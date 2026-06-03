-- =============================================================================
-- 04_analytics.sql
-- Projeto: Data Warehouse - Energia e Sustentabilidade (Opção 5)
-- Camada: ANALYTICS — Consultas de Negócio
-- Objetivo: 5 queries respondendo às perguntas analíticas do domínio.
-- =============================================================================

-- =============================================================================
-- QUERY 1: Análise Temporal
-- Pergunta: Como evoluiu a participação de energia solar no Brasil ao longo dos anos?
-- Tipo: Linha do tempo (tendência anual)
-- =============================================================================
-- Esta query mostra a trajetória de crescimento da energia solar brasileira,
-- evidenciando a aceleração pós-2012 com políticas de incentivo renovável.
SELECT
    d.year,
    ROUND(AVG(f.solar_pct), 2)              AS solar_pct,
    ROUND(AVG(f.renewables_pct), 2)         AS renewables_pct,
    ROUND(AVG(f.fossil_pct), 2)             AS fossil_pct,
    ROUND(SUM(f.solar_energy_twh), 4)       AS solar_twh_anual
FROM fact_energy f
JOIN dim_date    d  ON f.date_key    = d.date_key
JOIN dim_country dc ON f.country_key = dc.country_key
WHERE dc.country_id = 'BRA'
  AND dc.is_current = TRUE
GROUP BY d.year
ORDER BY d.year;

-- =============================================================================
-- QUERY 2: Ranking / TOP N
-- Pergunta: Quais são os 10 países com maior participação de energia renovável (2023)?
-- Tipo: Ranking dos mais limpos
-- =============================================================================
-- Identifica líderes mundiais em transição energética no ano mais recente,
-- permitindo benchmarking entre países.
SELECT
    RANK() OVER (ORDER BY AVG(f.renewables_pct) DESC) AS ranking,
    dc.country_name,
    dc.region,
    dc.development_status,
    ROUND(AVG(f.renewables_pct), 2)  AS renewables_pct_media,
    ROUND(AVG(f.solar_pct), 2)       AS solar_pct,
    ROUND(AVG(f.wind_pct), 2)        AS wind_pct,
    ROUND(AVG(f.hydro_pct), 2)       AS hydro_pct
FROM fact_energy f
JOIN dim_date    d  ON f.date_key    = d.date_key
JOIN dim_country dc ON f.country_key = dc.country_key
WHERE d.year = 2023
  AND dc.is_current = TRUE
GROUP BY dc.country_name, dc.region, dc.development_status
ORDER BY renewables_pct_media DESC
LIMIT 10;

-- =============================================================================
-- QUERY 3: Agregação Multidimensional
-- Pergunta: Como varia o consumo per capita por região e nível de desenvolvimento?
-- Tipo: Cruzamento de dimensões (região × desenvolvimento)
-- =============================================================================
-- Revela disparidades globais de consumo energético, cruzando a dimensão
-- geográfica com o nível de desenvolvimento econômico.
SELECT
    dc.region,
    dc.development_status,
    COUNT(DISTINCT dc.country_name)             AS qtd_paises,
    ROUND(AVG(f.energy_per_capita_kwh), 0)      AS consumo_pc_kwh_medio,
    ROUND(MIN(f.energy_per_capita_kwh), 0)      AS consumo_pc_minimo,
    ROUND(MAX(f.energy_per_capita_kwh), 0)      AS consumo_pc_maximo,
    ROUND(AVG(f.renewables_pct), 1)             AS renovavel_pct_medio,
    ROUND(AVG(f.co2_mt * 12), 2)                AS co2_anual_medio_mt
FROM fact_energy f
JOIN dim_date    d  ON f.date_key    = d.date_key
JOIN dim_country dc ON f.country_key = dc.country_key
WHERE d.year = 2023
  AND dc.is_current = TRUE
GROUP BY dc.region, dc.development_status
ORDER BY dc.region, consumo_pc_kwh_medio DESC;

-- =============================================================================
-- QUERY 4: Análise de Cohort / Evolução por Grupo
-- Pergunta: Como evoluiu a matriz energética (limpa vs fóssil) por década?
-- Tipo: Cohort temporal — comparação entre décadas
-- =============================================================================
-- Agrupa países por cohort de início de transição energética e compara
-- a evolução média da participação renovável por faixa de renda.
SELECT
    dc.income_group,
    CASE
        WHEN d.year BETWEEN 2000 AND 2009 THEN 'Decade 2000s'
        WHEN d.year BETWEEN 2010 AND 2019 THEN 'Decade 2010s'
        ELSE 'Decade 2020s'
    END                                             AS decada,
    COUNT(DISTINCT dc.country_name)                 AS qtd_paises,
    ROUND(AVG(f.renewables_pct), 2)                 AS renovavel_pct_medio,
    ROUND(AVG(f.fossil_pct), 2)                     AS fossil_pct_medio,
    ROUND(AVG(f.solar_pct), 2)                      AS solar_pct_medio,
    ROUND(AVG(f.co2_mt * 12), 2)                    AS co2_anual_medio_mt
FROM fact_energy f
JOIN dim_date    d  ON f.date_key    = d.date_key
JOIN dim_country dc ON f.country_key = dc.country_key
WHERE dc.is_current = TRUE
GROUP BY dc.income_group, decada
ORDER BY decada, dc.income_group;

-- =============================================================================
-- QUERY 5: KPI — Indicador Estratégico
-- Pergunta: Qual o índice de limpeza energética por país? (Ranking KPI global)
-- Tipo: KPI composto — métrica estratégica de sustentabilidade
-- =============================================================================
-- O "Clean Energy Score" combina percentual renovável e inverso das emissões
-- per capita para produzir um KPI de sustentabilidade comparável entre países.
-- Útil para policy makers priorizarem cooperação técnica internacional.
WITH kpi_base AS (
    SELECT
        dc.country_name,
        dc.region,
        dc.development_status,
        ROUND(AVG(f.renewables_pct), 2)              AS renovavel_pct,
        ROUND(AVG(f.fossil_pct), 2)                  AS fossil_pct,
        ROUND(AVG(f.energy_per_capita_kwh), 0)       AS consumo_pc_kwh,
        ROUND(AVG(f.co2_mt * 12), 4)                 AS co2_anual_mt,
        CASE
            WHEN AVG(f.energy_per_capita_kwh) > 0
            THEN ROUND(AVG(f.co2_mt * 12 * 1e6) / AVG(f.energy_per_capita_kwh), 4)
            ELSE NULL
        END                                          AS co2_intensity
    FROM fact_energy f
    JOIN dim_date    d  ON f.date_key    = d.date_key
    JOIN dim_country dc ON f.country_key = dc.country_key
    WHERE d.year >= 2020 
      AND dc.is_current = TRUE
    GROUP BY dc.country_name, dc.region, dc.development_status
)
SELECT
    RANK() OVER (ORDER BY renovavel_pct DESC, co2_intensity ASC) AS kpi_rank,
    country_name,
    region,
    development_status,
    renovavel_pct,
    fossil_pct,
    consumo_pc_kwh,
    ROUND(co2_intensity, 4)                                        AS co2_intensity,
    ROUND(
        0.60 * renovavel_pct
        + 0.40 * (100 - LEAST(co2_intensity * 100, 100))
    , 1)                                                           AS clean_energy_score
FROM kpi_base
ORDER BY clean_energy_score DESC;
