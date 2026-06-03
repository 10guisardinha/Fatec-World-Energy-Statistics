-- =============================================================================
-- 03_etl_load.sql
-- Projeto: Data Warehouse - Energia e Sustentabilidade (Opção 5)
-- Camada: ETL — Carga (OLTP -> DW)
-- Objetivo: Popular dim_date, dim_country (SCD2), dim_source e fact_energy.
-- Idempotente: DELETE + INSERT garante reexecução sem duplicação.
-- =============================================================================

-- =============================================================================
-- PASSO 1: Carga da dim_date
-- Gera um registro por mês para o período 2000–2023 (288 meses)
-- =============================================================================
DELETE FROM dim_date;

INSERT INTO dim_date
SELECT
    CAST(year * 100 + month AS INTEGER)    AS date_key,
    year,
    month,
    CAST(CEIL(month / 3.0) AS INTEGER)     AS quarter,
    PRINTF('%04d-%02d', year, month)       AS year_month,
    CASE month
        WHEN  1 THEN 'January'   WHEN  2 THEN 'February' WHEN  3 THEN 'March'
        WHEN  4 THEN 'April'     WHEN  5 THEN 'May'       WHEN  6 THEN 'June'
        WHEN  7 THEN 'July'      WHEN  8 THEN 'August'    WHEN  9 THEN 'September'
        WHEN 10 THEN 'October'   WHEN 11 THEN 'November'  WHEN 12 THEN 'December'
    END                                    AS month_name,
    CASE WHEN month <= 6 THEN 1 ELSE 2 END AS semester,
    year >= 2010                           AS is_renewable_decade
FROM (
    SELECT UNNEST(RANGE(2000, 2024)) AS year
) y
CROSS JOIN (
    SELECT UNNEST(RANGE(1, 13)) AS month
) m
ORDER BY year, month;

-- Validação: deve retornar 288 registros (24 anos × 12 meses)
SELECT COUNT(*) AS total_meses_dim_date FROM dim_date;

-- =============================================================================
-- PASSO 2: Carga da dim_country com SCD Type 2
-- Atributo que muda: development_status e income_group
-- Regra: países com PIB per capita acima de determinados limiares por período
-- Versão 1 (2000–2011): classificação inicial
-- Versão 2 (2012–2023): reclassificação de países emergentes que cresceram
-- =============================================================================
DELETE FROM dim_country;

CREATE OR REPLACE SEQUENCE seq_country_key START 1;

-- Versão 1: 2000–2011 (classificação histórica)
INSERT INTO dim_country
SELECT
    NEXTVAL('seq_country_key'),
    c.country_id,
    c.country_name,
    c.region,
    CASE
        WHEN avg_gdp_pc >= 25000 THEN 'Developed'
        WHEN avg_gdp_pc >= 10000 THEN 'Emerging'
        ELSE 'Developing'
    END                     AS development_status,
    CASE
        WHEN avg_gdp_pc >= 25000 THEN 'High'
        WHEN avg_gdp_pc >= 10000 THEN 'Upper-Middle'
        WHEN avg_gdp_pc >=  4000 THEN 'Lower-Middle'
        ELSE 'Low'
    END                     AS income_group,
    DATE '2000-01-01'       AS scd_start_date,
    DATE '2011-12-31'       AS scd_end_date,
    FALSE                   AS is_current
FROM oltp_country c
JOIN (
    -- PIB per capita médio do período inicial (2000–2011)
    SELECT country_id,
           AVG(CASE WHEN population > 0 THEN gdp / population ELSE 0 END) AS avg_gdp_pc
    FROM oltp_energy_annual
    WHERE year BETWEEN 2000 AND 2011
    GROUP BY country_id
) g ON c.country_id = g.country_id;

-- Versão 2: 2012–2023 (classificação atual — registro is_current = TRUE)
INSERT INTO dim_country
SELECT
    NEXTVAL('seq_country_key'),
    c.country_id,
    c.country_name,
    c.region,
    CASE
        WHEN avg_gdp_pc >= 25000 THEN 'Developed'
        WHEN avg_gdp_pc >= 10000 THEN 'Emerging'
        ELSE 'Developing'
    END                     AS development_status,
    CASE
        WHEN avg_gdp_pc >= 25000 THEN 'High'
        WHEN avg_gdp_pc >= 10000 THEN 'Upper-Middle'
        WHEN avg_gdp_pc >=  4000 THEN 'Lower-Middle'
        ELSE 'Low'
    END                     AS income_group,
    DATE '2012-01-01'       AS scd_start_date,
    NULL                    AS scd_end_date,     -- registro atual
    TRUE                    AS is_current
