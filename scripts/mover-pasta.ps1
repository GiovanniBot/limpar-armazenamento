# Move uma pasta para outro disco e deixa uma junction no caminho antigo,
# para que apps (NVIDIA, Explorer, Desktop) continuem usando o mesmo caminho
# sem mudar nenhuma configuracao.
# - robocopy /MOVE: codigo de saida 0-7 = sucesso (1 = arquivos copiados).
# - Se sobrar arquivo na origem, confere por hash se ja esta no destino antes de apagar.
# Uso: mover-pasta.ps1 -Source "$env:USERPROFILE\Videos\NVIDIA" -Target 'D:\Videos\NVIDIA'
param(
  [Parameter(Mandatory)][string]$Source,
  [Parameter(Mandatory)][string]$Target
)
if ((Get-Item -LiteralPath $Source -Force).LinkType) { "Ja e um link: $Source"; return }
New-Item -ItemType Directory -Force $Target | Out-Null
robocopy $Source $Target /E /MOVE /COPY:DAT /DCOPY:DAT /R:1 /W:1 /NP /NFL /NDL /NJH | Select-Object -Last 9 | Select-Object -First 3
if ($LASTEXITCODE -ge 8) { "ERRO robocopy rc=$LASTEXITCODE - nada mais foi feito"; return }
if (Test-Path -LiteralPath $Source) {
  $bad = 0
  foreach ($f in Get-ChildItem -LiteralPath $Source -Recurse -Force -File) {
    $d = $f.FullName.Replace($Source, $Target)
    if (-not (Test-Path -LiteralPath $d) -or (Get-FileHash -LiteralPath $d).Hash -ne (Get-FileHash -LiteralPath $f.FullName).Hash) { $bad++; "NAO COPIADO: $($f.FullName)" }
  }
  if ($bad -gt 0) { "Parei: $bad arquivo(s) so existem na origem."; return }
  Remove-Item -LiteralPath $Source -Recurse -Force
}
New-Item -ItemType Junction -Path $Source -Target $Target | Out-Null
$i = Get-Item -LiteralPath $Source -Force
"{0} -> {1} | itens visiveis: {2}" -f $i.LinkType, ($i.Target -join ''), @(Get-ChildItem -LiteralPath $Source -Recurse -Force -File).Count
