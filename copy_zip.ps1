<#
copy_zip_enhanced.ps1 (fixed)
Enhanced: ZIP -> parallel copy -> extract -> cleanup
#>

# ---------- CONFIG ----------
$SevenZipPath = 'E:\tools\7-zip\7z.exe'

$Sources = @(
    'E:\source\EAP-7.2.0'
)

$Targets = @(
    '\\10.8.50.28\source'
)

$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ZipDir  = Join-Path $BaseDir 'zip_output'
$LogDir  = Join-Path $BaseDir 'logs'

$SevenZipLevel = '-mx=3'

$RemoveLocalZipAfter = $true
$RemoveTargetZipAfter = $true

$ParallelTargets = $true
$MaxParallelJobs = 4

$TargetCredential = $null

# ---------- PREPARE ----------
New-Item -Path $ZipDir -ItemType Directory -Force | Out-Null
New-Item -Path $LogDir -ItemType Directory -Force | Out-Null

$use7z = ($SevenZipPath -and (Test-Path $SevenZipPath))

function Log {
    param([string]$Path, [string]$Text)
    $t = "{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $Text
    $t | Out-File -FilePath $Path -Encoding UTF8 -Append
    Write-Host $Text
}

function File-Sha256 {
    param([string]$Path)
    try {
        return (Get-FileHash -Algorithm SHA256 -Path $Path).Hash
    } catch {
        return $null
    }
}

