# limpar-armazenamento

Skill para o [Claude Code](https://claude.com/claude-code) que **diagnostica e libera espaço em
disco no Windows sem perder trabalho**.

Você pede "meu SSD está cheio, libera espaço" e o Claude:

1. mede o disco por pasta (em minutos, inclusive pastas com `node_modules`);
2. mostra uma tabela com onde está o espaço e o que dá para liberar, com ganho e risco;
3. **só apaga o que você aprovar**;
4. guarda backup de tudo que só existe no seu PC (alterações não commitadas, commits não
   enviados, `.env`, chaves) **antes** de remover qualquer coisa.

Ela nasceu de uma limpeza real: um SSD de 1 TB com 9 GB livres ficou com 371 GB livres. Não precisou
reduzir o pagefile nem perder nenhum trabalho.

---

## Instalação

Requisitos: Windows 10/11, [Claude Code](https://docs.claude.com/en/docs/claude-code/overview),
`git` e PowerShell 7 (`pwsh`), que é o recomendado.

### Opção A: com git (recomendado, fica fácil atualizar)

No PowerShell:

```powershell
git clone https://github.com/GiovanniBot/limpar-armazenamento "$env:USERPROFILE\.claude\skills\limpar-armazenamento"
```

Para atualizar depois:

```powershell
git -C "$env:USERPROFILE\.claude\skills\limpar-armazenamento" pull
```

### Opção B: sem git (baixa o zip)

```powershell
$dest = "$env:USERPROFILE\.claude\skills"
New-Item -ItemType Directory -Force $dest | Out-Null
Invoke-WebRequest https://github.com/GiovanniBot/limpar-armazenamento/archive/refs/heads/main.zip -OutFile "$env:TEMP\limpar-armazenamento.zip"
Expand-Archive "$env:TEMP\limpar-armazenamento.zip" -DestinationPath $dest -Force
Remove-Item "$dest\limpar-armazenamento" -Recurse -Force -ErrorAction SilentlyContinue
Rename-Item "$dest\limpar-armazenamento-main" "limpar-armazenamento"
```

### Opção C: pedir para o próprio Claude instalar

Cole isto num chat do Claude Code:

> Instale a skill de https://github.com/GiovanniBot/limpar-armazenamento clonando o repositório em
> `~/.claude/skills/limpar-armazenamento` e confirme que o arquivo SKILL.md ficou lá.

### Conferir

O arquivo precisa ficar exatamente em:

```
C:\Users\<seu-usuario>\.claude\skills\limpar-armazenamento\SKILL.md
```

Abra **um chat novo** no Claude Code (as skills são carregadas no início do chat) e digite
`/limpar-armazenamento`. Se ela aparecer na lista do `/`, está instalada.

---

## Como usar

Em qualquer chat do Claude Code, peça com suas palavras, por exemplo:

- "meu disco C: está cheio, o que está ocupando espaço?"
- "libera espaço no SSD"
- `/limpar-armazenamento`

O fluxo é sempre o mesmo:

| Etapa | O que o Claude faz | Apaga algo? |
|---|---|---|
| 1. Medir | Tamanho por pasta do C:, do seu usuário e do AppData | Não |
| 2. Propor | Tabela "o que dá para liberar, quanto, qual o risco" | Não |
| 3. Você escolhe | Você responde o que pode (ex.: "caches sim, pagefile não") | n/a |
| 4. Backup | Guarda no disco de backup o que não está no GitHub | Não |
| 5. Limpar | Remove só o aprovado, um passo por vez, mostrando o ganho | Sim, só o aprovado |
| 6. Relatório | Antes → depois, onde ficaram os backups, próximos passos | Não |

### O que ela sabe limpar

- **Worktrees git de agentes de IA** (Claude Code, Codex e outros): costuma ser o maior ganho.
  Cada worktree tem seu próprio `node_modules`, builds e arquivos temporários.
- **Docker**: imagens e cache de build antigos (mantém o recente) e Docker Desktop sem uso.
- **Caches**: shaders da NVIDIA, Gradle, npm, pnpm, Chrome/Edge e Temp.
- **Downloads**: instaladores e ISOs. Fotos, vídeos e documentos ficam.
- **Pastas grandes para outro disco** (gravações NVIDIA, Capturas, Desktop): com um atalho de
  sistema (junction) no lugar antigo, os apps nem percebem.
- **Jogos e programas**: desinstala pelo caminho oficial.
- **Hibernação**: passa o comando para você rodar como administrador.

### O que ela nunca faz sozinha

- Apagar sem você aprovar naquele chat.
- Remover o checkout principal de um repositório.
- Mexer em worktrees modificadas há menos de 2 dias (podem estar em uso).
- Alterar pagefile, rodar comandos de administrador ou contornar bloqueios de permissão.

---

## Scripts incluídos

Ficam em `scripts\`. O Claude chama todos sozinho, mas você também pode rodá-los à mão:

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
