-- DESPESA.sql — Despesa Orçamentária (Balanço Orçamentário)
-- Placeholder {SCHEMA_ANO} será substituído pelo Python com o ano corrente (ex: mil2026)
-- O schema mil2001 é fixo (saldocontabil_ex)
-- Não colocar ponto-e-vírgula no final
-- Classe 5 (dotação autorizada): 522110000-522199999 — cobre dotação inicial + todos os créditos adicionais
-- Classe 6 (execução): 622130000-622139999 (empenhada/liquidada), 622920104 (paga)

SELECT
    v.coexercicio,
    v.inmes,
    v.coug,
    MIN(v.noug)                                    AS noug,
    v.cocontacontabil,
    SUM(v.vadebito)                                AS vadebito,
    SUM(v.vacredito)                               AS vacredito,
    SUM(CASE
        WHEN v.cocontacontabil LIKE '5%' THEN (v.vadebito - v.vacredito)
        WHEN v.cocontacontabil LIKE '6%' THEN (v.vacredito - v.vadebito)
        ELSE 0
    END)                                           AS saldo,

    -- Natureza da despesa
    v.conatureza || '00'                           AS despesa,
    MIN(c_desp.NOME)                               AS nome_despesa,

    SUBSTR(v.conatureza, 1, 1) || '0000000'        AS categoria_economica,
    MIN(c_cat_desp.NOME)                           AS nome_categoria_economica,

    SUBSTR(v.conatureza, 1, 2) || '000000'         AS gnd,
    MIN(c_gnd.NOME)                                AS nome_gnd,

    SUBSTR(v.conatureza, 3, 2)                     AS intra,

    -- Fonte de recurso
    TO_CHAR(v.cofonte)                             AS cofonte,
    SUBSTR(TO_CHAR(v.cofonte), 1, 4)               AS fonte_agrupada,
    MIN(fr.COFONTEFEDERAL)                         AS cofontefederal,
    MIN(fr_nome.NOFONTE)                           AS nome_fonte,

    -- Subelemento
    SUBSTR(v.cocontacorrente, 33, 8)               AS subelemento,
    MIN(c_sub.NOME)                                AS nome_subelemento,

    -- Função e subfunção
    v.cofuncao,
    MIN(f.NOFUNCAO)                                AS nofuncao,
    v.cosubfuncao,
    MIN(sf.NOSUBFUNCAO)                            AS nosubfuncao

FROM mil2001.saldocontabil_ex v

LEFT JOIN (SELECT TO_CHAR(COCLASSEORC) AS COD, MIN(NOCLASSIFICACAO) AS NOME
             FROM {SCHEMA_ANO}.classificacaoorcamentaria GROUP BY TO_CHAR(COCLASSEORC)) c_desp
       ON c_desp.COD = v.conatureza || '00'

LEFT JOIN (SELECT TO_CHAR(COCLASSEORC) AS COD, MIN(NOCLASSIFICACAO) AS NOME
             FROM {SCHEMA_ANO}.classificacaoorcamentaria GROUP BY TO_CHAR(COCLASSEORC)) c_cat_desp
       ON c_cat_desp.COD = SUBSTR(v.conatureza, 1, 1) || '0000000'

LEFT JOIN (SELECT TO_CHAR(COCLASSEORC) AS COD, MIN(NOCLASSIFICACAO) AS NOME
             FROM {SCHEMA_ANO}.classificacaoorcamentaria GROUP BY TO_CHAR(COCLASSEORC)) c_gnd
       ON c_gnd.COD = SUBSTR(v.conatureza, 1, 2) || '000000'

LEFT JOIN (SELECT TO_CHAR(COCLASSEORC) AS COD, MIN(NOCLASSIFICACAO) AS NOME
             FROM {SCHEMA_ANO}.classificacaoorcamentaria GROUP BY TO_CHAR(COCLASSEORC)) c_sub
       ON c_sub.COD = SUBSTR(v.cocontacorrente, 33, 8)

LEFT JOIN {SCHEMA_ANO}.fonterecurso fr
       ON TO_CHAR(v.cofonte) = TO_CHAR(fr.COFONTE)

LEFT JOIN {SCHEMA_ANO}.fonterecurso fr_nome
       ON SUBSTR(TO_CHAR(v.cofonte), 1, 4) || '00000' = TO_CHAR(fr_nome.COFONTE)

LEFT JOIN {SCHEMA_ANO}.funcao f
       ON TO_CHAR(v.cofuncao) = TO_CHAR(f.COFUNCAO)

LEFT JOIN {SCHEMA_ANO}.subfuncao sf
       ON TO_CHAR(v.cosubfuncao) = TO_CHAR(sf.COSUBFUNCAO)

WHERE (
    -- Empenhada / Liquidada / Paga (classe 6)
    v.cocontacontabil BETWEEN '622130000' AND '622139999'
    OR v.cocontacontabil = '622920104'
    -- Dotação Autorizada + Créditos Adicionais (classe 5, todos os subtipos)
    OR v.cocontacontabil BETWEEN '522110000' AND '522199999'
)
AND v.coexercicio IN (
    TO_CHAR(EXTRACT(YEAR FROM SYSDATE)),
    TO_CHAR(EXTRACT(YEAR FROM SYSDATE) - 1)
)

GROUP BY
    v.coexercicio,
    v.inmes,
    v.coug,
    v.cocontacontabil,
    v.conatureza,
    SUBSTR(v.conatureza, 1, 1),
    SUBSTR(v.conatureza, 1, 2),
    SUBSTR(v.conatureza, 3, 2),
    TO_CHAR(v.cofonte),
    SUBSTR(TO_CHAR(v.cofonte), 1, 4),
    SUBSTR(v.cocontacorrente, 33, 8),
    v.cofuncao,
    v.cosubfuncao
