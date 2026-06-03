# DW Energia e Sustentabilidade — Opção 5

**Disciplina:** Banco e Armazém de Dados em Ciências de Dados  
**Integrante:** Guilherme Alexandre Sardinha
**Dataset:** World Energy Statistics (Our World in Data — `owid-energy-data.csv`)  
**Banco:** DuckDB | **ETL:** SQL + Python | **Visualização:** Plotly

---

# Respostas às Perguntas Analíticas — DW Energia e Sustentabilidade

## 1. Como cresceu a energia solar no Brasil (2000–2023)?

| Ano  | Solar (%) | Renováveis (%) | Fósseis (%) |
|------|-----------|----------------|-------------|
| 2000 | 0,20      | 77,7           | 18,3        |
| 2005 | 2,17      | 77,9           | 16,0        |
| 2010 | 8,64      | 81,6           | 12,2        |
| 2015 | 19,47     | 84,7           | 11,2        |
| 2020 | 33,46     | 85,9           | 9,4         |
| 2023 | 40,00     | 87,9           | 6,7         |

A energia solar saiu de praticamente **zero em 2000 para 40% em 2023**, um crescimento exponencial especialmente acelerado após 2012. O Brasil já tinha uma matriz limpa graças à hidroeletricidade, mas a solar reforçou ainda mais esse perfil — enquanto os fósseis caíram de 18% para menos de 7% no período.

---

## 2. Quais países usam mais energia renovável (2023)?

| # | País         | Renovável (%) | Solar (%) | Eólica (%) | Hidro (%) |
|---|--------------|---------------|-----------|------------|-----------|
| 1 | Noruega      | 99,0          | 12,9      | 24,3       | 61,8      |
| 2 | Nova Zelândia| 93,0          | 22,4      | 21,8       | 48,9      |
| 3 | **Brasil**   | **87,9**      | 40,0      | 22,7       | 25,2      |
| 4 | Suíça        | 86,4          | 20,0      | 22,0       | 44,4      |
| 5 | Suécia       | 84,4          | 19,4      | 21,5       | 43,5      |
| 6 | Dinamarca    | 81,4          | 25,7      | 20,4       | 35,3      |
| 7 | Colômbia     | 80,0          | 40,0      | 20,9       | 19,1      |
| 8 | Quênia       | 79,1          | 35,6      | 20,6       | 22,9      |
| 9 | Áustria      | 77,1          | 22,1      | 20,6       | 34,5      |
|10 | Canadá       | 73,9          | 18,8      | 19,3       | 35,8      |
|11 | Peru         | 67,3          | 40,0      | 15,7       | 11,7      |
|12 | Finlândia    | 67,1          | 16,3      | 16,8       | 33,9      |
|13 | Portugal     | 65,2          | 30,1      | 15,4       | 19,6      |
|14 | Chile        | 57,6          | 40,0      | 16,1       | 1,6       |
|15 | Espanha      | 50,4          | 29,8      | 12,1       | 8,5       |

O Brasil aparece em **3º lugar mundial**, notável para um país de dimensão continental. Os líderes europeus se apoiam em hidro + eólica; o Brasil se destaca por combinar hidro histórica com uma das maiores participações solares do top 10.

---

## 3. Evolução do consumo per capita por nível de desenvolvimento?

| Grupo         | 2000 (kWh/hab) | 2010   | 2023   | Crescimento |
|---------------|----------------|--------|--------|-------------|
| Desenvolvidos | 946            | 1.027  | 1.163  | +23%        |
| Emergentes    | 266            | 332    | 412    | +55%        |
| Desenvolvendo | 74             | 93     | 119    | +61%        |

Os países desenvolvidos consomem cerca de **10× mais energia per capita** que os em desenvolvimento, e essa lacuna persiste. Os emergentes crescem mais rápido (+55%), refletindo industrialização acelerada. Países em desenvolvimento ainda consomem muito pouco — sinal tanto de pobreza energética quanto de baixa industrialização.

---

## 4. Fontes limpas vs fósseis por grupo de renda e década?

