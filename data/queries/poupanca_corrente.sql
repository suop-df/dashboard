-- poupanca_corrente.sql
-- Placeholder {SCHEMA_ANO} substituído pelo Python (ex: mil2026)
-- Schema mil2001 é fixo (saldocontabil_ex — view histórica)
--
-- POUPANÇA CORRENTE (Art. 167-A, CF):
--   = (Desp. Correntes 12m + RPNP Inscrito no exercício − RPNP Cancelado) / Rec. Corrente 12m
--
-- COMPONENTES:
--   Receita Corrente      : COCONTACONTABIL 621200000–621390199
--                           GND via SUBSTR(COCONTACORRENTE,1,1) IN (1,7)
--                           1 = Correntes | 7 = Intraorçamentárias Correntes
--
--   Despesas Liquidadas   : SUBSTR(COCONTACONTABIL,1,7) IN (6221303,6221304,6221307)
--                           GND via SUBSTR(CONATUREZA,2,1) IN (1,2,3)
--
--   RPNP Inscrito         : COCONTACONTABIL IN (631100000,631200000)
--                           GND via SUBSTR(CONATUREZA,2,1) IN (1,2,3) | INMES=0
--
--   RPNP Cancelado        : COCONTACONTABIL IN (631900000)
--                           GND via SUBSTR(CONATUREZA,2,1) IN (1,2,3,7)
--
-- GND (despesas) derivado de CONATUREZA: SUBSTR(CONATUREZA,2,1)
--   1 = Pessoal e Encargos (31xxxxx)
--   2 = Juros e Encargos   (32xxxxx)
--   3 = Outras Correntes   (33xxxxx)
--   7 = Reserva RPPS       (37xxxxx)

SELECT
    s.coexercicio,
    s.inmes,
    s.cocontacontabil,
    s.cocontacorrente,
    s.conatureza,
    s.vacredito,
    s.vadebito,
    (SELECT MAX(m.inmes)
       FROM {SCHEMA_ANO}.mesfechado m
      WHERE m.inmes BETWEEN 1 AND 12)  AS max_mes_fechado
FROM mil2001.saldocontabil_ex s
WHERE (

    -- ── RECEITA CORRENTE REALIZADA ──────────────────────────────────────
    (   s.cocontacontabil BETWEEN 621200000 AND 621390199
    AND SUBSTR(TO_CHAR(s.cocontacorrente), 1, 1) IN ('1', '7')
    AND s.inmes BETWEEN 1 AND 12)

  OR

    -- ── DESPESAS LIQUIDADAS (correntes) ─────────────────────────────────
    (   SUBSTR(TO_CHAR(s.cocontacontabil), 1, 7) IN ('6221303', '6221304', '6221307')
    AND SUBSTR(s.conatureza, 2, 1) IN ('1', '2', '3')
    AND s.inmes BETWEEN 1 AND 12)

  OR

    -- ── RPNP INSCRITO no encerramento do exercício (inmes=0) ─────────────
    (   s.cocontacontabil IN (631100000, 631200000)
    AND SUBSTR(s.conatureza, 2, 1) IN ('1', '2', '3')
    AND s.inmes = 0)

  OR

    -- ── RPNP CANCELADO ──────────────────────────────────────────────────
    (   s.cocontacontabil IN (631900000)
    AND SUBSTR(s.conatureza, 2, 1) IN ('1', '2', '3', '7')
    AND s.inmes BETWEEN 1 AND 12)

)
AND s.coexercicio >= EXTRACT(YEAR FROM SYSDATE) - 1
