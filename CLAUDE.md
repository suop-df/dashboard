# CLAUDE.md — Dashboards Fiscais GDF

Documento de contexto para o Claude Code. Leia este arquivo antes de qualquer intervenção no projeto.

---

## Visão Geral

Dashboards interativos de execução orçamentária do Governo do Distrito Federal, publicados via **GitHub Pages** e alimentados por ETL automatizado a partir do banco Oracle.

- **Organização GitHub:** suop-df
- **Repositório:** publico
- **URL pública:** https://suop-df.github.io/publico/
- **Responsável técnico:** James (james.coelho) — ContDF/SEEC

---

## Arquitetura

```
Oracle (ORAPRD06)  →  etl.py (Python + oracledb)
                        ├── data/gz/*.json.gz  →  git push  →  GitHub Pages  (fonte primária)
                        └── upsert             →  Supabase                   (contingência automática)
                                                        ↓
                                               Dashboards HTML
                              (browser busca gz; se falhar, busca Supabase automaticamente)
```

### Decisões de arquitetura

- **GitHub Pages como fonte primária:** os gz são rápidos, sem dependência de API externa e sem custo.
- **Supabase como contingência passiva:** ativo apenas em caso de falha do GitHub Pages — o usuário não percebe a troca. Não é fonte primária.
- **Estratégia híbrida de armazenamento (Supabase ano corrente + gz histórico) foi analisada e descartada:** com teto de 4 anos e tabelas pequenas (exceto despesa), o free tier comporta todos os dados sem necessidade de arquivamento por ano.
- **gz em vez de JSON puro:** compressão nível 9 — o `despesa.json.gz` tem ~17MB comprimido versus centenas de MB em JSON. Essencial para GitHub Pages.
- **Runner self-hosted:** o banco Oracle está na rede interna do GDF, inacessível de runners hospedados pelo GitHub. O runner roda na estação de trabalho do james.coelho.

---

## Dados — Características importantes

- Os dados Oracle são sempre **D-1** (dia anterior), atualizados às **23:00** do dia anterior.
- Os dados **não se alteram durante o dia corrente (D-0)**.
- O ETL é agendado para rodar às **06:00 AM Brasília (09:00 UTC)** — antes dos usuários iniciarem o expediente — para garantir que os dashboards estejam com D-1 ao longo do dia.
- O schema Oracle usado é dinâmico: `mil{ano}` (ex: `mil2026`). Controlado pela variável `SCHEMA_ANO` no `etl.py`.

---

## ETL — etl.py

### Datasets gerados

| Arquivo gz | SQL | Transformação |
|---|---|---|
| `receita.json.gz` | `RECEITA.sql` | direto |
| `despesa.json.gz` | `DESPESA.sql` | direto + deduplicação |
| `rcl.json.gz` | `receita_RCL.sql` | `build_rcl_data()` — agregação complexa por regras ContDF |
| `restos_a_pagar.json.gz` | `restos_a_pagar.sql` | direto |

### Estrutura dos gz

Todos os gz seguem o mesmo envelope:
```json
{
  "atualizado_em": "2026-04-28T09:08:00+00:00",
  "total": 12345,
  "dados": [ ... ]
}
```

### Variáveis de ambiente (.env / GitHub Secrets)

| Variável | Descrição |
|---|---|
| `DB_USER` | Usuário Oracle |
| `DB_PASSWORD` | Senha Oracle |
| `DB_DSN` | `10.69.1.118:1521/oraprd06` |
| `ORACLE_CLIENT_PATH` | Vazio = thin mode (não precisa de client instalado) |
| `DB_MIN_CONNECTIONS` | Mínimo do pool (default: 1) |
| `DB_MAX_CONNECTIONS` | Máximo do pool (default: 5) |
| `DB_INCREMENT_CONNECTIONS` | Incremento do pool (default: 1) |
| `FCDF_PATH` | Caminho do arquivo XLSX do FCDF (Despesa de Pessoal UFIS/SIAFE) |
| `SUPABASE_URL` | URL do projeto Supabase |
| `SUPABASE_KEY` | Chave anon/service do Supabase |

