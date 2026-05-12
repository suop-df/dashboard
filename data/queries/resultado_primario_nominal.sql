SELECT SC.*, FR.COFONTEFEDERAL, SUBSTR(SC.COCONTACORRENTE, 1, 8) AS COCLASSEORC
FROM MIL2026.SALDOCONTABIL SC
LEFT JOIN MIL2026.FONTERECURSO FR ON SC.COFONTE=FR.COFONTE
WHERE (
    SUBSTR(SC.COCONTACONTABIL,1,4) IN (
        5211,5212,6212,6213,   -- RECEITAS PRIMARIAS
        5221,6221,             -- DESPESAS: dotacao (52211/52212/52215/52219) + empenho/liquidado (6221x)
        6322,                  -- DESPESAS: RP processados pagos
        6313,6314,             -- DESPESAS: RP nao processados (parcial)
        6318,                  -- DESPESAS: RP nao processados (631810000, 631820000)
        -- JUROS NOMINAIS (XXXVI - Juros Ativos 44xxx)
        4411,4412,4413,4414,4421,4422,4426,
        4431,4432,4433,4434,4435,4439,
        4451,4452,4461,4462,
        -- JUROS NOMINAIS (XXXVII - Juros Passivos 34xxx)
        3411,3412,3413,3414,3418,3419,
        3421,3422,3425,3426,
        3431,3432,3433,3434,3435,3439,
        3451,3452,3461,3491
    )
    OR SC.COCONTACONTABIL IN (
        -- -----------------------------------------------------------
        -- ABAIXO DA LINHA — DÍVIDA CONSOLIDADA (XXXIX)
        -- -----------------------------------------------------------
        -- Empréstimos Internos
        212117201, 222110200, 212115201,
        -- Empréstimos Externos
        212217201, 222210200, 222910100, 212215201,
        -- Reestruturação da Dívida de Estados e Municípios
        222130401, 212137401, 212135401,
        -- Financiamentos Internos
        222310102,
        -- Parcelamento — Tributos
        214136201, 224130201,
        -- Parcelamento — Contribuições Previdenciárias
        224130205, 211435102,
        -- Parcelamento — Demais Contribuições Sociais
        214138202, 224130202,
        -- Precatórios Posteriores a 05/05/2000
        221210202, 113510802,
        -- Outras Dívidas
        218910105, 218910108,
        -- -----------------------------------------------------------
        -- ABAIXO DA LINHA — DEDUÇÕES (XL)
        -- -----------------------------------------------------------
        -- Disponibilidade de Caixa Bruta
        111110100, 111110200, 111110600, 111111900, 111113000,
        111115000, 111115100, 111115200, 111115300,
        111210100, 111210200, 111210300, 111310000,
        -- (-) Restos a Pagar Processados (XLI)
        622130700, 631300000, 632100000,
        -- (-) Depósitos Restituíveis e Valores Vinculados
        218810000, 218830000, 218840000, 218850000,
        228810000, 228830000, 228840000, 228850000,
        -- Demais Haveres Financeiros
        112410201, 112410302, 112410303, 112410304, 112910301,
        121110301, 121110302, 121110321, 121110322, 121310102
    )
)
AND SC.INMES BETWEEN 1 AND 12