# Roadmap — Dashboards Fiscais GDF

> Registro dos planos de evolução do projeto. Atualizado em 04/05/2026.

---

## 📌 Pendente — Colaboração Multi-estação

### Objetivo
Permitir que múltiplos colaboradores trabalhem em paralelo no repositório, cada um em sua própria estação, sem interferir no trabalho uns dos outros.

### Premissas
- ETL permanece **centralizado na máquina do james.coelho** (único acesso ao Oracle)
- Dashboard HTML pode ser desenvolvido em qualquer estação usando os gz já commitados
- Cada colaborador trabalha num dashboard diferente (conflitos raros)

### O que cada colaborador precisa
1. Conta GitHub — james.coelho adiciona via `Settings → Collaborators`
2. Git instalado na estação
3. Clone do repositório: `git clone https://github.com/suop-df/dashboard`
4. Os `data/gz/*.json.gz` commitados servem como dados de desenvolvimento local

### Fluxo de trabalho

```
Colaborador A                Colaborador B
feat/dashboard-x             feat/dashboard-y
      ↓ Pull Request               ↓ Pull Request
            main (james.coelho — revisor e merge)
                      ↓
                GitHub Pages (publicação automática)
                ETL (só na máquina do james.coelho)
```

```bash
git pull origin main                      # atualizar antes de começar
git checkout -b feat/nome-do-dashboard    # branch por tarefa
# desenvolver e testar localmente
git add . && git commit -m "feat: ..."
git push origin feat/nome-do-dashboard
# abrir Pull Request no GitHub para revisão
```

### Arquivos críticos — combinar antes de mexer
- `index.html` raiz (portal de navegação)
- `etl.py` (pipeline de dados)

Qualquer alteração nesses dois arquivos deve ser coordenada com james.coelho para evitar conflito de merge.

### Opcional: proteção da branch main
Em `Settings → Branches → Add rule` no GitHub:
- Exigir PR antes de merge (sem push direto para main)
- Garante que nada vai para produção sem revisão

---

## 📌 Pendente — Segundo Repositório: Dashboards Internos D-0

### Objetivo
Criar um segundo repositório GitHub público (`suop-df/relatorios`) para dashboards de uso interno com dados D-0 (Oracle em tempo real), atualizado várias vezes ao dia. O repositório existente (`dashboard`) não é alterado.

### Arquitetura

```
Repo 1 (existente)                    Repo 2 (novo)
suop-df/dashboard                suop-df/relatorios
──────────────────────                ──────────────────────
Oracle D-1 → etl.py                   Oracle D-0 → etl.py
→ data/gz/ → GitHub Pages             → data/gz/ → GitHub Pages
→ Supabase (tabelas atuais)           → Supabase (tabelas com sufixo _d0)
Cron: 1x/dia (06:00 Brasília)         Cron: 5x/dia (07,10,12,15,17h seg-sex)
Runner: D:\Actions-runner\            Runner: D:\Actions-runner-interno\
```

### Diferenças técnicas

| Aspecto | Repo público (D-1) | Repo interno (D-0) |
|---|---|---|
| Filtro de mês | `mesfechado` (meses fechados) | `EXTRACT(MONTH FROM SYSDATE)` (mês corrente aberto) |
| Frequência ETL | 1x/dia | 5x/dia (dias úteis) |
| Conteúdo | Dashboards existentes | Apenas novos relatórios |

### Implementação

1. **Criar repo** `suop-df/relatorios` no GitHub (público, GitHub Pages na `main`)
2. **Configurar Secrets** no novo repo: `DB_USER`, `DB_PASSWORD`, `DB_DSN`, `ORACLE_CLIENT_PATH`, `SUPABASE_URL`, `SUPABASE_KEY`, `PAT_TOKEN`
3. **Instalar segundo runner** na mesma máquina:
   ```powershell
   mkdir D:\Actions-runner-interno
   cd D:\Actions-runner-interno
   # Baixar mesma versão do runner existente
   .\config.cmd --url https://github.com/suop-df/relatorios --token <TOKEN>
   .\svc.cmd install GitHubActionsRunnerInterno
   .\svc.cmd start GitHubActionsRunnerInterno
   ```