function Resolve-Source {
    param([string]$inputPath)
    $p = $inputPath.TrimEnd('\')
    if (Test-Path $p) { return (Get-Item $p).FullName }
    if ($p.Length -lt 2) { return $null }
    $drive = $p.Substring(0,2)
    $basename = Split-Path -Path $p -Leaf
    Write-Host "Mencari '$basename' pada drive $drive ..." -ForegroundColor Yellow
    $found = Get-ChildItem -Path "$drive\" -Directory -Recurse -Force -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -ieq $basename } | Select-Object -First 1
    if ($found) { return $found.FullName }
    $foundFile = Get-ChildItem -Path "$drive\" -File -Recurse -Force -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -ieq $basename } | Select-Object -First 1
    if ($foundFile) { return $foundFile.FullName }
    return $null
}

# ---------- STEP 1: CREATE ZIPs ----------
$zipMeta = @()
foreach ($src in $Sources) {
    $resolved = Resolve-Source -inputPath $src
    if (-not $resolved) {
        Log (Join-Path $LogDir 'script.log') "ERROR: Source not found: $src"
        continue
    }
    $item = Get-Item $resolved
    $baseName = $item.BaseName
    $outZip = Join-Path $ZipDir ("$baseName.zip")
    Log (Join-Path $LogDir 'script.log') "Creating ZIP: $resolved -> $outZip"

    if ($use7z) {
        if ($item.PSIsContainer) {
            & $SevenZipPath a -tzip $outZip "$resolved\*" $SevenZipLevel -y > $null 2>&1
        } else {
            & $SevenZipPath a -tzip $outZip $resolved $SevenZipLevel -y > $null 2>&1
        }
    } else {
        try {
            if ($item.PSIsContainer) {
                if (Test-Path $outZip) { Remove-Item $outZip -Force }
                Compress-Archive -Path (Join-Path $resolved '*') -DestinationPath $outZip -Force
            } else {
                if (Test-Path $outZip) { Remove-Item $outZip -Force }
                Compress-Archive -Path $resolved -DestinationPath $outZip -Force
            }
        } catch {
            Log (Join-Path $LogDir 'script.log') "ERROR: Compress-Archive failed for $resolved : $_"
            continue
        }
    }

    if (Test-Path $outZip) {
        $size = (Get-Item $outZip).Length
        $hash = File-Sha256 -Path $outZip
        $meta = [PSCustomObject]@{
            ZipPath = $outZip
            BaseName = $baseName
            Size = $size
            Hash = $hash
        }
        $zipMeta += $meta
        Log (Join-Path $LogDir 'script.log') "ZIP created: $outZip (Size: $size bytes, SHA256: $hash)"
    } else {
        Log (Join-Path $LogDir 'script.log') "ERROR: Failed to create zip for $resolved"
    }
}

if ($zipMeta.Count -eq 0) {
    Log (Join-Path $LogDir 'script.log') "No ZIPs created. Exiting."
    exit 1
}

# ---------- worker ----------
$worker = {
    param($target, $zipList, $use7z, $SevenZipPath, $RemoveTargetZipAfter, $LogDir, $TargetCredential)

    $logFile = Join-Path $LogDir ("copy_extract_{0}.log" -f (($target -replace '[\\/:]','_')))
    "===== START TARGET: $target =====`nTime: $(Get-Date)`n" | Out-File -FilePath $logFile -Encoding UTF8 -Append

    $mappedDrive = $null
    if ($TargetCredential) {
        $driveName = "TGT" + ([guid]::NewGuid().ToString('N').Substring(0,6))
        try {
            New-PSDrive -Name $driveName -PSProvider FileSystem -Root $target -Credential $TargetCredential -ErrorAction Stop | Out-Null
            $mappedDrive = "$driveName`:\"
        } catch {
            "ERROR: Failed mapping credential to $target : $_" | Out-File -FilePath $logFile -Append
            return
        }
    }

    $useTargetRoot = if ($mappedDrive) { $mappedDrive } else { $target }

    foreach ($zm in $zipList) {
        $zipName = [System.IO.Path]::GetFileName($zm.ZipPath)
        $remoteZipPath = Join-Path $useTargetRoot $zipName
        $extractDir = Join-Path $useTargetRoot $zm.BaseName

        "COPY: $($zm.ZipPath) -> $useTargetRoot" | Out-File -FilePath $logFile -Append
        try {
            Copy-Item -Path $zm.ZipPath -Destination $useTargetRoot -Force -ErrorAction Stop
        } catch {
            "ERROR: Copy failed for $zipName -> $useTargetRoot : $($_)" | Out-File -FilePath $logFile -Append
            continue
        }

        Start-Sleep -Milliseconds 300

        try {
            $remoteInfo = Get-Item $remoteZipPath -ErrorAction Stop
            $remoteSize = $remoteInfo.Length
            $remoteHash = (Get-FileHash -Algorithm SHA256 -Path $remoteZipPath -ErrorAction Stop).Hash
            "$zipName remote size: $remoteSize, hash: $remoteHash" | Out-File -FilePath $logFile -Append
        } catch {
            "ERROR: Cannot stat remote file $remoteZipPath : $($_)" | Out-File -FilePath $logFile -Append
            continue
        }

        if ($remoteSize -ne $zm.Size -or $remoteHash -ne $zm.Hash) {
            "WARNING: Verification mismatch for $zipName (local size:$($zm.Size) remote size:$remoteSize) or hash mismatch" | Out-File -FilePath $logFile -Append
            continue
        }

        if (-not (Test-Path $extractDir)) {
            try { New-Item -ItemType Directory -Path $extractDir -Force | Out-Null } catch { "ERROR: create extract dir $extractDir : $($_)" | Out-File -FilePath $logFile -Append; continue }
        }

        "EXTRACT: $remoteZipPath -> $extractDir" | Out-File -FilePath $logFile -Append
        if ($use7z) {
            try {
                & $SevenZipPath x $remoteZipPath "-o$extractDir" -y > $null 2>&1
                "EXTRACTED (7z): $zipName" | Out-File -FilePath $logFile -Append
            } catch {
                "ERROR: 7z extract failed for $zipName: $($_)" | Out-File -FilePath $logFile -Append
                continue
            }
        } else {
            try {
                Expand-Archive -LiteralPath $remoteZipPath -DestinationPath $extractDir -Force
                "EXTRACTED (Expand-Archive): $zipName" | Out-File -FilePath $logFile -Append
            } catch {
                "ERROR: Expand-Archive failed for $zipName: $($_)" | Out-File -FilePath $logFile -Append
                continue
            }
        }

        if ($RemoveTargetZipAfter) {
            try {
                Remove-Item -LiteralPath $remoteZipPath -Force -ErrorAction Stop
                "Removed remote ZIP: $remoteZipPath" | Out-File -FilePath $logFile -Append
            } catch {
                "WARNING: Unable to remove remote ZIP $remoteZipPath : $($_)" | Out-File -FilePath $logFile -Append
            }
        }
    }

    if ($mappedDrive) { Remove-PSDrive -Name $driveName -Force -ErrorAction SilentlyContinue }
    "===== END TARGET: $target =====`n" | Out-File -FilePath $logFile -Encoding UTF8 -Append
}

# ---------- STEP 3: COPY & EXTRACT ----------
$zipListForJob = $zipMeta | ForEach-Object { @{ ZipPath=$_.ZipPath; BaseName=$_.BaseName; Size=$_.Size; Hash=$_.Hash } }

if ($ParallelTargets) {
    $jobs = @()
    foreach ($t in $Targets) {
        $j = Start-Job -ScriptBlock $worker -ArgumentList $t, $zipListForJob, $use7z, $SevenZipPath, $RemoveTargetZipAfter, $LogDir, $TargetCredential
        $jobs += $j
        while ( ($jobs | Where-Object { $_.State -eq 'Running' }).Count -ge $MaxParallelJobs ) {
            Start-Sleep -Seconds 1
        }
    }
    Write-Host "Waiting for $($jobs.Count) job(s) to finish..."
    Wait-Job -Job $jobs
    foreach ($j in $jobs) {
        Receive-Job -Job $j -ErrorAction SilentlyContinue | Out-Null
        Remove-Job -Job $j -Force -ErrorAction SilentlyContinue
    }
} else {
    foreach ($t in $Targets) {
        & $worker $t $zipListForJob $use7z $SevenZipPath $RemoveTargetZipAfter $LogDir $TargetCredential
    }
}

# ---------- STEP 4: optionally remove local zips ----------
if ($RemoveLocalZipAfter) {
    foreach ($zm in $zipMeta) {
        try {
            Remove-Item -LiteralPath $zm.ZipPath -Force -ErrorAction Stop
            Log (Join-Path $LogDir 'script.log') "Removed local ZIP: $($zm.ZipPath)"
        } catch {
            Log (Join-Path $LogDir 'script.log') "WARNING: Failed remove local ZIP $($zm.ZipPath) : $($_)"
        }
    }
}

Log (Join-Path $LogDir 'script.log') "ALL DONE. ZIPs processed: $($zipMeta.Count). Logs in: $LogDir"
