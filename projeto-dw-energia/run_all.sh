#!/bin/bash
# run_all.sh — Executa o pipeline completo do DW Energia e Sustentabilidade
set -e

echo "=== DW Energia e Sustentabilidade — Pipeline Completo ==="
cd "$(dirname "$0")"

echo "[1/2] Executando pipeline ETL (staging -> oltp -> dw -> carga)..."
python3 - << 'PYEOF'
import duckdb, time

con = duckdb.connect('energia_dw.duckdb')
scripts = [
    ('scripts/00_staging.sql',  'Staging'),
    ('scripts/01_oltp.sql',     'OLTP'),
    ('scripts/02_dw_model.sql', 'DW Model'),
    ('scripts/03_etl_load.sql', 'ETL Load'),
]
for path, label in scripts:
    t0 = time.time()
    con.execute(open(path).read())
    print(f"  [OK] {label} — {time.time()-t0:.2f}s")

# Analytics e Performance (excluindo EXPLAIN)
for path, label in [('scripts/04_analytics.sql','Analytics'),('scripts/05_performance.sql','Performance')]:
    t0 = time.time()
    for stmt in open(path).read().split(';'):
        s = stmt.strip()
        if s and not s.upper().startswith('EXPLAIN'):
            try: con.execute(s)
            except: pass
    print(f"  [OK] {label} — {time.time()-t0:.2f}s")

n = con.execute("SELECT COUNT(*) FROM fact_energy").fetchone()[0]
print(f"\n  fact_energy: {n} registros carregados")
con.close()
PYEOF

echo ""
echo "[2/2] Gerando visualizações..."
python3 visualizacoes/gerar_graficos.py

echo ""
echo "=== CONCLUÍDO ==="
echo "Banco:    energia_dw.duckdb"
echo "Gráficos: visualizacoes/grafico_[1-4]_*.png"
