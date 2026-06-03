import duckdb
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import os

# Garante que a pasta de saída existe
os.makedirs('visualizacoes', exist_ok=True)

# Conexão com o DW já populado
con = duckdb.connect('energia_dw.duckdb')

# Paleta de cores
CORES_FONTES = {
    'Solar':    '#F4A100',
    'Wind':     '#4FC3F7',
    'Hydro':    '#0288D1',
    'Renewables': '#2E7D32',
    'Fossil':   '#B71C1C',
}

# =============================================================================
# GRÁFICO 1 — Linha do Tempo
# Evolução da energia solar no Brasil (2000–2023)
# =============================================================================
df1 = con.execute("""
    SELECT
        a.year,
        ROUND(AVG(a.solar_pct), 2)       AS solar_pct,
        ROUND(AVG(a.renewables_pct), 2)  AS renovavel_pct,
        ROUND(AVG(a.fossil_pct), 2)      AS fossil_pct
    FROM agg_country_year a
    WHERE a.country_name = 'Brazil'
    GROUP BY a.year
    ORDER BY a.year
""").df()

fig1 = go.Figure()
fig1.add_trace(go.Scatter(
    x=df1['year'], y=df1['renovavel_pct'],
    name='Renováveis (%)', mode='lines+markers',
    line=dict(color=CORES_FONTES['Renewables'], width=2.5),
    marker=dict(size=5)
))
fig1.add_trace(go.Scatter(
    x=df1['year'], y=df1['fossil_pct'],
    name='Fósseis (%)', mode='lines+markers',
    line=dict(color=CORES_FONTES['Fossil'], width=2.5, dash='dash'),
    marker=dict(size=5)
))
fig1.add_trace(go.Scatter(
    x=df1['year'], y=df1['solar_pct'],
    name='Solar (%)', mode='lines+markers',
    line=dict(color=CORES_FONTES['Solar'], width=2),
    marker=dict(size=5)
))
fig1.update_layout(
    title='Evolução da Matriz Energética do Brasil (2000–2023)',
    xaxis_title='Ano',
    yaxis_title='Participação na Matriz Energética (%)',
    legend_title='Fonte',
    template='plotly_white',
    font=dict(family='Arial', size=13),
    hovermode='x unified',
    width=900, height=500
)
fig1.write_image('visualizacoes/grafico_1_evolucao_brasil.png', scale=2)
fig1.write_html('visualizacoes/grafico_1_evolucao_brasil.html')
print("[OK] Gráfico 1 salvo")

# =============================================================================
# GRÁFICO 2 — Barras (Ranking)
# Top 15 países com maior participação renovável em 2023
# =============================================================================
df2 = con.execute("""
    SELECT
        country_name,
        region,
        ROUND(AVG(renewables_pct), 1) AS renovavel_pct,
        ROUND(AVG(solar_pct), 1)      AS solar_pct,
        ROUND(AVG(wind_pct), 1)       AS wind_pct,
        ROUND(AVG(hydro_pct), 1)      AS hydro_pct
    FROM agg_country_year
    WHERE year = 2023
    GROUP BY country_name, region
    ORDER BY renovavel_pct DESC
    LIMIT 15
""").df()

fig2 = go.Figure()
fig2.add_trace(go.Bar(
    y=df2['country_name'], x=df2['solar_pct'],
    name='Solar', orientation='h',
    marker_color=CORES_FONTES['Solar']
))
fig2.add_trace(go.Bar(
    y=df2['country_name'], x=df2['wind_pct'],
    name='Eólica', orientation='h',
    marker_color=CORES_FONTES['Wind']
))
fig2.add_trace(go.Bar(
    y=df2['country_name'], x=df2['hydro_pct'],
    name='Hidrelétrica', orientation='h',
    marker_color=CORES_FONTES['Hydro']
))
fig2.update_layout(
    barmode='stack',
    title='Top 15 Países com Maior Participação Renovável (2023)',
    xaxis_title='Participação Renovável (%)',
    yaxis_title='País',
    legend_title='Fonte Renovável',
    template='plotly_white',
    font=dict(family='Arial', size=12),
    yaxis=dict(autorange='reversed'),
    width=900, height=550
)
fig2.write_image('visualizacoes/grafico_2_ranking_renovavel.png', scale=2)
fig2.write_html('visualizacoes/grafico_2_ranking_renovavel.html')
print("[OK] Gráfico 2 salvo")

