-- =============================================================================
-- 05_performance.sql
-- Projeto: Data Warehouse - Energia e Sustentabilidade (Opção 5)
-- Camada: PERFORMANCE — Otimização e Materialização
-- Objetivo: Criar 1 tabela agregada materializada, índices e comparar
--           tempo de execução de query original vs otimizada.
-- =============================================================================

-- =============================================================================
-- PARTE 1: Índices na tabela
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_fact_date_key    ON fact_energy(date_key);
CREATE INDEX IF NOT EXISTS idx_fact_country_key ON fact_energy(country_key);
CREATE INDEX IF NOT EXISTS idx_fact_year        ON fact_energy(year);
CREATE INDEX IF NOT EXISTS idx_dim_country_curr ON dim_country(is_current, country_id);

-- =============================================================================
-- PARTE 2: Tabela Agregada Materializada — agg_country_year
-- Grain: país × ano (colapsa 12 meses em 1 registro anual)
-- Objetivo: Acelerar queries analíticas que operam em nível anual
-- =============================================================================
DROP TABLE IF EXISTS agg_country_year;

CREATE TABLE agg_country_year AS
SELECT
    dc.country_key,
    dc.country_name,
    dc.region,
    dc.development_status,
    dc.income_group,
    f.year,
    -- Médias anuais das participações (%)
    ROUND(AVG(f.renewables_pct), 4)         AS renewables_pct,
    ROUND(AVG(f.fossil_pct), 4)             AS fossil_pct,
    ROUND(AVG(f.solar_pct), 4)              AS solar_pct,
    ROUND(AVG(f.wind_pct), 4)              AS wind_pct,
    ROUND(AVG(f.hydro_pct), 4)              AS hydro_pct,
    ROUND(AVG(f.coal_pct), 4)               AS coal_pct,
    ROUND(AVG(f.oil_pct), 4)                AS oil_pct,
    ROUND(AVG(f.gas_pct), 4)                AS gas_pct,
    ROUND(AVG(f.energy_per_capita_kwh), 2)  AS energy_per_capita_kwh,
    -- Somas anuais (multiplica mensal × 12)
    ROUND(SUM(f.total_energy_twh), 4)       AS total_energy_twh,
    ROUND(SUM(f.renewable_energy_twh), 4)   AS renewable_energy_twh,
    ROUND(SUM(f.fossil_energy_twh), 4)      AS fossil_energy_twh,
    ROUND(SUM(f.solar_energy_twh), 4)       AS solar_energy_twh,
    ROUND(SUM(f.co2_mt), 6)                 AS co2_mt_anual,
    COUNT(*)                                AS meses_registrados
FROM fact_energy f
JOIN dim_country dc ON f.country_key = dc.country_key AND dc.is_current = TRUE
GROUP BY
    dc.country_key, dc.country_name, dc.region,
    dc.development_status, dc.income_group, f.year
ORDER BY dc.country_name, f.year;

CREATE INDEX IF NOT EXISTS idx_agg_year    ON agg_country_year(year);
CREATE INDEX IF NOT EXISTS idx_agg_country ON agg_country_year(country_name);
CREATE INDEX IF NOT EXISTS idx_agg_region  ON agg_country_year(region);

SELECT COUNT(*) AS registros_agg, COUNT(DISTINCT country_name) AS paises,
       COUNT(DISTINCT year) AS anos
FROM agg_country_year;

-- =============================================================================
-- PARTE 3: Comparação de Performance
-- =============================================================================

-- --- QUERY ORIGINAL (sem otimização — usa fact_energy com JOINs mensais) ---
-- Esta query faz JOIN de 14.400 registros para obter média anual por região
EXPLAIN ANALYZE
SELECT
    dc.region,
    f.year,
    ROUND(AVG(f.renewables_pct), 2) AS renovavel_pct_medio,
    ROUND(AVG(f.fossil_pct), 2)     AS fossil_pct_medio,
    ROUND(SUM(f.total_energy_twh), 2) AS energia_total_twh
FROM fact_energy f
JOIN dim_country dc ON f.country_key = dc.country_key AND dc.is_current = TRUE
GROUP BY dc.region, f.year
ORDER BY dc.region, f.year;

-- --- QUERY OTIMIZADA (usa tabela agregada — 1.200 registros) ---
-- Mesma resposta, mas opera sobre agg_country_year que já tem os dados sumarizados
EXPLAIN ANALYZE
SELECT
    region,
    year,
    ROUND(AVG(renewables_pct), 2)       AS renovavel_pct_medio,
    ROUND(AVG(fossil_pct), 2)           AS fossil_pct_medio,
    ROUND(SUM(total_energy_twh), 2)     AS energia_total_twh
FROM agg_country_year
GROUP BY region, year
ORDER BY region, year;

-- =============================================================================
-- PARTE 4: Documentação do ganho de performance
-- =============================================================================
-- A tabela agg_country_year reduz o volume de dados lidos de ~14.400 registros
-- (fact_energy) para ~1.200 registros (50 países × 24 anos).
-- Fator de redução esperado: 12× (equivalente à eliminação da dimensão mensal).
-- Em DuckDB, o ganho real também inclui a eliminação do JOIN com dim_country,
-- pois a agg já contém os atributos dimensionais inline (country_name, region, etc.).
SELECT
    'fact_energy (original)'   AS fonte,
    COUNT(*)                   AS registros,
    '14.400 (50 × 24 × 12)'   AS descricao
FROM fact_energy
UNION ALL
SELECT
    'agg_country_year (otimizado)' AS fonte,
    COUNT(*)                       AS registros,
    '1.200 (50 × 24)'             AS descricao
FROM agg_country_year;
