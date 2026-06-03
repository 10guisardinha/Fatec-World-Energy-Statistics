# Dicionário de Dados — DW Energia e Sustentabilidade

**Projeto:** Data Warehouse — Energia e Sustentabilidade (Opção 5)  
**Banco:** DuckDB | **Arquivo:** `energia_dw.duckdb`  
**Modelo:** Esquema Estrela com 3 dimensões + 1 tabela fato

---

## Tabelas de Origem (Staging / OLTP)

### `stg_energy` (View)
Leitura direta do CSV bruto via DuckDB `read_csv_auto`.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| country | VARCHAR | Nome completo do país |
| iso_code | VARCHAR | Código ISO 3166-1 alpha-3 (ex: BRA, USA) |
| region | VARCHAR | Região geográfica (ex: South America) |
| year | INTEGER | Ano de referência (2000–2023) |
| population | BIGINT | População total do país |
| gdp | DOUBLE | PIB total em USD correntes |
| energy_per_capita | DOUBLE | Consumo de energia per capita (kWh/hab) |
| primary_energy_consumption | DOUBLE | Consumo total de energia primária (TWh) |
| renewables_share_energy | DOUBLE | Participação de renováveis (%) |
| fossil_share_energy | DOUBLE | Participação de fósseis (%) |
| solar_share_energy | DOUBLE | Participação de energia solar (%) |
| wind_share_energy | DOUBLE | Participação de energia eólica (%) |
| hydro_share_energy | DOUBLE | Participação de hidroelétrica (%) |
| coal_share_energy | DOUBLE | Participação de carvão (%) |
| oil_share_energy | DOUBLE | Participação de petróleo e derivados (%) |
| gas_share_energy | DOUBLE | Participação de gás natural (%) |
| co2_emissions | DOUBLE | Emissões de CO₂ (Mt/ano) |

### `oltp_country` (Tabela)
Entidade normalizada de países.

| Coluna | Tipo | PK/FK | Descrição |
|--------|------|-------|-----------|
| country_id | VARCHAR | PK | ISO code do país |
| country_name | VARCHAR | — | Nome completo |
| region | VARCHAR | — | Região geográfica |

### `oltp_energy_annual` (Tabela)
Medições anuais normalizadas.

| Coluna | Tipo | PK/FK | Descrição |
|--------|------|-------|-----------|
| country_id | VARCHAR | FK | Referência a oltp_country |
| year | INTEGER | — | Ano de referência |
| population | BIGINT | — | População |
| gdp | DOUBLE | — | PIB total USD |
| energy_per_capita_kwh | DOUBLE | — | Consumo per capita (kWh/hab) |
| total_energy_twh | DOUBLE | — | Consumo total (TWh) |
| renewables_pct | DOUBLE | — | % Renováveis |
| fossil_pct | DOUBLE | — | % Fósseis |
| solar_pct | DOUBLE | — | % Solar |
| wind_pct | DOUBLE | — | % Eólica |
| hydro_pct | DOUBLE | — | % Hidro |
| coal_pct | DOUBLE | — | % Carvão |
| oil_pct | DOUBLE | — | % Petróleo |
| gas_pct | DOUBLE | — | % Gás |
| co2_mt | DOUBLE | — | CO₂ total (Mt) |
| renewable_energy_twh | DOUBLE | — | TWh de renováveis |
| fossil_energy_twh | DOUBLE | — | TWh de fósseis |
| solar_energy_twh | DOUBLE | — | TWh de solar |

---

## Dimensões (DW)

### `dim_date` (Dimensão de Tempo)
Grain: 1 registro por mês/ano. Total: 288 registros (24 anos × 12 meses).

| Coluna | Tipo | PK | Descrição |
|--------|------|----|-----------|
| date_key | INTEGER | PK | Surrogate: YYYYMM (ex: 200301) |
| year | INTEGER | — | Ano (2000–2023) |
| month | INTEGER | — | Mês (1–12) |
| quarter | INTEGER | — | Trimestre (1–4) |
| year_month | VARCHAR | — | Texto: '2003-01' |
| month_name | VARCHAR | — | Nome do mês em inglês |
| semester | INTEGER | — | Semestre (1 ou 2) |
| is_renewable_decade | BOOLEAN | — | TRUE se ano ≥ 2010 |

### `dim_country` (Dimensão de País — SCD Type 2)
Grain: 1 registro por versão de atributo. Total: 100 registros (50 países × 2 versões).

