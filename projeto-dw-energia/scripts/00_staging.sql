-- =============================================================================
-- 00_staging.sql
-- Projeto: Data Warehouse - Energia e Sustentabilidade (Opção 5)
-- Camada: STAGING
-- Objetivo: Criar views temporárias sobre o CSV bruto sem nenhuma transformação.
--           Representa o ponto de entrada do pipeline ETL.
-- Idempotente: pode ser executado múltiplas vezes sem efeito colateral.
-- =============================================================================

-- Remove views caso já existam (idempotência)
DROP VIEW IF EXISTS stg_energy;

-- View principal: lê o CSV diretamente via DuckDB
-- Nenhuma transformação é aplicada aqui — apenas exposição dos dados brutos
CREATE VIEW stg_energy AS
SELECT
    country,
    iso_code,
    region,
    CAST(year AS INTEGER)                      AS year,
    CAST(population AS BIGINT)                 AS population,
    CAST(gdp AS DOUBLE)                        AS gdp,
    CAST(energy_per_capita AS DOUBLE)          AS energy_per_capita,
    CAST(primary_energy_consumption AS DOUBLE) AS primary_energy_consumption,
    CAST(renewables_share_energy AS DOUBLE)    AS renewables_share_energy,
    CAST(fossil_share_energy AS DOUBLE)        AS fossil_share_energy,
    CAST(solar_share_energy AS DOUBLE)         AS solar_share_energy,
    CAST(wind_share_energy AS DOUBLE)          AS wind_share_energy,
    CAST(hydro_share_energy AS DOUBLE)         AS hydro_share_energy,
    CAST(coal_share_energy AS DOUBLE)          AS coal_share_energy,
    CAST(oil_share_energy AS DOUBLE)           AS oil_share_energy,
    CAST(gas_share_energy AS DOUBLE)           AS gas_share_energy,
    CAST(co2_emissions AS DOUBLE)              AS co2_emissions
FROM read_csv_auto('data/owid-energy-data.csv', header=true);

-- Validação rápida da staging
SELECT
    COUNT(*)                    AS total_registros,
    COUNT(DISTINCT country)     AS total_paises,
    MIN(year)                   AS ano_inicio,
    MAX(year)                   AS ano_fim
FROM stg_energy;