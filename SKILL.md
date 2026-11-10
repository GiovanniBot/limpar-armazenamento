---
name: limpar-armazenamento
description: Diagnostica e limpa espaço em disco no Windows com segurança, para qualquer agente de IA que rode comandos (Claude Code, Codex, Cursor, Gemini CLI, Copilot e outros). Use quando o usuário pedir para liberar espaço, limpar armazenamento, ver o que está ocupando o disco/SSD, reclamar de disco cheio ou de pouco espaço. Mede pastas rápido, acha worktrees git antigas de agentes e guarda backup do que não está no GitHub antes de remover, poda imagens Docker, limpa caches, instaladores em Downloads e move pastas grandes para outro disco sem quebrar apps.
---

# Limpar armazenamento (Windows)

Skill no formato aberto de Agent Skills: funciona com qualquer agente que lê `SKILL.md`
(Claude Code, Codex, Cursor, Gemini CLI, GitHub Copilot, OpenCode e outros) e que consegue
rodar comandos no PowerShell do Windows.

Responda no idioma do usuário. Trabalhe em etapas curtas, mostre números (GB) e **pergunte antes
de apagar**. Se o seu agente tiver lista de tarefas ou plano visível, use-a para mostrar as etapas.
Grave CSVs, logs e saídas numa pasta temporária (a pasta de rascunho da sua sessão, se houver, ou
`$env:TEMP\limpar-armazenamento`), nunca dentro de um repositório.

Os scripts ficam em `scripts\`, **na mesma pasta deste SKILL.md**. Use o caminho real de onde a
skill foi instalada; se não souber, este trecho procura nas pastas de skills mais comuns:

```powershell
$sk = @("$env:USERPROFILE\.agents\skills", "$env:USERPROFILE\.claude\skills", "$env:USERPROFILE\.codex\skills",
        "$env:USERPROFILE\.cursor\skills", "$env:USERPROFILE\.gemini\skills", "$env:USERPROFILE\.copilot\skills", ".agents\skills") |
  ForEach-Object { Join-Path $_ 'limpar-armazenamento\scripts' } | Where-Object { Test-Path $_ } | Select-Object -First 1
