# SO FAZ BACKUP. Nao apaga nada.
# Para cada worktree do CSV com DirAgeDays >= MinAgeDays, guarda em BackupRoot\<nome>\:
#   info.txt                       branch, HEAD, remoto
#   commits-nao-enviados.bundle    commits que nao estao em nenhum remoto (git bundle)
#   alteracoes.patch + status.txt  alteracoes nao commitadas (git diff HEAD --binary)
#   arquivos-novos\                arquivos nao rastreados e nao ignorados (<=50 MB cada)
#   env\                           arquivos .env* ignorados (fora de node_modules)
# Escreve BackupRoot\backup-log.txt com uma linha "BKP <dir>" por backup ok
# (ou "FAIL <dir>"). remover-worktrees.ps1 so remove o que estiver como BKP.
# Uso: backup-worktrees.ps1 -Csv inv.csv -BackupRoot D:\Backups\worktrees-AAAAMMDD [-MinAgeDays 2]
param(
  [Parameter(Mandatory)][string]$Csv,
  [Parameter(Mandatory)][string]$BackupRoot,
  [int]$MinAgeDays = 2
)
$ErrorActionPreference = 'Continue'
$rows = Import-Csv $Csv | Where-Object { [int]$_.DirAgeDays -ge $MinAgeDays -and $_.Repo -ne '?' -and $_.Tipo -ne 'checkout-principal' }
New-Item -ItemType Directory -Force $BackupRoot | Out-Null
$log = Join-Path $BackupRoot 'backup-log.txt'
foreach ($r in $rows) {
  $d = $r.Dir
  if (-not (Test-Path -LiteralPath $d)) { continue }
  $leaf = Split-Path $d -Leaf
  $parent = Split-Path (Split-Path $d -Parent) -Leaf
  $name = if ($d -like '*\.codex\*' -or $d -like '*\.ao\*') { "${parent}__$leaf" } else { $leaf }
  $b = Join-Path $BackupRoot $name
  New-Item -ItemType Directory -Force $b | Out-Null
  "dir=$d`nbranch=$($r.Branch)`nhead=$(git -C $d rev-parse HEAD)`nremote=$(git -C $d remote get-url origin)" |
    Set-Content "$b\info.txt" -Encoding utf8
  $ok = $true
  $unpushed = @(git -C $d log HEAD --not --remotes --oneline)
  if ($unpushed.Count -gt 0) {
    git -C $d bundle create "$b\commits-nao-enviados.bundle" HEAD --not --remotes 2>&1 | Out-Null
    $v = git -C $d bundle verify "$b\commits-nao-enviados.bundle" 2>&1 | Out-String
    if ($v -notmatch 'is okay') { $ok = $false }
    $unpushed | Set-Content "$b\commits-nao-enviados.txt" -Encoding utf8
  }
  if (git -C $d status --porcelain) {
    git -C $d diff HEAD --binary | Set-Content "$b\alteracoes.patch" -Encoding utf8 -NoNewline
    git -C $d status --porcelain | Set-Content "$b\status.txt" -Encoding utf8
    foreach ($f in git -C $d ls-files --others --exclude-standard) {
      $src = Join-Path $d $f
      if ((Get-Item -LiteralPath $src -EA SilentlyContinue).Length -gt 50MB) { "pulado (>50MB): $f" | Add-Content "$b\status.txt"; continue }
      $dst = Join-Path "$b\arquivos-novos" $f
      New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
      Copy-Item -LiteralPath $src $dst -Force
    }
  }
  foreach ($f in git -C $d ls-files --others --ignored --exclude-standard | Where-Object { $_ -match '(^|/)\.env' -and $_ -notmatch 'node_modules' }) {
    $dst = Join-Path "$b\env" $f
    New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
    Copy-Item -LiteralPath (Join-Path $d $f) $dst -Force
  }
  $line = "{0} {1}" -f $(if ($ok) { 'BKP ' } else { 'FAIL' }), $d
  $line | Add-Content $log -Encoding utf8
  $line
}
"Backup em $BackupRoot - log: $log"
