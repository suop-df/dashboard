-- receita_RCL.sql — Receita Corrente Líquida (RREO Anexo 3)
-- Placeholder {SCHEMA_ANO} substituído pelo Python (ex: mil2026)
-- Schema mil2001 é fixo (saldocontabil_ex — view histórica)
-- Não colocar ponto-e-vírgula no final
--
-- Ranges cocontacontabil:
--   521100000–521299999 : Previsão de Receitas Correntes (classe 5)
--   621200000–621399999 : Realizados de Receitas Correntes (classe 6)
--                         EXCETO a conta 621310100 (não entra na apuração)
--
-- class_orc = SUBSTR(cocontacorrente, 1, 8) — usado pelo Python para
--             classificar cada linha nas categorias do demonstrativo.
-- cofonte e cofontefederal — usados para apurar emendas individuais (V),
--             emendas de bancada (VII) e agentes comunitários (VIII).
-- max_mes_fechado — max(inmes) de {SCHEMA_ANO}.mesfechado (inmes 1-12).
--   Define o último mês da janela de 12 colunas do demonstrativo.
--   NULL quando não há meses fechados no exercício corrente (fallback no Python).

SELECT
  s.coexercicio,
  s.cocontacorrente,
  s.cocontacontabil,
  SUBSTR(s.cocontacorrente, 1, 8)  AS class_orc,
  s.inmes,
  s.cofonte,
  f.cofontefederal,
  (SELECT MAX(m.inmes)
     FROM {SCHEMA_ANO}.mesfechado m
    WHERE m.inmes BETWEEN 1 AND 12) AS max_mes_fechado,
  CASE
    WHEN s.cocontacontabil BETWEEN 521100000 AND 521299999
         THEN (s.vadebito - s.vacredito)
    WHEN s.cocontacontabil BETWEEN 621200000 AND 621399999
         THEN (s.vacredito - s.vadebito)
    ELSE 0
  END AS saldo
FROM mil2001.saldocontabil_ex s
LEFT JOIN {SCHEMA_ANO}.fonterecurso f
       ON f.cofonte = s.cofonte
WHERE (
        s.cocontacontabil BETWEEN 521100000 AND 521299999
     OR (
          s.cocontacontabil BETWEEN 621200000 AND 621399999
          AND s.cocontacontabil <> 621310100
        )
     )
  AND s.inmes NOT IN (0, 13, 14)
  AND s.coexercicio >= EXTRACT(YEAR FROM SYSDATE) - 1
