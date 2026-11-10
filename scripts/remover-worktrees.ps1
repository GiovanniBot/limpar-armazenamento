# Remove SOMENTE as worktrees marcadas "BKP <dir>" no log do backup-worktrees.ps1.
# Rode so depois de conferir o log (0 FAIL) e de o dono ter aprovado a remocao.
# Uso: remover-worktrees.ps1 -Log D:\Backups\worktrees-AAAAMMDD\backup-log.txt
param([Parameter(Mandatory)][string]$Log)
$dirs = Get-Content $Log | Where-Object { $_ -like 'BKP *' } | ForEach-Object { $_.Substring(5).Trim() }
foreach ($d in $dirs) {
  if (-not (Test-Path -LiteralPath $d)) { "GONE $d"; continue }
  $repo = Split-Path (git -C $d rev-parse --path-format=absolute --git-common-dir) -Parent
  if (-not $repo -or ((Resolve-Path $repo).Path -eq (Resolve-Path $d).Path)) { "SKIP (checkout principal, nao e worktree) $d"; continue }
  git -C $repo worktree remove --force $d 2>&1 | Out-Null
  if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }
  git -C $repo worktree prune 2>&1 | Out-Null
  "{0} {1}" -f $(if (Test-Path -LiteralPath $d) { 'FAIL' } else { 'OK  ' }), $d
}
"C: livre: " + [math]::Round((Get-PSDrive C).Free / 1GB, 1) + " GB"