4. **Criar `.github/workflows/etl.yml`** com cron `"0 10,13,15,18,20 * * 1-5"` (07–17h Brasília)
5. **Criar `etl.py`** — cópia do atual sem `FCDF_PATH`, com queries D-0 (sem `mesfechado`)
6. **Criar script de disparo** `D:\Actions-runner-interno\disparar-etl-interno.ps1` + tarefa agendada no Windows
7. **Criar tabelas Supabase** no mesmo projeto (sufixo `_d0`) conforme novos dashboards forem criados

### Arquivos a criar (no novo repo)

| Arquivo | Descrição |
|---|---|
| `etl.py` | ETL D-0 sem filtro mesfechado |
| `requirements.txt` | Igual ao repo público |
| `.github/workflows/etl.yml` | Cron múltiplo + workflow_dispatch |
| `CLAUDE.md` | Contexto do projeto interno |
| `index.html` | Portal de navegação |
| `data/queries/*.sql` | Novos SQLs sem filtro mesfechado |

### Observação
O plano detalhado está em `C:\Users\james.coelho\.claude\plans\esse-projeto-dever-ter-rippling-cerf.md`.

---

## ✅ Concluído

- Pipeline Oracle → ETL Python → JSON.gz → GitHub → GitHub Pages
- Dashboards: RCL, Receita Orçamentária, Despesa Orçamentária, Restos a Pagar, Resultado Primário e Nominal, Poupança Corrente (Art. 167-A CF)
- Runner self-hosted com GitHub Actions (schedule diário 06:00 Brasília)
- Treemap ECharts em receita e despesa (composição por espécie/GND)
- Supabase como contingência: ETL faz upsert paralelo nas tabelas; dashboards buscam gz do GitHub Pages e caem automaticamente no Supabase em caso de falha

---

## 📌 Pendente — Ambiente de Homologação (branch `dev`)

### Objetivo
Criar um ambiente de testes para validar novas queries, mudanças no ETL e novos dashboards antes de subir para produção.

### Implementação
1. Criar branch `dev` no repositório
2. Criar `.github/workflows/etl-dev.yml` — cópia do `etl.yml` com:
   - Trigger na branch `dev` (push ou `workflow_dispatch`)
   - Runner self-hosted (mesmo runner, mesmo Oracle)
   - Commit dos JSON.gz na própria branch `dev`
3. Fluxo de desenvolvimento:
   - Nova query em `data/queries/`
   - Ajuste no `etl.py`
   - Novo HTML do dashboard
   - Push para `dev` → Actions roda ETL → valida dados
4. Merge para produção quando validado:

```powershell
git checkout main
git merge dev
git push origin main
```

### Casos de uso
- Criação de novo demonstrativo (nova query + ETL + HTML)
- Mudanças estruturais no ETL
- Testes de novos componentes visuais nos dashboards

---

## ✅ Concluído — Supabase como Contingência

### Arquitetura implementada

```
ETL (etl.py)
  ├── gera gz  →  commit no GitHub  →  GitHub Pages  (produção, fonte primária)
  └── upsert   →  Supabase API      →  fallback automático nos HTMLs
```

### O que foi feito
- Projeto Supabase criado (free tier) com 4 tabelas: `receita`, `despesa`, `rcl`, `restos_a_pagar`
- Secrets `SUPABASE_URL` e `SUPABASE_KEY` configurados no GitHub
- `etl.py` adaptado: upsert paralelo no Supabase após gerar os gz
- Dashboards atualizados: tentam gz primeiro; se falhar, buscam Supabase automaticamente (sem intervenção do usuário)
- Testado e validado em 26/04/2026 via bloqueio de URL no DevTools

### Decisão de arquitetura
GitHub Pages permanece como fonte primária. Supabase é contingência passiva — ativo só em caso de falha. Estratégia híbrida de armazenamento descartada: com teto de 4 anos e tabelas pequenas (exceto despesa), o free tier comporta todos os dados sem necessidade de arquivamento em gz.

---

## 📌 Pendente — Filtro Bimestral nos Dashboards

### Objetivo
Adicionar opção de visualização "no mês" além do atual "acumulado até o mês" nos dashboards de receita e despesa orçamentária.

### Status
Ideia levantada, análise de viabilidade feita, implementação adiada por decisão do usuário.