# =============================================================================
# GRÁFICO 3 — Mapa de Calor
# Participação renovável por país e décadas (2000–2023)
# =============================================================================
df3 = con.execute("""
    SELECT
        country_name,
        CASE
            WHEN year BETWEEN 2000 AND 2007 THEN '2000-2007'
            WHEN year BETWEEN 2008 AND 2015 THEN '2008-2015'
            ELSE '2016-2023'
        END AS periodo,
        ROUND(AVG(renewables_pct), 1) AS renovavel_pct
    FROM agg_country_year
    GROUP BY country_name, periodo
    ORDER BY country_name, periodo
""").df()

df3_pivot = df3.pivot(index='country_name', columns='periodo', values='renovavel_pct')
df3_pivot = df3_pivot.sort_values('2016-2023', ascending=False).head(25)

fig3 = go.Figure(data=go.Heatmap(
    z=df3_pivot.values,
    x=df3_pivot.columns.tolist(),
    y=df3_pivot.index.tolist(),
    colorscale='YlGn',
    colorbar=dict(title='% Renovável'),
    text=df3_pivot.values.round(1),
    texttemplate='%{text}%',
    hovertemplate='País: %{y}<br>Período: %{x}<br>Renovável: %{z:.1f}%<extra></extra>'
))
fig3.update_layout(
    title='Participação Renovável por País e Período (Top 25 países, %)',
    xaxis_title='Período',
    yaxis_title='País',
    template='plotly_white',
    font=dict(family='Arial', size=11),
    width=900, height=700
)
fig3.write_image('visualizacoes/grafico_3_heatmap_renovavel.png', scale=2)
fig3.write_html('visualizacoes/grafico_3_heatmap_renovavel.html')
print("[OK] Gráfico 3 salvo")

# =============================================================================
# GRÁFICO 4 — Dashboard / Composição
# Painel comparativo: Limpas vs Fósseis por nível de desenvolvimento
# =============================================================================
df4 = con.execute("""
    SELECT
        development_status,
        year,
        ROUND(AVG(renewables_pct), 2) AS renovavel_pct,
        ROUND(AVG(fossil_pct), 2)     AS fossil_pct,
        ROUND(AVG(solar_pct), 2)      AS solar_pct,
        ROUND(AVG(energy_per_capita_kwh), 0) AS consumo_pc
    FROM agg_country_year
    GROUP BY development_status, year
    ORDER BY development_status, year
""").df()

fig4 = make_subplots(
    rows=2, cols=2,
    subplot_titles=(
        'Participação Renovável por Nível de Desenvolvimento',
        'Participação Fóssil por Nível de Desenvolvimento',
        'Crescimento da Energia Solar por Desenvolvimento',
        'Consumo Per Capita (kWh) por Desenvolvimento'
    ),
    horizontal_spacing=0.12,
    vertical_spacing=0.18
)

dev_status = df4['development_status'].unique()
cores_dev = {'Developed': '#1565C0', 'Emerging': '#2E7D32', 'Developing': '#F57F17'}

for status in sorted(dev_status):
    sub = df4[df4['development_status'] == status]
    cor = cores_dev.get(status, '#999')
    kw = dict(x=sub['year'], mode='lines', name=status, line=dict(color=cor, width=2),
              showlegend=True)

    fig4.add_trace(go.Scatter(y=sub['renovavel_pct'],   **kw), row=1, col=1)
    kw['showlegend'] = False
    fig4.add_trace(go.Scatter(y=sub['fossil_pct'],      **kw), row=1, col=2)
    fig4.add_trace(go.Scatter(y=sub['solar_pct'],       **kw), row=2, col=1)
    fig4.add_trace(go.Scatter(y=sub['consumo_pc'],      **kw), row=2, col=2)

fig4.update_xaxes(title_text='Ano', tickangle=-45)
fig4.update_yaxes(title_text='%',   row=1, col=1)
fig4.update_yaxes(title_text='%',   row=1, col=2)
fig4.update_yaxes(title_text='%',   row=2, col=1)
fig4.update_yaxes(title_text='kWh', row=2, col=2)
fig4.update_layout(
    title='Dashboard: Transição Energética por Nível de Desenvolvimento (2000–2023)',
    template='plotly_white',
    font=dict(family='Arial', size=11),
    legend=dict(title='Desenvolvimento', orientation='h', y=-0.15),
    width=1100, height=700
)
fig4.write_image('visualizacoes/grafico_4_dashboard.png', scale=2)
fig4.write_html('visualizacoes/grafico_4_dashboard.html')
print("[OK] Gráfico 4 salvo")

con.close()
print("\n[CONCLUÍDO] Todos os gráficos gerados em visualizacoes/")