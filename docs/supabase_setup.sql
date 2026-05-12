-- =============================================================
-- Supabase: criação das tabelas do projeto Dashboard Fiscal GDF
-- Execute no SQL Editor do Supabase (https://supabase.com/dashboard)
-- =============================================================

-- -------------------------------------------------------
-- FASE 1: restos_a_pagar
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS restos_a_pagar (
    id              BIGSERIAL PRIMARY KEY,
    ano             INTEGER        NOT NULL,
    coug            TEXT           NOT NULL,
    noug            TEXT,
    cocontacontabil INTEGER        NOT NULL,
    cat             TEXT,
    nocat           TEXT,
    gnd             TEXT,
    nognd           TEXT,
    saldo           NUMERIC(18,2),
    inmes           INTEGER        NOT NULL,
    atualizado_em   TIMESTAMPTZ    DEFAULT NOW(),
    UNIQUE (ano, coug, cocontacontabil, cat, gnd, inmes)
);

-- Permite leitura pública sem autenticação (dashboards públicos)
ALTER TABLE restos_a_pagar ENABLE ROW LEVEL SECURITY;
CREATE POLICY "leitura publica" ON restos_a_pagar
    FOR SELECT USING (true);

-- -------------------------------------------------------
-- FASE 2: receita
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS receita (
    id                       BIGSERIAL PRIMARY KEY,
    coexercicio              INTEGER        NOT NULL,
    inmes                    INTEGER        NOT NULL,
    coug                     INTEGER,
    noug                     TEXT,
    cocontacontabil          BIGINT,
    cocontacorrente          TEXT,
    vadebito                 NUMERIC(18,2),
    vacredito                NUMERIC(18,2),
    saldo                    NUMERIC(18,2),
    fonte                    TEXT,
    fonte_agrupada           TEXT,
    cofontefederal           TEXT,
    nome_fonte               TEXT,
    receita                  TEXT,
    nome_receita             TEXT,
    categoria_economica      TEXT,
    nome_categoria_economica TEXT,
    origem_receita           TEXT,
    nome_origem_receita      TEXT,
    especie_receita          TEXT,
    nome_especie_receita     TEXT,
    tipo_receita             TEXT,
    nome_tipo_receita        TEXT,
    detalhe_receita          TEXT,
    nome_detalhe_receita     TEXT,
    atualizado_em            TIMESTAMPTZ    DEFAULT NOW(),
    UNIQUE (coexercicio, inmes, coug, cocontacontabil, cocontacorrente)
);

ALTER TABLE receita ENABLE ROW LEVEL SECURITY;
CREATE POLICY "leitura publica" ON receita FOR SELECT USING (true);
CREATE POLICY "insert etl"      ON receita FOR INSERT WITH CHECK (true);
CREATE POLICY "update etl"      ON receita FOR UPDATE USING (true);

-- -------------------------------------------------------
-- FASE 2: despesa
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS despesa (
    id                       BIGSERIAL PRIMARY KEY,
    coexercicio              INTEGER        NOT NULL,
    inmes                    INTEGER        NOT NULL,
    coug                     INTEGER,
    noug                     TEXT,
    cocontacontabil          BIGINT,
    vadebito                 NUMERIC(18,2),
    vacredito                NUMERIC(18,2),
    saldo                    NUMERIC(18,2),
    despesa                  TEXT,
    nome_despesa             TEXT,
    categoria_economica      TEXT,
    nome_categoria_economica TEXT,
    gnd                      TEXT,
    nome_gnd                 TEXT,
    intra                    TEXT,
    cofonte                  TEXT,
    fonte_agrupada           TEXT,
    cofontefederal           TEXT,
    nome_fonte               TEXT,
    subelemento              TEXT,
    nome_subelemento         TEXT,
    cofuncao                 TEXT,
    nofuncao                 TEXT,
    cosubfuncao              TEXT,
    nosubfuncao              TEXT,
    atualizado_em            TIMESTAMPTZ    DEFAULT NOW(),
    UNIQUE (coexercicio, inmes, coug, cocontacontabil, despesa, cofonte)
);

ALTER TABLE despesa ENABLE ROW LEVEL SECURITY;
CREATE POLICY "leitura publica" ON despesa FOR SELECT USING (true);
CREATE POLICY "insert etl"      ON despesa FOR INSERT WITH CHECK (true);
CREATE POLICY "update etl"      ON despesa FOR UPDATE USING (true);

-- -------------------------------------------------------
-- FASE 2: rcl (armazenada como JSONB — 1 linha por ano)
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS rcl (
    id            BIGSERIAL PRIMARY KEY,
    ano           INTEGER     NOT NULL UNIQUE,
    dados         JSONB       NOT NULL,
    atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE rcl ENABLE ROW LEVEL SECURITY;
CREATE POLICY "leitura publica" ON rcl FOR SELECT USING (true);
CREATE POLICY "insert etl"      ON rcl FOR INSERT WITH CHECK (true);
CREATE POLICY "update etl"      ON rcl FOR UPDATE USING (true);
