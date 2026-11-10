# Mede o tamanho das subpastas (e arquivos) de uma pasta, rapido.
# Usa robocopy /L em paralelo: muito mais rapido que Get-ChildItem -Recurse
# (que estoura o timeout em pastas com node_modules).
# Uso: medir-pastas.ps1 -Root 'C:\' [-Top 20]
param(
  [Parameter(Mandatory)][string]$Root,
  [int]$Top = 20
)
$ErrorActionPreference = 'SilentlyContinue'
$dirs = Get-ChildItem -LiteralPath $Root -Force -Directory |
  Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) }
$jobs = foreach ($d in $dirs) {
  Start-ThreadJob -ThrottleLimit 8 -ArgumentList $d.FullName -ScriptBlock {
    param($p)
    $out = robocopy $p 'C:\__nul__' /L /S /NJH /BYTES /NFL /NDL /NC /NP /R:0 /W:0 /XJ 2>$null
    $line = $out | Where-Object { $_ -match '^\s*Bytes\s*:' } | Select-Object -First 1
    $b = 0; if ($line -match ':\s*(\d+)') { $b = [int64]$Matches[1] }
    [pscustomobject]@{ Path = $p; GB = [math]::Round($b / 1GB, 1) }
  }
}
$res = @($jobs | Wait-Job | Receive-Job)
$res += Get-ChildItem -LiteralPath $Root -Force -File |
  ForEach-Object { [pscustomobject]@{ Path = $_.FullName; GB = [math]::Round($_.Length / 1GB, 1) } }
$res | Sort-Object GB -Descending | Select-Object -First $Top |
  Format-Table -AutoSize | Out-String -Width 220
