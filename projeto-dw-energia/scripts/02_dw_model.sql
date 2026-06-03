-- =============================================================================
-- 02_dw_model.sql
-- Projeto: Data Warehouse - Energia e Sustentabilidade (Opção 5)
-- Camada: DW — Estrutura do Modelo Dimensional (Esquema Estrela)
-- Objetivo: Criar as tabelas de dimensão e a tabela fato (sem dados ainda).
--           A carga de dados ocorre no script 03_etl_load.sql.
-- Modelo: Estrela com 3 dimensões + 1 fato
--   dim_date     -> dimensão de tempo (grain: mês/ano)
--   dim_country  -> dimensão de país com SCD Type 2
--   dim_source   -> dimensão de fonte de energia
--   fact_energy  -> tabela fato mensal por país e fonte
-- Idempotente: DROP + CREATE garante reexecução limpa.
-- =============================================================================

-- =============================================================================
-- DIMENSÃO 1: dim_date (Dimensão de Tempo)
-- Grain: um registro por mês/ano no período 2000–2023
-- =============================================================================
DROP TABLE IF EXISTS dim_date;

CREATE TABLE dim_date (
    date_key        INTEGER PRIMARY KEY,  -- formato YYYYMM (ex: 200001 para janeiro de 2000)
    year            INTEGER NOT NULL,
    month           INTEGER NOT NULL,     -- 1–12
    quarter         INTEGER NOT NULL,     -- 1–4
    year_month      VARCHAR NOT NULL,     -- ex: '2003-01'
    month_name      VARCHAR NOT NULL,     -- ex: 'January'
    semester        INTEGER NOT NULL,     -- 1 ou 2
    is_renewable_decade BOOLEAN NOT NULL  -- TRUE se ano >= 2010
);

-- =============================================================================
-- DIMENSÃO 2: dim_country (Dimensão de País — SCD Type 2)
-- Grain: um registro por versão de atributo do país
-- SCD Type 2: rastreia mudança de classificação de desenvolvimento ao longo do tempo
-- =============================================================================
DROP TABLE IF EXISTS dim_country;

CREATE TABLE dim_country (
    country_key     INTEGER PRIMARY KEY,  
    country_id      VARCHAR NOT NULL,     
    country_name    VARCHAR NOT NULL,
    region          VARCHAR NOT NULL,
    development_status VARCHAR NOT NULL,  -- 'Developed' | 'Emerging' | 'Developing'
    income_group    VARCHAR NOT NULL,     -- 'High' | 'Upper-Middle' | 'Lower-Middle' | 'Low'
    -- Controle SCD Type 2:
    scd_start_date  DATE    NOT NULL,
    scd_end_date    DATE,                 -- NULL = registro atual
    is_current      BOOLEAN NOT NULL DEFAULT TRUE
);

-- =============================================================================
-- DIMENSÃO 3: dim_source (Dimensão de Fonte de Energia)
-- Grain: um registro por tipo de fonte energética
-- Dimensão estática (não muda — sem necessidade de SCD)
-- =============================================================================
DROP TABLE IF EXISTS dim_source;

CREATE TABLE dim_source (
    source_key      INTEGER PRIMARY KEY,
    source_code     VARCHAR NOT NULL UNIQUE,  -- ex: 'SOLAR', 'WIND', 'HYDRO'
    source_name     VARCHAR NOT NULL,
    source_type     VARCHAR NOT NULL,         -- 'Renewable' | 'Fossil' | 'Mixed'
    is_renewable    BOOLEAN NOT NULL,
    is_clean        BOOLEAN NOT NULL          -- inclui nuclear como limpa
);

-- =============================================================================
-- TABELA FATO: fact_energy
-- Grain: um registro por país × mês × fonte de energia
-- Aproximadamente 50 países × 288 meses × 3 fontes = ~43.200 registros
-- Simplificado: 50 países × 288 meses = 14.400 (métricas agregadas por país-mês)
-- =============================================================================
DROP TABLE IF EXISTS fact_energy;

CREATE TABLE fact_energy (
    fact_key            BIGINT  PRIMARY KEY,  -- surrogate gerado automaticamente
    date_key            INTEGER NOT NULL REFERENCES dim_date(date_key),
    country_key         INTEGER NOT NULL REFERENCES dim_country(country_key),
    -- Métricas de consumo
    total_energy_twh        DOUBLE,   -- consumo total em TWh (proporcional ao mês)
    energy_per_capita_kwh   DOUBLE,   -- consumo per capita em kWh
    -- Participação das fontes (%)
    renewables_pct      DOUBLE,
    fossil_pct          DOUBLE,
    solar_pct           DOUBLE,
    wind_pct            DOUBLE,
    hydro_pct           DOUBLE,
    coal_pct            DOUBLE,
    oil_pct             DOUBLE,
    gas_pct             DOUBLE,
    -- Métricas absolutas (TWh)
    renewable_energy_twh DOUBLE,
    fossil_energy_twh    DOUBLE,
    solar_energy_twh     DOUBLE,
    -- Emissões
    co2_mt               DOUBLE,
    -- Dimensões degeneradas
    year                INTEGER NOT NULL,
    month               INTEGER NOT NULL
);

-- Confirmação da estrutura criada
SELECT table_name, COUNT(*) AS colunas
FROM information_schema.columns
WHERE table_name IN ('dim_date','dim_country','dim_source','fact_energy')
GROUP BY table_name
ORDER BY table_name;