FROM oltp_country c
JOIN (
    -- PIB per capita médio do período recente (2012–2023)
    SELECT country_id,
           AVG(CASE WHEN population > 0 THEN gdp / population ELSE 0 END) AS avg_gdp_pc
    FROM oltp_energy_annual
    WHERE year BETWEEN 2012 AND 2023
    GROUP BY country_id
) g ON c.country_id = g.country_id;

SELECT COUNT(*) AS total_dim_country,
       SUM(CASE WHEN is_current THEN 1 ELSE 0 END) AS versoes_atuais,
       SUM(CASE WHEN NOT is_current THEN 1 ELSE 0 END) AS versoes_historicas
FROM dim_country;

-- =============================================================================
-- PASSO 3: Carga da dim_source
-- =============================================================================
DELETE FROM dim_source;

INSERT INTO dim_source VALUES
    (1, 'TOTAL',    'Total Energy',           'Mixed',     FALSE, FALSE),
    (2, 'RENEW',    'Renewables (Total)',      'Renewable', TRUE,  TRUE),
    (3, 'FOSSIL',   'Fossil Fuels (Total)',    'Fossil',    FALSE, FALSE),
    (4, 'SOLAR',    'Solar Energy',            'Renewable', TRUE,  TRUE),
    (5, 'WIND',     'Wind Energy',             'Renewable', TRUE,  TRUE),
    (6, 'HYDRO',    'Hydroelectric',           'Renewable', TRUE,  TRUE),
    (7, 'COAL',     'Coal',                    'Fossil',    FALSE, FALSE),
    (8, 'OIL',      'Oil & Petroleum',         'Fossil',    FALSE, FALSE),
    (9, 'GAS',      'Natural Gas',             'Fossil',    FALSE, FALSE);

SELECT COUNT(*) AS total_fontes FROM dim_source;

-- =============================================================================
-- PASSO 4: Carga da fact_energy
-- Grain: país × mês (decompõe dados anuais em 12 meses)
-- Resultado esperado: ~50 países × 24 anos × 12 meses = 14.400 registros
-- =============================================================================
DELETE FROM fact_energy;

CREATE OR REPLACE SEQUENCE seq_fact_key START 1;

INSERT INTO fact_energy
SELECT
    NEXTVAL('seq_fact_key')                                  AS fact_key,
    d.date_key,
    dc.country_key,
    -- Divisão por 12 converte valor anual em mensal
    ROUND(e.total_energy_twh / 12, 6)                        AS total_energy_twh,
    e.energy_per_capita_kwh,                                 
    e.renewables_pct,
    e.fossil_pct,
    e.solar_pct,
    e.wind_pct,
    e.hydro_pct,
    e.coal_pct,
    e.oil_pct,
    e.gas_pct,
    ROUND(e.renewable_energy_twh / 12, 6)                    AS renewable_energy_twh,
    ROUND(e.fossil_energy_twh / 12, 6)                       AS fossil_energy_twh,
    ROUND(e.solar_energy_twh / 12, 6)                        AS solar_energy_twh,
    ROUND(e.co2_mt / 12, 6)                                  AS co2_mt,
    d.year,
    d.month
FROM oltp_energy_annual e
-- Junta com todos os meses do respectivo ano
JOIN dim_date d
    ON d.year = e.year
-- Usa o registro atual do país (is_current = TRUE)
JOIN dim_country dc
    ON dc.country_id = e.country_id
    AND dc.is_current = TRUE
ORDER BY dc.country_key, d.date_key;

-- =============================================================================
-- VALIDAÇÕES FINAIS
-- =============================================================================
SELECT 'dim_date'    AS tabela, COUNT(*) AS registros FROM dim_date
UNION ALL
SELECT 'dim_country' AS tabela, COUNT(*) AS registros FROM dim_country
UNION ALL
SELECT 'dim_source'  AS tabela, COUNT(*) AS registros FROM dim_source
UNION ALL
SELECT 'fact_energy' AS tabela, COUNT(*) AS registros FROM fact_energy;

-- Verificação de integridade: sem chaves estrangeiras nulas na fato
SELECT
    COUNT(*) AS fatos_sem_date_key
FROM fact_energy f
LEFT JOIN dim_date d ON f.date_key = d.date_key
WHERE d.date_key IS NULL;

SELECT
    COUNT(*) AS fatos_sem_country_key
FROM fact_energy f
LEFT JOIN dim_country dc ON f.country_key = dc.country_key
WHERE dc.country_key IS NULL;


SELECT
    v1.country_name,
    v1.development_status AS status_2000_2011,
    v2.development_status AS status_2012_2023,
    v1.income_group       AS grupo_2000_2011,
    v2.income_group       AS grupo_2012_2023
FROM dim_country v1
JOIN dim_country v2
    ON v1.country_id = v2.country_id
    AND v1.is_current = FALSE
    AND v2.is_current = TRUE
WHERE v1.development_status <> v2.development_status
   OR v1.income_group       <> v2.income_group
ORDER BY v1.country_name;