# limpar-armazenamento

**Agent Skill** que **diagnostica e libera espaço em disco no Windows sem perder trabalho**.
Funciona com **qualquer agente de IA** que leia skills no formato aberto `SKILL.md` e rode comandos
no seu PC: Claude Code, OpenAI Codex, Cursor, Gemini CLI, GitHub Copilot, OpenCode, Windsurf e
outros.

Você pede "meu SSD está cheio, libera espaço" e o agente:

1. mede o disco por pasta (em minutos, inclusive pastas com `node_modules`);
2. mostra uma tabela com onde está o espaço e o que dá para liberar, com ganho e risco;
3. **só apaga o que você aprovar**;
4. guarda backup de tudo que só existe no seu PC (alterações não commitadas, commits não
   enviados, `.env`, chaves) **antes** de remover qualquer coisa.

Ela nasceu de uma limpeza real: um SSD de 1 TB com 9 GB livres ficou com 371 GB livres. Não precisou
reduzir o pagefile nem perder nenhum trabalho.

---

## Instalação

Requisitos: Windows 10/11, um agente de IA que execute comandos no terminal, `git` e PowerShell 7
(`pwsh`), que é o recomendado.

### Opção A: `npx skills` (instala para os agentes que você tem)

Com Node.js instalado, o instalador aberto [`skills`](https://www.npmjs.com/package/skills) detecta
os agentes da máquina e coloca a skill na pasta certa de cada um:

```bash
npx skills add GiovanniBot/limpar-armazenamento -g
```

`-g` instala para todos os projetos. Para escolher o agente, use `-a`, por exemplo `-a codex` ou
`-a claude-code`. Depois: `npx skills update` atualiza e `npx skills remove limpar-armazenamento`
remove.

### Opção B: `git clone` na pasta de skills do seu agente

Clone direto na pasta de skills do agente que você usa:

| Agente | Pasta de skills (global) |
|---|---|
| Padrão aberto (lido por vários agentes) | `%USERPROFILE%\.agents\skills` |
| Claude Code | `%USERPROFILE%\.claude\skills` |
| OpenAI Codex | `%USERPROFILE%\.codex\skills` |
| Cursor | `%USERPROFILE%\.cursor\skills` |
| Gemini CLI | `%USERPROFILE%\.gemini\skills` |
| GitHub Copilot | `%USERPROFILE%\.copilot\skills` |

Exemplo no PowerShell (troque `.agents` pela pasta do seu agente):

```powershell
git clone https://github.com/GiovanniBot/limpar-armazenamento "$env:USERPROFILE\.agents\skills\limpar-armazenamento"
```

Para atualizar: `git -C "$env:USERPROFILE\.agents\skills\limpar-armazenamento" pull`.

As pastas mudam de versão para versão. Se o seu agente não achar a skill, veja na documentação dele
onde ficam as skills e clone lá.

### Opção C: sem git (zip)

```powershell
$dest = "$env:USERPROFILE\.agents\skills"   # troque pela pasta do seu agente
New-Item -ItemType Directory -Force $dest | Out-Null
Invoke-WebRequest https://github.com/GiovanniBot/limpar-armazenamento/archive/refs/heads/main.zip -OutFile "$env:TEMP\limpar-armazenamento.zip"
Expand-Archive "$env:TEMP\limpar-armazenamento.zip" -DestinationPath $dest -Force
Remove-Item "$dest\limpar-armazenamento" -Recurse -Force -ErrorAction SilentlyContinue
Rename-Item "$dest\limpar-armazenamento-main" "limpar-armazenamento"
```

### Opção D: pedir para o próprio agente instalar

Cole isto no chat do seu agente:

> Instale a Agent Skill de https://github.com/GiovanniBot/limpar-armazenamento na sua pasta de
> skills globais (clone o repositório numa subpasta `limpar-armazenamento`) e confirme que o
> SKILL.md ficou lá.

### Agente sem suporte a skills?

Funciona mesmo assim: clone o repositório em qualquer pasta e diga ao agente
*"leia `<pasta>\limpar-armazenamento\SKILL.md` e siga as instruções para liberar espaço no meu disco"*.

### Conferir

Abra **uma conversa nova** (os agentes carregam as skills no início) e pergunte
"quais skills você tem?". A `limpar-armazenamento` deve aparecer. Em agentes com comandos `/`,
ela costuma aparecer como `/limpar-armazenamento`.

---

## Como usar

Peça com suas palavras, por exemplo:

- "meu disco C: está cheio, o que está ocupando espaço?"
- "libera espaço no SSD"
- "use a skill limpar-armazenamento"

O fluxo é sempre o mesmo:

| Etapa | O que o agente faz | Apaga algo? |
|---|---|---|
| 1. Medir | Tamanho por pasta do C:, do seu usuário e do AppData | Não |
| 2. Propor | Tabela "o que dá para liberar, quanto, qual o risco" | Não |
| 3. Você escolhe | Você responde o que pode (ex.: "caches sim, pagefile não") | n/a |
| 4. Backup | Guarda no disco de backup o que não está no GitHub | Não |
| 5. Limpar | Remove só o aprovado, um passo por vez, mostrando o ganho | Sim, só o aprovado |
| 6. Relatório | Antes → depois, onde ficaram os backups, próximos passos | Não |

### O que ela sabe limpar

- **Worktrees git de agentes de IA** (Claude Code, Codex, Cursor e outros): costuma ser o maior
  ganho. Cada worktree tem seu próprio `node_modules`, builds e arquivos temporários.
- **Docker**: imagens e cache de build antigos (mantém o recente) e Docker Desktop sem uso.
- **Caches**: shaders da NVIDIA, Gradle, npm, pnpm, Chrome/Edge e Temp.
- **Downloads**: instaladores e ISOs. Fotos, vídeos e documentos ficam.
- **Pastas grandes para outro disco** (gravações NVIDIA, Capturas, Desktop): com um atalho de
  sistema (junction) no lugar antigo, os apps nem percebem.
- **Jogos e programas**: desinstala pelo caminho oficial.
- **Hibernação**: passa o comando para você rodar como administrador.

### O que ela nunca faz sozinha

- Apagar sem você aprovar naquela conversa.
- Remover o checkout principal de um repositório.
- Mexer em worktrees modificadas há menos de 2 dias (podem estar em uso por um agente).
- Alterar pagefile, rodar comandos de administrador ou contornar bloqueios de permissão.

---

## Scripts incluídos

Ficam em `scripts\`. O agente chama todos sozinho, mas você também pode rodá-los à mão no PowerShell:

| Script | O que faz |
|---|---|
| `medir-pastas.ps1 -Root C:\` | Tamanho das subpastas (robocopy em paralelo, ignora junctions) |
| `inventario-worktrees.ps1 -Out inv.csv` | Acha repositórios e worktrees e diz o que está sujo, não enviado ou mergeado |
| `backup-worktrees.ps1 -Csv inv.csv -BackupRoot D:\Backups\wt` | **Só backup**: patch, arquivos novos, bundle de commits e `.env` |
| `remover-worktrees.ps1 -Log D:\Backups\wt\backup-log.txt` | Remove só as worktrees com backup OK |
| `mover-pasta.ps1 -Source <C:\...> -Target <D:\...>` | Move com verificação e cria junction |

### Restaurar uma worktree do backup

```powershell
git worktree add C:\caminho\nova <branch>
git -C C:\caminho\nova apply D:\Backups\wt\<nome>\alteracoes.patch
# se houver commits-nao-enviados.bundle:
git -C C:\caminho\nova fetch D:\Backups\wt\<nome>\commits-nao-enviados.bundle HEAD:recuperado
```

---

## Licença

MIT. Use, adapte e compartilhe.