### Executar manualmente

```cmd
py etl.py
```

### Instalar dependências

```cmd
py -m pip install -r requirements.txt
```

---

## GitHub Actions — Workflow

Arquivo: `.github/workflows/etl.yml`

```yaml
on:
  schedule:
    - cron: "0 9 * * *"   # 09:00 UTC = 06:00 Brasília
  workflow_dispatch:        # disparo manual pela interface do GitHub
```

- `runs-on: self-hosted` — obrigatório, por causa do acesso ao Oracle interno.
- O workflow faz checkout, instala dependências, roda `py etl.py`, e commita os gz gerados de volta ao repositório.
- O passo de commit usa `git diff --staged --quiet` para só fazer push se houver alterações.
- **Atenção:** o arquivo `.yml` deve conter texto puro — nunca links Markdown. O GitHub Pages falha silenciosamente se o YAML tiver sintaxe inválida (sem exibir erro no Actions).

### Disparo alternativo via API (agendador Windows)

Para não depender da instabilidade do cron do GitHub Actions (free tier), foi criado um script PowerShell que dispara o workflow via API:

```powershell
# E:\Actions-runner\disparar-etl.ps1
$token    = "SEU_PAT_AQUI"
$owner    = "suop-df"
$repo     = "dashboard"
$workflow = "etl.yml"
$branch   = "main"

$headers = @{ Authorization = "Bearer $token"; Accept = "application/vnd.github+json" }
$body    = @{ ref = $branch } | ConvertTo-Json

Invoke-RestMethod -Method Post `
    -Uri "https://api.github.com/repos/$owner/$repo/actions/workflows/$workflow/dispatches" `
    -Headers $headers -Body $body -ContentType "application/json"
```

Tarefa agendada Windows para rodar às 06:00 Brasília:
```powershell
$action    = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NonInteractive -File E:\Actions-runner\disparar-etl.ps1"
$trigger   = New-ScheduledTaskTrigger -Daily -At "06:00"
$settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
$principal = New-ScheduledTaskPrincipal -UserId "james.coelho" -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName "DisparadorETL" -Action $action -Trigger $trigger -Settings $settings -Principal $principal
```

---

## Runner Self-Hosted

- **Localização:** `E:\Actions-runner\`
- **Usuário:** seap\james.coelho
- **Inicialização:** Agendador de Tarefas do Windows (`GitHubActionsRunner`), trigger `AtLogOn`, via `run-hidden.vbs` (sem janela).
- **Suspensão:** desativada nas Configurações de Energia da máquina.

### Recriar tarefas agendadas (PowerShell admin)

Ver script `E:\Actions-runner\setup-tarefas-admin.ps1` ou consultar memória do projeto.

```powershell
# IMPORTANTE: usar AtLogOn, NÃO AtStartup
$action    = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "E:\Actions-runner\run-hidden.vbs"
$trigger   = New-ScheduledTaskTrigger -AtLogOn -User "seap\james.coelho"
$settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 0
$principal = New-ScheduledTaskPrincipal -UserId "seap\james.coelho" -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName "GitHubActionsRunner" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
Start-ScheduledTask -TaskName "GitHubActionsRunner"
```

---

## Supabase — Contingência

- **Projeto:** free tier, criado com login GitHub do james.coelho.
- **URL:** `https://otrlwfdtdrqpynemoexj.supabase.co`
- **Tabelas:** `receita`, `despesa`, `rcl`, `restos_a_pagar`
- **Política:** Row Level Security ativada em todas as tabelas.
- **Integração GitHub → Supabase:** conectada no painel, mas não usada no projeto (sem migrations automáticas). Inofensiva.
- O ETL faz upsert paralelo no Supabase após gerar os gz. Em caso de falha do Supabase, o ETL continua sem interromper.
- Os dashboards tentam gz primeiro. Se falhar, caem automaticamente no Supabase. Testado e validado via bloqueio de URL no DevTools (26/04/2026).

