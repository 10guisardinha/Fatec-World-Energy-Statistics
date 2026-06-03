-- =============================================================================
-- 01_oltp.sql
-- Projeto: Data Warehouse - Energia e Sustentabilidade (Opção 5)
-- Camada: OLTP (Transacional Normalizado)
-- Objetivo: A partir da staging, criar tabelas normalizadas, removendo
--           duplicatas, tratando nulos e separando entidades distintas.
-- Idempotente: DROP + CREATE garante reexecução sem duplicação.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabela de Países (entidade independente)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS oltp_country;

CREATE TABLE oltp_country AS
SELECT DISTINCT
    iso_code                           AS country_id,   -- identificador natural
    country                            AS country_name,
    COALESCE(region, 'Unknown')        AS region        -- trata nulos de região
FROM stg_energy
WHERE iso_code IS NOT NULL
  AND country  IS NOT NULL
ORDER BY country_name;

-- -----------------------------------------------------------------------------
-- 2. Tabela de Medições Anuais (fatos brutos normalizados)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS oltp_energy_annual;

CREATE TABLE oltp_energy_annual AS
SELECT
    iso_code                                        AS country_id,
    year,
    COALESCE(population, 0)                         AS population,
    COALESCE(gdp, 0)                                AS gdp,
    COALESCE(energy_per_capita, 0)                  AS energy_per_capita_kwh,
    COALESCE(primary_energy_consumption, 0)         AS total_energy_twh,
    COALESCE(renewables_share_energy, 0)            AS renewables_pct,
    COALESCE(fossil_share_energy, 0)                AS fossil_pct,
    COALESCE(solar_share_energy, 0)                 AS solar_pct,
    COALESCE(wind_share_energy, 0)                  AS wind_pct,
    COALESCE(hydro_share_energy, 0)                 AS hydro_pct,
    COALESCE(coal_share_energy, 0)                  AS coal_pct,
    COALESCE(oil_share_energy, 0)                   AS oil_pct,
    COALESCE(gas_share_energy, 0)                   AS gas_pct,
    COALESCE(co2_emissions, 0)                      AS co2_mt,
    COALESCE(primary_energy_consumption, 0)
        * COALESCE(renewables_share_energy, 0) / 100 AS renewable_energy_twh,
    COALESCE(primary_energy_consumption, 0)
        * COALESCE(fossil_share_energy, 0) / 100     AS fossil_energy_twh,
    COALESCE(primary_energy_consumption, 0)
        * COALESCE(solar_share_energy, 0) / 100      AS solar_energy_twh
FROM stg_energy
WHERE iso_code IS NOT NULL
  AND year     IS NOT NULL
  AND year BETWEEN 2000 AND 2023
-- Garante unicidade por país-ano (remove eventuais duplicatas do CSV)
QUALIFY ROW_NUMBER() OVER (PARTITION BY iso_code, year ORDER BY iso_code) = 1
ORDER BY country_id, year;

-- -----------------------------------------------------------------------------
-- Validações OLTP
-- -----------------------------------------------------------------------------
SELECT 'oltp_country'       AS tabela, COUNT(*) AS registros FROM oltp_country
UNION ALL
SELECT 'oltp_energy_annual' AS tabela, COUNT(*) AS registros FROM oltp_energy_annual;