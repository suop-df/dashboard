# Dashboards Fiscais

Dashboards interativos de execução orçamentária do Governo do Distrito Federal, publicados via GitHub Pages e alimentados por ETL automatizado a partir do banco Oracle.

🔗 **Acesso público:** https://suop-df.github.io/publico/

---

## Arquitetura

```
Oracle (ORAPRD06)
    ↓ etl.py  (Python + oracledb)
    ├── data/gz/*.json.gz  →  git push  →  GitHub Pages  (fonte primária)
    └── upsert             →  Supabase                   (contingência)
                                  ↓
                         Dashboards HTML
                   (browser busca gz; se falhar, busca Supabase automaticamente)
```

O ETL roda automaticamente todo dia às **06:00 (horário de Brasília)** via GitHub Actions com runner self-hosted instalado na estação de trabalho do James (james.coelho).

---

## Contingência Supabase

O projeto utiliza o **Supabase** como camada de contingência para os dados. A cada execução do ETL, além de gerar os arquivos `json.gz` e commitá-los no GitHub, os dados são enviados simultaneamente para um banco PostgreSQL no Supabase via upsert.

### Como funciona o fallback nos dashboards

Cada dashboard tenta carregar os dados na seguinte ordem:

1. **Busca o `json.gz` no GitHub Pages** (fonte primária — rápida e sem dependência externa)
2. **Se falhar** (GitHub Pages indisponível, erro de rede) → **busca automaticamente no Supabase**
3. O usuário não percebe a troca — o dashboard carrega normalmente em ambos os casos

```javascript
fetchJsonGz('../data/gz/receita.json.gz')
  .catch(function() { return fetchSupabaseReceita(); })  // fallback automático
  .then(function(json) { /* processa normalmente */ })
```

### Tabelas no Supabase

| Tabela | Conteúdo |
|--------|----------|
| `receita` | Receita orçamentária — linhas por conta contábil e mês |
| `despesa` | Despesa orçamentária — linhas por conta contábil e mês |
| `rcl` | Receita Corrente Líquida — estrutura pré-agregada por ano |
| `restos_a_pagar` | Restos a pagar — linhas por UG, categoria e GND |

### Secrets adicionais necessários

| Secret | Descrição |
|--------|-----------|
| `SUPABASE_URL` | URL do projeto Supabase (ex: `https://xxxx.supabase.co`) |
| `SUPABASE_KEY` | Chave anon/service do Supabase |

---

## Estrutura do projeto

```
├── index.html                          # Página inicial — links para os dashboards
├── etl.py                              # ETL: Oracle → JSON.GZ
├── requirements.txt                    # Dependências Python
├── .env                                # Credenciais (não versionado)
├── .github/
│   └── workflows/
│       └── etl.yml                     # Workflow de automação (Actions)
├── data/
│   ├── gz/                             # Arquivos comprimidos (commitados)
│   │   ├── despesa.json.gz
│   │   ├── receita.json.gz
│   │   ├── rcl.json.gz                 # Estrutura D pré-agregada (gerada por build_rcl_data)
│   │   └── saldo_funcao_subfuncao.json.gz
│   └── queries/                        # SQLs das extrações
│       ├── DESPESA.sql
│       ├── RECEITA.sql
│       ├── receita_RCL.sql             # SQL da RCL (retorna linhas brutas por conta)
│       └── saldocontabil_funcao_subfuncao.sql
├── balanco_orcamentario/
│   ├── index.html                      # Menu: Receita e Despesa
│   ├── receita_orcamentaria.html       # Dashboard de Receita
│   └── despesa_orcamentaria.html       # Dashboard de Despesa
├── funcao-subfuncao/
│   └── index.html                      # Dashboard Função e Subfunção
├── rcl/
│   └── index.html                      # Dashboard Receita Corrente Líquida (RREO)
└── tools/
    └── Brasão_do_Distrito_Federal_Brasil.png
```

---

## Configuração do ambiente

### 1. Pré-requisitos

- Python 3.10+
- Acesso à rede do GDF (VPN ou máquina interna)
- Oracle Instant Client (opcional — thin mode não precisa)

### 2. Instalar dependências

```cmd
py -m pip install -r requirements.txt
```

### 3. Configurar credenciais

Crie o arquivo `.env` na raiz do projeto:

```env
DB_USER=seu_usuario
DB_PASSWORD=sua_senha
DB_DSN=10.69.1.118:1521/oraprd06
ORACLE_CLIENT_PATH=          # deixe vazio para thin mode
DB_MIN_CONNECTIONS=1
DB_MAX_CONNECTIONS=5
DB_INCREMENT_CONNECTIONS=1
```

### 4. Executar o ETL manualmente

```cmd
py etl.py
```

Os arquivos `.json.gz` serão gerados em `data/gz/`.

---

## GitHub Actions — Runner self-hosted

O workflow `etl.yml` roda no servidor do GDF via runner self-hosted instalado em `D:\Actions-runner` na estação de trabalho do James (james.coelho). A suspensão da máquina está desativada (Configurações de Energia) e o runner é iniciado automaticamente via **Agendador de Tarefas do Windows** a cada inicialização.

