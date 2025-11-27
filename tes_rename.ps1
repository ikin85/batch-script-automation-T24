<#
rename_manual_final.ps1
Manual run: baca semua file pada folder sumber (lokal atau UNC), tentukan judul
berdasarkan kata kunci / longest line / first non-empty / filename, lalu simpan
hasil (UTF-8 .txt) ke folder output.
#>

# ===== KONFIG =====
$FOLDERS = @{
    "R19" = @{ Source = "D:\R19"           ; Output = "D:\test_rename\R19" }   # contoh network path \\server (ip\drive\file
    "R25" = @{ Source = "D:\R25"          ; Output = "D:\test_rename\R25" }
}
$LOG_NAME = "rename_log.txt"
# jika ingin menghapus sumber setelah sukses copy, ubah ke $true (default $false)
$DELETE_SOURCE_AFTER_COPY = $false
# ===== END KONFIG =====


# ---  judul jadi nama file ---
function MakeSafe([string]$s, [int]$max=220) {
    if ($null -eq $s) { return "" }
    $s = $s -replace '[\x00]', ''
    $s = $s -replace '[\\\/:\*\?"<>\|]', ''
    $s = ($s -replace '\s+', ' ').Trim()
    if ($s.Length -gt $max) { $s = $s.Substring(0,$max).Trim() }
    return $s
}

# ---  baca file sebagai text ---
function Read-Lines([string]$path) {
    try {
        
        $lines = Get-Content -LiteralPath $path -ErrorAction Stop
        return @{ Lines = $lines; Encoding = "auto" }
    } catch {
        
        try {
            $bytes = [System.IO.File]::ReadAllBytes($path)
            if ($bytes.Length -eq 0) { return @{ Lines = @(); Encoding="empty" } }
            $encCandidates = @("utf8","unicode","bigendianunicode","utf32","windows-1252")
            foreach ($c in $encCandidates) {
                try {
                    $enc = [System.Text.Encoding]::GetEncoding($c)
                    $text = $enc.GetString($bytes).Trim([char]0) -replace "^\uFEFF",""
                    $lines = $text -split "(\r\n|\n|\r)" | Where-Object { ($_ -ne "`r") -and ($_ -ne "`n") } 
                    
                    $real = @()
                    for ($i=0; $i -lt $lines.Length; $i+=2) { $real += $lines[$i] }
                    return @{ Lines = $real; Encoding = $enc.WebName }
                } catch { continue }
            }
        } catch { }
        return $null
    }
}

# ---  judul sesuai baris di line 6 dengan string Laba,Neraca,Summary ---
function Find-TitleByKeywords([string[]]$lines) {
    if (-not $lines) { return $null }
    
    $patterns = @(
        '\bRE\d{3,}\b', '\bKC\b', '\bLAP\b', '\bLABARUGI\b', '\bSUMMARY\b', '\bNERACA\b',
        '\bKANTOR\b', '\bMENARA\b', '\bBTPNS\b'
    )
    foreach ($ln in $lines) {
        foreach ($p in $patterns) {
            if ($ln -match $p) { return @{ Title=$ln; Reason="keyword_match:$p" } }
        }
    }
    return $null
}


function Extract-Title([string[]]$lines, [string]$fileName) {
    if ($null -ne $lines -and $lines.Count -gt 0) {
        
        $k = Find-TitleByKeywords $lines
        if ($k) { return $k }

        
        $longest = $lines | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" } | Sort-Object { -($_.Length) } | Select-Object -First 1
        if ($longest) { return @{ Title = $longest; Reason = "longest_line" } }

        
        $first = $lines | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" } | Select-Object -First 1
        if ($first) { return @{ Title = $first; Reason="first_nonempty" } }
    }
    
    $base = [IO.Path]::GetFileNameWithoutExtension($fileName)
    return @{ Title = $base; Reason = "fallback_filename" }
}