| Grupo de Renda  | Década | Renovável (%) | Fóssil (%) | Solar (%) | Países |
|-----------------|--------|---------------|------------|-----------|--------|
| High            | 2000s  | 44,9          | 47,9       | 2,9       | 22     |
| High            | 2010s  | 49,3          | 44,3       | 11,6      | 22     |
| High            | 2020s  | 52,2          | 41,9       | 22,8      | 22     |
| Upper-Middle    | 2000s  | 31,1          | 65,5       | 2,8       | 12     |
| Upper-Middle    | 2010s  | 36,1          | 62,1       | 15,5      | 12     |
| Upper-Middle    | 2020s  | 39,2          | 59,3       | 30,6      | 12     |
| Lower-Middle    | 2000s  | 27,7          | 70,1       | 2,2       | 9      |
| Lower-Middle    | 2010s  | 32,1          | 66,5       | 15,4      | 9      |
| Lower-Middle    | 2020s  | 35,1          | 64,1       | 32,0      | 9      |
| Low             | 2000s  | 29,9          | 67,9       | 2,0       | 7      |
| Low             | 2010s  | 34,6          | 64,1       | 14,9      | 7      |
| Low             | 2020s  | 37,8          | 62,3       | 29,6      | 7      |

Três conclusões claras:

1. **Todos os grupos de renda aumentaram renováveis** a cada década, sem exceção.
2. A solar explodiu nos 2020s em todos os grupos — curiosamente mais nos países de baixa e média-baixa renda, onde o custo competitivo dos painéis foi determinante.
3. Os países de alta renda ainda têm a **maior participação renovável absoluta**, mas a convergência está em curso.

---

## Estrutura
```
projeto-dw-energia/
├── data/owid-energy-data.csv        # Dataset fonte (50 países × 24 anos)
├── scripts/
│   ├── 00_staging.sql               # Views sobre o CSV bruto
│   ├── 01_oltp.sql                  # Tabelas OLTP normalizadas
│   ├── 02_dw_model.sql              # Estrutura do DW (dimensões + fato)
│   ├── 03_etl_load.sql              # Carga ETL com SCD Type 2
│   ├── 04_analytics.sql             # 5 consultas analíticas
│   └── 05_performance.sql           # Tabela agregada + benchmark
├── visualizacoes/
│   ├── gerar_graficos.py            # Geração dos gráficos
│   └── grafico_[1-4]_.png/          # 4 gráficos + insights
├── docs/
│   └── dicionario_dados.md          # Dicionário completo
└── run_all.sh                       # Script para rodar tudo
```

---

## Como Executar

### Pré-requisitos
```bash
pip install duckdb plotly pandas kaleido==0.2.1
```

### Executar pipeline completo
```bash
bash run_all.sh
```

### Ou manualmente (passo a passo)
```bash
# 1. Rodar o pipeline ETL
python3 run_pipeline.py

# 2. Gerar os gráficos
cd projeto-dw-energia
python3 visualizacoes/gerar_graficos.py
```

---

## Modelo Dimensional

```
          dim_date (288 registros)
          date_key (PK) ─────────────────┐
          year, month, quarter...        │
                                         ▼
dim_country (100 registros)      fact_energy (14.400 registros)
country_key (PK) ────────────► country_key (FK)
country_name, region            date_key (FK)
development_status ◄─SCD2      total_energy_twh
income_group                    renewables_pct, fossil_pct
scd_start/end_date              solar_pct, wind_pct, hydro_pct
is_current                      co2_mt, energy_per_capita_kwh
```

**SCD Type 2:** O Brasil foi reclassificado de *Developing* -> *Emerging* entre os períodos 2000–2011 e 2012–2023.

---

## Resultados Resumidos

| Métrica | Valor |
|---------|-------|
| Registros na fact_energy | **14.400** |
| Países analisados | 50 |
| Período | 2000–2023 |
| Dimensões | 3 (date, country, source) |
| Consultas analíticas | 5 |
| Gráficos gerados | 4 |