---

## CDN do GitHub Pages — Comportamento de Cache

- O GitHub Pages usa CDN (Fastly). Os gz são cacheados por alguns minutos a horas dependendo do edge node.
- Após o ETL atualizar os gz, há uma janela em que o CDN ainda serve a versão anterior.
- **Esse risco é aceito:** como o ETL roda às 06:00 e os usuários abrem os dashboards tipicamente depois das 08:00, o CDN já terá expirado o cache.
- Se necessário no futuro, o cache-busting pode ser implementado adicionando `?v=' + new Date().toISOString().slice(0,10)` na URL do `fetchJsonGz` em cada dashboard.

---

## Dashboards — Estrutura HTML

Cada dashboard é um HTML estático com:
- Fetch do gz via `fetchJsonGz(url)` com fallback automático para Supabase.
- Visualizações com **ECharts** (treemap, gauge, tabelas).
- Campo `atualizado_em` exibido no cabeçalho, lido do gz ou do max das linhas do Supabase.
- Brasão do DF carregado de `tools/Brasão_do_Distrito_Federal_Brasil.png`.
- Botão **← Voltar** no cabeçalho, respeitando a hierarquia de navegação.

### Navegação atual

```
index.html (raiz)
├── balanco_orcamentario/index.html
│   ├── receita_orcamentaria.html
│   └── despesa_orcamentaria.html
├── rcl/index.html
└── restos_a_pagar/index.html
```

> `funcao-subfuncao/` está sendo removido do projeto.

---

## Adicionar Novo Dashboard

1. Criar pasta (ex: `resultado-primario/`)
2. Desenvolver `index.html` seguindo o padrão visual dos existentes
3. Adicionar query SQL em `data/queries/`
4. Registrar a query em `etl.py` na lista `QUERIES`
5. Adicionar link no `index.html` raiz ou no menu da seção correspondente
6. Botão **← Voltar** no cabeçalho

---

## Git — Comandos Frequentes

```powershell
# Ver histórico
git log --oneline

# Restaurar arquivo para versão de commit anterior
git checkout <hash> -- caminho/arquivo.html

# Desfazer último commit de forma segura
git revert HEAD --no-edit
git push

# Se aparecer index.lock travado
Remove-Item E:\Projetos\publico\.git\index.lock -Force

# Pull com rebase (quando o remote tem commits que o local não tem)
git pull --rebase
git push
```

---

## Roadmap

### ✅ Concluído

- Pipeline Oracle → ETL Python → JSON.gz → GitHub Pages
- Dashboards: RCL, Receita Orçamentária, Despesa Orçamentária, Restos a Pagar
- Runner self-hosted com GitHub Actions (schedule diário 06:00 Brasília)
- Treemap ECharts em receita e despesa (composição por espécie/GND)
- Gauge + treemap lado a lado acima dos dados detalhados
- Supabase como contingência: upsert paralelo nas 4 tabelas; fallback automático nos dashboards

### 📌 Pendente

**Ambiente de Homologação (branch `dev`)**
- Criar branch `dev` com workflow `etl-dev.yml` separado
- Permite validar novas queries, mudanças no ETL e novos dashboards antes de ir para `main`

**Filtro Bimestral nos Dashboards**
- Adicionar visualização "no mês" além do atual "acumulado até o mês"
- Analisado e adiado por decisão do usuário

---

## Contexto de Desenvolvimento

- Este projeto foi desenvolvido inteiramente via **Claude Cowork** (desktop).
- A migração para **Claude Code** (CLI) está planejada — use este CLAUDE.md como ponte de contexto.
- O repositório local fica em `E:\Projetos\publico` na máquina do james.coelho.
- Usar `py` em vez de `python` ou `python3` no Windows desta máquina.
