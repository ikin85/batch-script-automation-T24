Add-Type -AssemblyName System.Windows.Forms

#Pilih File1 (R19)
$dialog1 = New-Object System.Windows.Forms.OpenFileDialog
$dialog1.Title = "Pilih File R19"
$dialog1.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
if ($dialog1.ShowDialog() -eq "OK") {
    $File1 = $dialog1.FileName
} else {
    Write-Host "File R19 tidak dipilih. Script berhenti."
    exit
}

#Pilih File2 (R25)
$dialog2 = New-Object System.Windows.Forms.OpenFileDialog
$dialog2.Title = "Pilih File R25"
$dialog2.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
if ($dialog2.ShowDialog() -eq "OK") {
    $File2 = $dialog2.FileName
} else {
    Write-Host "File R25 tidak dipilih. Script berhenti."
    exit
}

# Output file ke folder yang sama
$OutputFile = Join-Path (Split-Path $File1) "Hasil_comapre.html"

#Baca isi file
$Text1 = Get-Content $File1
$Text2 = Get-Content $File2

# Jumlah baris maksimum
$maxLines = [Math]::Max($Text1.Count, $Text2.Count)

#HTML
$Result = @"
<html>
<head>
<style>
body { font-family: Consolas, monospace; background-color: #f9f9f9; }
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid #ccc; padding: 6px; vertical-align: top; }
th { background-color: #e0e0e0; }
.diff { color: red; font-weight: bold; }
</style>
</head>
<body>
<h2>Hasil Perbandingan File (Hanya Baris Berbeda)</h2>
<table>
<tr><th>R19 ($File1)</th><th>R25 ($File2)</th></tr>
"@

for ($i = 0; $i -lt $maxLines; $i++) {
    $line1 = if ($i -lt $Text1.Count) { $Text1[$i] } else { "" }
    $line2 = if ($i -lt $Text2.Count) { $Text2[$i] } else { "" }

    if ($line1 -ne $line2) {
        # Highlight karakter berbeda
        $words1 = $line1 -split '\s+'
        $words2 = $line2 -split '\s+'
        $maxWords = [Math]::Max($words1.Count, $words2.Count)

        $line1Formatted = ""
        $line2Formatted = ""

        for ($j = 0; $j -lt $maxWords; $j++) {
            $w1 = if ($j -lt $words1.Count) { $words1[$j] } else { "" }
            $w2 = if ($j -lt $words2.Count) { $words2[$j] } else { "" }

            if ($w1 -eq $w2) {
                $line1Formatted += "$w1 "
                $line2Formatted += "$w2 "
            } else {
                $line1Formatted += "<span class='diff'>$w1</span> "
                $line2Formatted += "<span class='diff'>$w2</span> "
            }
        }

        $Result += "<tr><td>Baris $($i+1): $line1Formatted</td><td>Baris $($i+1): $line2Formatted</td></tr>`n"
    }
}

# Tutup HTML
$Result += "</table></body></html>"

# Simpan hasil ke HTML
$Result | Out-File -FilePath $OutputFile -Encoding UTF8

Write-Host "Analisa selesai. Hasil disimpan di $OutputFile"
Write-Host ""
Write-Host "                        .-." -ForegroundColor Yellow
Write-Host "                       /   \"
Write-Host "      _..-----.._     |.-.|"
Write-Host "    .'  _     _  '.   / / \"
Write-Host "   /    O)   (O    \ / /   \"
Write-Host "  |  .--.  ^  .--.  | |     |"
Write-Host "  | (    \___/    ) | | PARTY|"
Write-Host "   \ '.__.' '.__.' /  \ H O !"
Write-Host "    '.           .'    '---'"
Write-Host "      '-._____.-'" -ForegroundColor Yellow
Write-Host ""
Write-Host "   *** B E R H A S I L  ***" -ForegroundColor Green
Write-Host ""

# ---------- CONFETTI ----------
if ($ConfettiEnabled) {
    $chars = @('*','+','o','x','%','#')
    $width  = $Host.UI.RawUI.WindowSize.Width
    $height = $Host.UI.RawUI.WindowSize.Height
    $end    = (Get-Date).AddSeconds($ConfettiDurationSeconds)

    while ((Get-Date) -lt $end) {
        $x = Get-Random -Minimum 0 -Maximum ($width-1)
        $y = Get-Random -Minimum 0 -Maximum ($height-2)

        try {
            $Host.UI.RawUI.CursorPosition = @{X=$x;Y=$y}
            Write-Host ($chars | Get-Random) -NoNewline -ForegroundColor Cyan
        } catch {}

        Start-Sleep -Milliseconds 40
    }
}

Write-Host "`nSEMUA TASK SUKSES!" -ForegroundColor Green