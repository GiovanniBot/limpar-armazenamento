# Levanta todas as worktrees/clones git (de agentes de IA ou suas) e grava um CSV.
# Descobre sozinho:
#   1. repositorios git ate 2 niveis dentro de -Roots, e as worktrees de cada um (git worktree list)
#   2. pastas de worktrees de agentes conhecidos: ~\.codex\worktrees, ~\.ao\data\worktrees,
#      <repo>\.claude\worktrees, <repo>\.worktrees, <repo>\.trees
# Colunas: Dir, Repo, Branch, Dirty, Changes, Unpushed, Merged, DirAgeDays, LastCommit
#  - Merged = origin/<main|master|staging|develop> se HEAD e ancestral; senao False.
#    False NAO quer dizer "nao mergeado": squash-merge nao aparece como ancestral.
#    Confira com `gh pr list --head <branch> --state all`.
#  - Unpushed = commits de HEAD que nao existem em nenhum remoto.
# Uso: inventario-worktrees.ps1 -Out <pasta-temporaria>\inv.csv [-Roots C:\dev,D:\projetos]
param(
  [Parameter(Mandatory)][string]$Out,
  [string[]]$Roots = @(
    'C:\dev', 'C:\src', 'C:\code', 'C:\projects', 'C:\wt',
    "$env:USERPROFILE\dev", "$env:USERPROFILE\source\repos", "$env:USERPROFILE\Projects",
    "$env:USERPROFILE\Documents\GitHub", "$env:USERPROFILE\code"
  )
)
$ErrorActionPreference = 'SilentlyContinue'
$found = New-Object System.Collections.Generic.HashSet[string]([StringComparer]::OrdinalIgnoreCase)
function Add-Dir($p) { if ($p -and (Test-Path (Join-Path $p '.git'))) { [void]$found.Add((Resolve-Path $p).Path) } }

$repos = foreach ($r in $Roots | Where-Object { Test-Path $_ }) {
  Get-ChildItem $r -Directory -Force | ForEach-Object {
    if (Test-Path (Join-Path $_.FullName '.git')) { $_.FullName }
    else { Get-ChildItem $_.FullName -Directory -Force | Where-Object { Test-Path (Join-Path $_.FullName '.git') } | ForEach-Object FullName }
  }
}
foreach ($repo in $repos) {
  Add-Dir $repo
  git -C $repo worktree list --porcelain 2>$null | Where-Object { $_ -like 'worktree *' } |
    ForEach-Object { Add-Dir ($_.Substring(9) -replace '/', '\') }
  foreach ($sub in '.claude\worktrees', '.worktrees', '.trees') {
    Get-ChildItem (Join-Path $repo $sub) -Directory -Force | ForEach-Object { Add-Dir $_.FullName }
  }
}
foreach ($agentDir in "$env:USERPROFILE\.codex\worktrees", "$env:USERPROFILE\.ao\data\worktrees") {
  Get-ChildItem $agentDir -Directory -Force | ForEach-Object {
    Add-Dir $_.FullName
    Get-ChildItem $_.FullName -Directory -Force | ForEach-Object { Add-Dir $_.FullName }
  }
}

$fetched = @{}
$rows = foreach ($d in $found) {
  $common = git -C $d rev-parse --path-format=absolute --git-common-dir 2>$null
  if (-not $common) { continue }
  $repo = Split-Path $common -Parent
  $isMain = ((Resolve-Path $repo).Path -eq $d)
  if (-not $fetched[$repo]) { git -C $repo fetch --prune origin 2>$null | Out-Null; $fetched[$repo] = 1 }
  $st = git -C $d status --porcelain 2>$null
  $merged = $false
  foreach ($b in 'origin/main', 'origin/master', 'origin/staging', 'origin/develop') {
    if (git -C $d rev-parse --verify -q $b) {
      git -C $d merge-base --is-ancestor HEAD $b
      if ($LASTEXITCODE -eq 0) { $merged = $b; break }
    }
  }
  [pscustomobject]@{
    Dir        = $d
    Repo       = Split-Path $repo -Leaf
    Tipo       = $(if ($isMain) { 'checkout-principal' } else { 'worktree' })
    Branch     = git -C $d rev-parse --abbrev-ref HEAD
    Dirty      = [bool]$st
    Changes    = @($st).Count
    Unpushed   = @(git -C $d log HEAD --not --remotes --oneline 2>$null).Count
    Merged     = $merged
    DirAgeDays = [int]((Get-Date) - (Get-Item $d).LastWriteTime).TotalDays
    LastCommit = git -C $d log -1 --format=%cr
  }
}
$rows | Export-Csv $Out -NoTypeInformation -Encoding utf8
$rows | Sort-Object Tipo, { [int]$_.DirAgeDays } |
  Format-Table Tipo, Branch, Dirty, Changes, Unpushed, Merged, DirAgeDays, Dir -AutoSize | Out-String -Width 300
"CSV: $Out ($(@($rows).Count) linhas). Checkouts principais aparecem so para contexto: o backup/remocao ignora Tipo=checkout-principal."