| Coluna | Tipo | PK/FK | Descrição |
|--------|------|-------|-----------|
| country_key | INTEGER | PK | Surrogate key auto-gerada |
| country_id | VARCHAR | NK | ISO code (chave natural) |
| country_name | VARCHAR | — | Nome do país |
| region | VARCHAR | — | Região geográfica |
| development_status | VARCHAR | — | 'Developed' / 'Emerging' / 'Developing' |
| income_group | VARCHAR | — | 'High' / 'Upper-Middle' / 'Lower-Middle' / 'Low' |
| scd_start_date | DATE | — | Início de validade do registro |
| scd_end_date | DATE | — | Fim de validade (NULL = atual) |
| is_current | BOOLEAN | — | TRUE = registro ativo |

**Implementação SCD Type 2:** O atributo `development_status` e `income_group` variam entre dois períodos históricos (2000–2011 e 2012–2023), com base no PIB per capita médio de cada período. Países como o Brasil foram reclassificados de *Developing* para *Emerging* na versão mais recente.

### `dim_source` (Dimensão de Fonte de Energia)
Dimensão estática. Total: 9 registros.

| Coluna | Tipo | PK | Descrição |
|--------|------|----|-----------|
| source_key | INTEGER | PK | Surrogate key |
| source_code | VARCHAR | UK | Código da fonte (ex: SOLAR) |
| source_name | VARCHAR | — | Nome completo |
| source_type | VARCHAR | — | 'Renewable' / 'Fossil' / 'Mixed' |
| is_renewable | BOOLEAN | — | TRUE se fonte renovável |
| is_clean | BOOLEAN | — | TRUE se fonte limpa (inclui nuclear) |

---

## Tabela Fato

### `fact_energy` (Fato de Energia Mensal)
Grain: 1 registro por país × mês. Total: **14.400 registros** (50 países × 24 anos × 12 meses).

| Coluna | Tipo | PK/FK | Descrição |
|--------|------|-------|-----------|
| fact_key | BIGINT | PK | Surrogate key auto-gerada |
| date_key | INTEGER | FK -> dim_date | Chave de tempo |
| country_key | INTEGER | FK -> dim_country | Chave de país |
| total_energy_twh | DOUBLE | — | Consumo mensal total (TWh) |
| energy_per_capita_kwh | DOUBLE | — | Consumo per capita (kWh/hab) |
| renewables_pct | DOUBLE | — | % Renováveis no mês |
| fossil_pct | DOUBLE | — | % Fósseis no mês |
| solar_pct | DOUBLE | — | % Solar no mês |
| wind_pct | DOUBLE | — | % Eólica no mês |
| hydro_pct | DOUBLE | — | % Hidrelétrica no mês |
| coal_pct | DOUBLE | — | % Carvão no mês |
| oil_pct | DOUBLE | — | % Petróleo no mês |
| gas_pct | DOUBLE | — | % Gás no mês |
| renewable_energy_twh | DOUBLE | — | TWh de renováveis no mês |
| fossil_energy_twh | DOUBLE | — | TWh de fósseis no mês |
| solar_energy_twh | DOUBLE | — | TWh de solar no mês |
| co2_mt | DOUBLE | — | CO₂ mensal (Mt) |
| year | INTEGER | — | Ano (degenerado, para performance) |
| month | INTEGER | — | Mês (degenerado, para performance) |

---

## Tabela Agregada (Performance)

### `agg_country_year`
Grain: 1 registro por país × ano. Total: 1.200 registros (50 países × 24 anos).  
Redução de 12× em relação à fact_energy para queries analíticas anuais.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| country_key | INTEGER | FK -> dim_country |
| country_name | VARCHAR | Nome do país (inline) |
| region | VARCHAR | Região (inline) |
| development_status | VARCHAR | Status de desenvolvimento (inline) |
| income_group | VARCHAR | Grupo de renda (inline) |
| year | INTEGER | Ano de referência |
| renewables_pct … gas_pct | DOUBLE | Médias anuais das participações (%) |
| energy_per_capita_kwh | DOUBLE | Média anual do consumo per capita |
| total_energy_twh | DOUBLE | Soma anual do consumo (TWh) |
| renewable_energy_twh | DOUBLE | TWh anuais renováveis |
| fossil_energy_twh | DOUBLE | TWh anuais fósseis |
| solar_energy_twh | DOUBLE | TWh anuais solar |
| co2_mt_anual | DOUBLE | CO₂ total anual (Mt) |
| meses_registrados | INTEGER | Qtd de meses que compõem o agregado (sempre 12) |