### Registrar o runner

1. Acesse: `github.com/suop-df/publico` → Settings → Actions → Runners → **New self-hosted runner**
2. Siga as instruções para Windows
3. Configure com:
   ```cmd
   .\config.cmd --url https://github.com/suop-df/publico --token <TOKEN>
   ```
4. Inicie o runner:
   ```cmd
   .\run.cmd
   ```

### Iniciar automaticamente com o Windows (Agendador de Tarefas)

Caso o runner não esteja configurado como serviço, use o Agendador de Tarefas para iniciá-lo automaticamente. Execute no **PowerShell ISE como administrador**:

```powershell
$action   = New-ScheduledTaskAction -Execute "D:\Actions-runner\run.cmd"
$trigger  = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 0
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "GitHubActionsRunner" -Action $action -Trigger $trigger -Settings $settings -Principal $principal
```

Para iniciar imediatamente sem reiniciar:

```powershell
Start-ScheduledTask -TaskName "GitHubActionsRunner"
```

Para verificar o status:

```powershell
Get-ScheduledTask -TaskName "GitHubActionsRunner" | Select-Object State
```

### Secrets necessários no repositório

Configure em Settings → Secrets → Actions:

| Secret | Descrição |
|--------|-----------|
| `DB_USER` | Usuário Oracle |
| `DB_PASSWORD` | Senha Oracle |
| `DB_DSN` | DSN de conexão |
| `ORACLE_CLIENT_PATH` | Caminho do Oracle Client (vazio = thin mode) |
| `DB_MIN_CONNECTIONS` | Mínimo de conexões no pool |
| `DB_MAX_CONNECTIONS` | Máximo de conexões no pool |
| `DB_INCREMENT_CONNECTIONS` | Incremento do pool |
| `SUPABASE_URL` | URL do projeto Supabase |
| `SUPABASE_KEY` | Chave anon/service do Supabase |

---

## Colaboradores — como contribuir

Colaboradores não precisam de acesso à pasta local do administrador. O fluxo é:

### 1. Clonar o repositório

```cmd
git clone https://github.com/suop-df/publico.git
```

Isso baixa uma cópia completa do projeto para a máquina do colaborador.

### 2. Desenvolver localmente

Criar a pasta do novo dashboard, desenvolver o `index.html` seguindo o padrão visual do projeto e adicionar a query SQL em `data/queries/`.

### 3. Enviar para o GitHub

```cmd
git add .
git commit -m "feat: novo dashboard RCL"
git push origin main
```

O GitHub centraliza tudo. Ninguém acessa a pasta do outro — cada um trabalha na sua cópia local e o repositório é o ponto de encontro.

### 4. Sincronizar após contribuição de outro colaborador

```cmd
git pull origin main
```

### Conceder acesso a colaboradores

Acesse `github.com/suop-df/publico` → **Settings → Collaborators → Add people** e adicione o usuário GitHub do colaborador.

---

## Reverter alterações com Git

### Ver histórico de commits

```cmd
git log --oneline
```

Exemplo de saída:
```
a1b2c3d fix: remove backslash antes do DOCTYPE
e4f5g6h feat: brasão via tools/ em todos os dashboards
f7h8i9j feat: navegação hierárquica - botão voltar por nível
```

### Recuperar um arquivo específico de um commit anterior

```cmd
git checkout <hash> -- nome-do-arquivo.html
```

Exemplo — restaurar a despesa para como estava em `e4f5g6h`:
```cmd
git checkout e4f5g6h -- balanco_orcamentario/despesa_orcamentaria.html
```

Após recuperar, commitar novamente:
```cmd
git add .
git commit -m "fix: reverte arquivo para versão anterior"
git push origin main
```

### Desfazer o último commit (mantendo os arquivos)

```cmd
git revert HEAD
git push origin main
```

### Voltar tudo para um commit específico (⚠️ irreversível)

```cmd
git reset --hard <hash>
git push origin main --force
```

> **Atenção:** `reset --hard` apaga permanentemente tudo que veio após aquele commit. Use com cautela.

---

## Adicionar novo dashboard

1. Crie uma pasta para o novo demonstrativo (ex: `resultado-primario/`)
2. Desenvolva o `index.html` seguindo o padrão visual dos dashboards existentes
3. Inclua o botão **← Voltar** no cabeçalho apontando para o nível anterior
4. Adicione a query SQL em `data/queries/` e registre em `etl.py` (lista `QUERIES`)
5. Adicione o link na página `index.html` da seção correspondente ou no `index.html` raiz

---

## Navegação

```
Início (index.html)
├── Balanço Orçamentário  →  balanco_orcamentario/index.html
│   ├── Receita Orçamentária
│   └── Despesa Orçamentária
├── Função e Subfunção    →  funcao-subfuncao/index.html
└── Receita Corrente Líquida  →  rcl/index.html
```

---

*suop-df/SEEC — Secretaria Excutiva de Orçamento, Finanças e Planejamento*