# --- helper: tulis log CSV per output folder ---
function Write-Log($outDir, $rec) {
    $logPath = Join-Path $outDir $LOG_NAME
    if (-not (Test-Path $logPath)) {
        "Source,Destination,Reason,Encoding,Timestamp" | Out-File -FilePath $logPath -Encoding UTF8
    }
    $line = '"{0}","{1}","{2}","{3}","{4}"' -f $rec.Source,$rec.Destination,$rec.Reason,$rec.Encoding,$rec.Timestamp
    $line | Out-File -FilePath $logPath -Encoding UTF8 -Append
}


foreach ($kv in $FOLDERS.GetEnumerator()) {
    $prefix = $kv.Key
    $src = $kv.Value.Source
    $out = $kv.Value.Output

    Write-Host "`n=== PROSES $prefix ==="
    Write-Host "Source: $src"
    Write-Host "Output: $out"

    if (-not (Test-Path $src)) {
        Write-Host "  -> Source path tidak ditemukan: $src" -ForegroundColor Yellow
        continue
    }
    if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out -Force | Out-Null }

    $files = Get-ChildItem -Path $src -File -ErrorAction SilentlyContinue
    if (-not $files -or $files.Count -eq 0) {
        Write-Host "  -> Tidak ada file di source." -ForegroundColor DarkGray
        continue
    }

    foreach ($f in $files) {
        Write-Host "`nProses file: $($f.Name)"
        $read = Read-Lines $f.FullName
        if ($null -eq $read) {
            Write-Host "  -> Tidak bisa baca teks; pakai nama file fallback." -ForegroundColor Yellow
            $titleRec = @{ Title = [IO.Path]::GetFileNameWithoutExtension($f.Name); Reason = "read_error_fallback" }
            $encoding = "unknown"
        } else {
            $encoding = $read.Encoding
            $titleRec = Extract-Title $read.Lines $f.Name
        }

        $rawTitle = $titleRec.Title
        $reason = $titleRec.Reason

        
        $clean = MakeSafe $rawTitle
        if ($clean -match "^(R\d{2})[\s\-_]+(.+)$") {
            $clean = $matches[2].Trim()
            Write-Host "  -> Menghapus leading prefix dari title."
        }

        if ([string]::IsNullOrWhiteSpace($clean)) { $clean = [IO.Path]::GetFileNameWithoutExtension($f.Name) }

        # nama akhir
        $date = $f.LastWriteTime.ToString("yyyyMMdd")
        $baseName = "{0}_{1}_{2}" -f $prefix, $clean, $date
        $destName = $baseName + ".txt"
        $destPath = Join-Path $out $destName

        $i = 1
        while (Test-Path $destPath) {
            $destName = "{0}({1}).txt" -f $baseName, $i
            $destPath = Join-Path $out $destName
            $i++
        }

        
        try {
            if ($null -ne $read -and $read.Lines) {
                $content = ($read.Lines -join "`r`n").Trim([char]0)
                [System.IO.File]::WriteAllText($destPath, $content, [System.Text.Encoding]::UTF8)
                Write-Host "  -> Saved: $destName (reason: $reason; encoding: $encoding)" -ForegroundColor Green
            } else {
                Copy-Item -LiteralPath $f.FullName -Destination $destPath -Force
                Write-Host "  -> Copied raw to: $destName" -ForegroundColor Yellow
            }

            Write-Log $out @{ Source = $f.FullName; Destination = $destName; Reason = $reason; Encoding = $encoding; Timestamp = (Get-Date) }

            if ($DELETE_SOURCE_AFTER_COPY) {
                Remove-Item -LiteralPath $f.FullName -Force
                Write-Host "  -> Sumber dihapus."
            }
        } catch {
            Write-Host "  -> ERROR saat menyimpan: $_" -ForegroundColor Red
            Write-Log $out @{ Source = $f.FullName; Destination = ""; Reason = "save_error"; Encoding = $encoding; Timestamp = (Get-Date) }
        }
    }
}

Write-Host "`nSELESAI."