$sk
```

Rode os scripts com PowerShell 7 (`pwsh`) de preferência, porque `medir-pastas.ps1` usa `Start-ThreadJob`.
Comandos longos (backup, remoção, medição do C: inteiro) podem passar de 10 minutos: se o seu agente
tiver execução em segundo plano, use-a; senão, divida por pasta.

## Regras de segurança (não negociáveis)

1. **Diagnóstico não apaga nada.** Meça, mostre a tabela e pergunte o que limpar. Só apague
   o que o usuário aprovou nesta conversa.
2. **Nada que só existe neste PC é apagado sem backup.** Antes de remover um repositório, uma
   worktree ou um projeto, procure: alterações não commitadas, commits não enviados e arquivos
   ignorados que não se recriam (`.env`, `.secrets`, chaves `.pem`/`.key`, keystores Android
   `.jks`/`keystore.properties`, certificados). Liste para o usuário o que achou e guarde num
   zip no disco de backup.
3. **Backup e remoção são passos separados.** Rode o backup, confira o log (0 FAIL) e só depois
   remova. Agentes com aprovação automática costumam bloquear "backup + apagar" no mesmo comando,
   e o passo separado também é mais seguro.
4. **Não mexa em worktrees modificadas há menos de 2 dias**: podem pertencer a uma sessão de
   agente aberta agora (deste ou de outro agente).
5. **Nunca remova o checkout principal de um repositório** pelos scripts de worktree. Pastas
   sem `.git` e sem histórico só saem com confirmação explícita.
6. A Lixeira fica no mesmo disco e não libera espaço. Apague de vez só o que foi aprovado.
7. Não tente contornar o que exige administrador ou o que for bloqueado: explique e passe o
   comando para o usuário rodar.

## Passo 1: medir (rápido)

```powershell
Get-Volume | ? DriveLetter | select DriveLetter, @{n='TotalGB';e={[math]::Round($_.Size/1GB)}}, @{n='LivreGB';e={[math]::Round($_.SizeRemaining/1GB)}}
& "$sk\medir-pastas.ps1" -Root 'C:\'
& "$sk\medir-pastas.ps1" -Root $env:USERPROFILE
& "$sk\medir-pastas.ps1" -Root "$env:LOCALAPPDATA"
```

Desça nas maiores pastas (AppData\Roaming, Program Files, ProgramData, Documents, Downloads, pastas
de projetos). **Não use `Get-ChildItem -Recurse` para medir pastas grandes**, porque com node_modules estoura
qualquer timeout. O script usa `robocopy /L` em paralelo e ignora junctions.

Apresente uma tabela agrupada (Desenvolvimento / Sistema / Programas / Jogos / Arquivos pessoais) e
depois uma tabela **"o que dá para liberar | ganho | risco"** para o usuário escolher.

## Onde o espaço costuma estar

| Item | Onde | Ação |
|---|---|---|
| Worktrees git de agentes de IA | `~\.codex\worktrees`, `<repo>\.claude\worktrees`, `<repo>\.worktrees`, `<repo>\.trees`, `~\.ao\data\worktrees`, pastas de worktrees que o usuário criou | Passo 2. Costuma ser o maior ganho (cada uma tem node_modules, builds, `.tmp`) |
| Disco do WSL | `AppData\Local\wsl\*\ext4.vhdx`, `AppData\Local\Packages\*Ubuntu*\LocalState\ext4.vhdx` | Limpe dentro do Linux (Passo 3). O vhdx não encolhe sozinho |
| Docker Desktop | `AppData\Local\Docker\wsl\disk\docker_data.vhdx` | Passo 3 |
| Caches | `AppData\Local\NVIDIA\DXCache`, `~\.gradle\caches`, npm-cache, pnpm store, Chrome/Edge Cache, `AppData\Local\Temp` | Passo 4 |
| Downloads | instaladores, ISOs, zips de instaladores | Passo 5 |
| Vídeos de gravação | `Videos\NVIDIA`, `Videos\Captures` | Mover para outro disco (Passo 6) |
| Jogos | Epic, Steam, Riot, Ubisoft | Desinstalar pelo launcher ou pelo Passo 7 |
| `pagefile.sys`, `hiberfil.sys` | raiz do C: | Só se o usuário quiser (Passo 8) |

## Passo 2: worktrees e repositórios

```powershell
$tmp = "$env:TEMP\limpar-armazenamento"; New-Item -ItemType Directory -Force $tmp | Out-Null
& "$sk\inventario-worktrees.ps1" -Out "$tmp\inv.csv"                 # aceita -Roots C:\dev,D:\code
```

Leia a tabela assim:
- `Tipo=checkout-principal`: é o repositório em si. Os scripts de worktree ignoram essas linhas.
- `Changes=0`, `Unpushed=0` e `Merged` diferente de False: está tudo no GitHub e pode sair.
- `Merged=False` **não** prova que não foi mergeado: squash-merge não aparece como ancestral.
  Confira com `gh pr list -R <owner/repo> --head <branch> --state all --json number,state`.
- `Changes>0` ou `Unpushed>0`: tem trabalho só local, e o backup guarda.

Mostre a lista ao usuário, combine o corte de idade (padrão: 2 dias) e o disco de backup, e então:

```powershell
$bk = "D:\Backups\worktrees-$(Get-Date -f yyyyMMdd)"   # sem segundo disco: use uma pasta fora do C: ou um HD externo
& "$sk\backup-worktrees.ps1" -Csv "$tmp\inv.csv" -BackupRoot $bk -MinAgeDays 2   # SO backup; pode demorar, rode em background
Select-String -Path "$bk\backup-log.txt" -Pattern '^FAIL'                         # tem que vir vazio
& "$sk\remover-worktrees.ps1" -Log "$bk\backup-log.txt"                           # remove só as linhas BKP
```

Cada pasta de backup contém `info.txt` (branch/commit/remoto), `alteracoes.patch` + `arquivos-novos\`
(o que não foi commitado), `commits-nao-enviados.bundle` (verificado) e `env\`. Os branches
continuam no git; só as pastas saem. **Restaurar:** `git worktree add <pasta> <branch>`,
`git apply alteracoes.patch`, copiar `arquivos-novos\`. Se houver bundle, use
`git fetch <arquivo.bundle> HEAD:recuperado`. Ao verificar um bundle à mão, rode
`git bundle verify` dentro do repositório de origem.

**Projeto inteiro que já está no GitHub** (o usuário quer tirar do PC): confira `git status`,
`git log --branches --not --remotes`, `git stash list` e
`git status --ignored --porcelain` (fora de node_modules/build). Zipe os arquivos ignorados que
importam (segredos e chaves) no disco de backup e confira o hash dos críticos antes de apagar a pasta.

Se o seu agente tiver um comando próprio para limpar as worktrees que ele mesmo criou (alguns apps
têm "limpar sessões inativas"), prefira-o para essas pastas: ele sabe quais sessões ainda estão abertas.

## Passo 3: Docker e WSL

- Descubra **qual** Docker é usado: `docker context ls`; `wsl -l -v`;
  `wsl -d <distro> -- bash -lc 'docker system df'`. Pode haver Docker Desktop no Windows **e** um
  Docker nativo dentro de uma distro (ex.: usado por um runner de CI). Antes de podar, veja se há
  build ou runner rodando.
- Podar com segurança, mantendo o cache recente. Para Docker dentro do WSL, rode via `bash` ou
  `wsl -d <distro> -- bash -lc '...'` a partir de um shell bash; as aspas do PowerShell costumam
  quebrar o `bash -c`:

```bash
docker image prune -a -f --filter "until=48h"
docker builder prune -f --filter "until=72h"
docker volume prune -f        # só volumes anônimos sem uso; volumes nomeados podem ter bancos de dados: pergunte
docker system df
```

- Docker Desktop sem uso há semanas: proponha desinstalar pelo `UninstallString` oficial
  (`"Docker Desktop Installer.exe" uninstall --quiet`), depois de fechar os processos.
- O espaço liberado dentro do WSL só volta ao Windows compactando o vhdx: `wsl --shutdown` e então
  `wsl --manage <distro> --set-sparse true --allow-unsafe` (WSL recente) ou `Optimize-VHD` (Hyper-V,
  admin). Ofereça e deixe o usuário decidir; desligar o WSL interrompe o que estiver rodando nele.

## Passo 4: caches (seguros, se recriam)

Um comando por cache, para o usuário ver o ganho de cada um:

```powershell
Remove-Item -LiteralPath "$env:LOCALAPPDATA\NVIDIA\DXCache" -Recurse -Force -EA SilentlyContinue
Remove-Item -LiteralPath "$env:USERPROFILE\.gradle\caches" -Recurse -Force -EA SilentlyContinue
npm cache clean --force
pnpm store prune
# Temp do usuário: só itens com mais de 1 dia; pule pastas de rascunho de agentes em uso
# (ex.: 'claude', 'limpar-armazenamento') e a pasta temporária da sua própria sessão
$keep = 'claude', 'limpar-armazenamento'
$cut=(Get-Date).AddDays(-1); Get-ChildItem $env:TEMP -Force | ? { $_.Name -notin $keep -and $_.LastWriteTime -lt $cut } | Remove-Item -Recurse -Force -EA SilentlyContinue
# Chrome/Edge: só as pastas Cache, Code Cache e GPUCache dentro de cada perfil em "User Data"
```

## Passo 5: Downloads

Liste os itens ≥20 MB com data e tipo. Proponha apagar instaladores (`.exe`, `.msi`), `.iso` e zips
de instaladores. **Mantenha** fotos, vídeos, documentos, PSDs, mods de jogos e imagens de
cartão SD; na dúvida, pergunte item por item.

## Passo 6: mover pastas para outro disco (sem quebrar apps)

```powershell
& "$sk\mover-pasta.ps1" -Source "$env:USERPROFILE\Videos\NVIDIA" -Target 'D:\Videos\NVIDIA'
```

O script move com robocopy (código 0–7 = sucesso; 1 = copiou), confere por hash o que sobrar e
cria uma **junction** no caminho antigo. O app continua gravando no mesmo lugar e os arquivos vão
para o outro disco. Serve para Desktop, Videos e Documents de jogos. Avise o usuário: a pasta
continua aparecendo no C:, e apagá-la apaga os arquivos no destino. Confira antes se o destino
é NTFS e tem espaço.

## Passo 7: jogos e programas

- Prefira o desinstalador do launcher ou o `UninstallString` em
  `HKLM/HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*`.
- Jogo da Epic sem desinstalador (launcher fechado): guarde cópia de
  `C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests\<id>.item` e
  `C:\ProgramData\Epic\UnrealEngineLauncher\LauncherInstalled.dat`. Depois remova o `.item`, tire a
  entrada do jogo (AppName) do `.dat` e apague a pasta do jogo.

## Passo 8: sistema (só com o usuário)

- Hibernação: `powercfg /h off` libera o tamanho do `hiberfil.sys`, mas desliga Hibernar e
  Inicialização Rápida. **Exige terminal de administrador**: passe o comando para o usuário.
- Pagefile: não mexa sem pedido explícito.
- Limpeza do Windows Update/componentes: `cleanmgr` ou Configurações → Armazenamento, feito pelo usuário.

## Fechamento

Mostre: espaço livre antes → depois, uma tabela do que foi feito, **onde estão os backups**
(destaque segredos e chaves que foram salvos), o que ficou de propósito e próximos passos numerados
(o que o usuário precisa fazer, como comandos que exigem admin).
