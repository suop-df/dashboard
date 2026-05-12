-- RECEITA.sql — Receita Orçamentária (Balanço Orçamentário)
-- Placeholder {SCHEMA_ANO} será substituído pelo Python com o ano corrente (ex: mil2026)
-- O schema mil2001 é fixo (saldocontabil_ex)
-- Não colocar ponto-e-vírgula no final
--
-- IMPORTANTE: JOINs com classificacaoorcamentaria usam subquery com
-- GROUP BY para garantir 1 linha por código, evitando duplicação.

SELECT
    v.coexercicio,
    v.inmes,
    v.coug,
    v.noug,
    v.cocontacontabil,
    v.cocontacorrente,
    v.vadebito,
    v.vacredito,
    CASE
        WHEN v.cocontacontabil LIKE '5%' THEN (v.vadebito - v.vacredito)
        WHEN v.cocontacontabil LIKE '6%' THEN (v.vacredito - v.vadebito)
        ELSE 0
    END AS SALDO,
    SUBSTR(v.cocontacorrente, 9, 9) AS FONTE,
    SUBSTR(v.cocontacorrente, 9, 4) AS FONTE_AGRUPADA,
    fr.COFONTEFEDERAL,
    fr_nome.NOFONTE AS NOME_FONTE,

    SUBSTR(v.cocontacorrente, 1, 8) AS RECEITA,
    c_rec.NOME AS NOME_RECEITA,

    SUBSTR(v.cocontacorrente, 1, 1) || '0000000' AS CATEGORIA_ECONOMICA,
    c_cat.NOME AS NOME_CATEGORIA_ECONOMICA,

    SUBSTR(v.cocontacorrente, 1, 2) || '000000' AS ORIGEM_RECEITA,
    c_ori.NOME AS NOME_ORIGEM_RECEITA,

    SUBSTR(v.cocontacorrente, 1, 3) || '00000' AS ESPECIE_RECEITA,
    c_esp.NOME AS NOME_ESPECIE_RECEITA,

    SUBSTR(v.cocontacorrente, 1, 6) || '00' AS TIPO_RECEITA,
    c_tip.NOME AS NOME_TIPO_RECEITA,

    SUBSTR(v.cocontacorrente, 1, 7) || '0' AS DETALHE_RECEITA,
    c_det.NOME AS NOME_DETALHE_RECEITA

FROM mil2001.saldocontabil_ex v

-- Subqueries com GROUP BY garantem 1 linha por código
LEFT JOIN (SELECT TO_CHAR(COCLASSEORC) AS COD, MIN(NOCLASSIFICACAO) AS NOME
             FROM {SCHEMA_ANO}.classificacaoorcamentaria GROUP BY TO_CHAR(COCLASSEORC)) c_rec
       ON c_rec.COD = SUBSTR(v.cocontacorrente, 1, 8)

LEFT JOIN (SELECT TO_CHAR(COCLASSEORC) AS COD, MIN(NOCLASSIFICACAO) AS NOME
             FROM {SCHEMA_ANO}.classificacaoorcamentaria GROUP BY TO_CHAR(COCLASSEORC)) c_cat
       ON c_cat.COD = SUBSTR(v.cocontacorrente, 1, 1) || '0000000'

LEFT JOIN (SELECT TO_CHAR(COCLASSEORC) AS COD, MIN(NOCLASSIFICACAO) AS NOME
             FROM {SCHEMA_ANO}.classificacaoorcamentaria GROUP BY TO_CHAR(COCLASSEORC)) c_ori
       ON c_ori.COD = SUBSTR(v.cocontacorrente, 1, 2) || '000000'

LEFT JOIN (SELECT TO_CHAR(COCLASSEORC) AS COD, MIN(NOCLASSIFICACAO) AS NOME
             FROM {SCHEMA_ANO}.classificacaoorcamentaria GROUP BY TO_CHAR(COCLASSEORC)) c_esp
       ON c_esp.COD = SUBSTR(v.cocontacorrente, 1, 3) || '00000'

LEFT JOIN (SELECT TO_CHAR(COCLASSEORC) AS COD, MIN(NOCLASSIFICACAO) AS NOME
             FROM {SCHEMA_ANO}.classificacaoorcamentaria GROUP BY TO_CHAR(COCLASSEORC)) c_tip
       ON c_tip.COD = SUBSTR(v.cocontacorrente, 1, 6) || '00'

LEFT JOIN (SELECT TO_CHAR(COCLASSEORC) AS COD, MIN(NOCLASSIFICACAO) AS NOME
             FROM {SCHEMA_ANO}.classificacaoorcamentaria GROUP BY TO_CHAR(COCLASSEORC)) c_det
       ON c_det.COD = SUBSTR(v.cocontacorrente, 1, 7) || '0'

-- Fonte: JOIN direto (cofonte é chave única)
LEFT JOIN {SCHEMA_ANO}.fonterecurso fr
       ON TO_CHAR(fr.COFONTE) = SUBSTR(v.cocontacorrente, 9, 9)

-- Fonte agrupada (4 dígitos + '00000')
LEFT JOIN {SCHEMA_ANO}.fonterecurso fr_nome
       ON TO_CHAR(fr_nome.COFONTE) = SUBSTR(v.cocontacorrente, 9, 4) || '00000'

WHERE (
        (v.cocontacontabil BETWEEN '521100000' AND '521299999')
     OR (v.cocontacontabil BETWEEN '621200000' AND '621399999')
      )
  AND v.coexercicio IN (
      TO_CHAR(EXTRACT(YEAR FROM SYSDATE)),
      TO_CHAR(EXTRACT(YEAR FROM SYSDATE) - 1)
  )
