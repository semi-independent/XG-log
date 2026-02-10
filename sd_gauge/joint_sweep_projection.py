import csv
from pathlib import Path

base = Path('notes/ab_compare')
s_path = base / 'scenario_sweep_S0_S12.csv'
d_path = base / 'direction_stage_sweep_D0_D12.csv'
out_csv = base / 'joint_sweep_Sx_Dx.csv'
out_svg = base / 'joint_sweep_heatmap.svg'

s_rows = []
with s_path.open() as f:
    r = csv.DictReader(f)
    for row in r:
        s_rows.append({
            'S': int(row['S']),
            'net': float(row['R_net_B']),
            'loss8': int(float(row['R_loss8_B'])),
            'avg_loss': float(row['R_avg_loss_B']),
        })

# Use D0..D8 (beyond that likely optimistic in current phase)
d_rows = []
with d_path.open() as f:
    r = csv.DictReader(f)
    for row in r:
        d = int(row['stage'][1:])
        if d <= 8:
            d_rows.append({
                'D': d,
                'net': float(row['net']),
                'loss8': int(float(row['loss<=-8'])),
                'avg_loss': float(row['avg_loss']),
            })

# Anchor: D sweep baseline is S6 (D0 row)
D0 = next(x for x in d_rows if x['D'] == 0)

records = []
for s in s_rows:
    # S6から離れるほど方向改善の効きを少し減衰（過学習防止の安全側）
    dist = abs(s['S'] - 6)
    coupling = max(0.78, 1.0 - 0.03 * dist)
    for d in d_rows:
        d_net_gain = (d['net'] - D0['net']) * coupling
        d_loss8_delta = (d['loss8'] - D0['loss8']) * coupling
        d_avg_delta = (d['avg_loss'] - D0['avg_loss']) * coupling

        net = s['net'] + d_net_gain
        loss8 = max(0, int(round(s['loss8'] + d_loss8_delta)))
        avg_loss = s['avg_loss'] + d_avg_delta

        # ranking score (net重視、-8帯減少を加点)
        score = net - 6.0 * loss8 + (5.4 - avg_loss) * 4.0
        records.append({
            'S': s['S'],
            'D': d['D'],
            'coupling': round(coupling, 3),
            'net': round(net, 2),
            'loss8': loss8,
            'avg_loss': round(avg_loss, 2),
            'score': round(score, 2),
        })

records.sort(key=lambda x: (-x['score'], -x['net'], x['loss8'], x['avg_loss']))

with out_csv.open('w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=['S', 'D', 'coupling', 'net', 'loss8', 'avg_loss', 'score'])
    w.writeheader()
    for row in records:
        w.writerow(row)

# Heatmap SVG
S_vals = sorted({r['S'] for r in records})
D_vals = sorted({r['D'] for r in records})

lookup = {(r['S'], r['D']): r for r in records}

w, h = 1480, 920
left, top = 130, 110
grid_w, grid_h = 980, 620
cw = grid_w / len(S_vals)
ch = grid_h / len(D_vals)

net_values = [r['net'] for r in records]
min_v, max_v = min(net_values), max(net_values)
span = max(1e-9, max_v - min_v)

def color(v):
    t = (v - min_v) / span
    r = int(230 - 140 * t)
    g = int(70 + 160 * t)
    b = int(80 + 80 * (1 - t))
    return f"rgb({r},{g},{b})"

svg = []
svg.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}">')
svg.append('<rect width="100%" height="100%" fill="white"/>')
svg.append('<text x="130" y="44" font-size="28" font-family="Arial" fill="#111">Joint Sweep: S(尻尾カット) × D(方向整流)</text>')
svg.append('<text x="130" y="74" font-size="15" fill="#444">基準: RSLT_2214 + ReportHistory-20049725 / 想定モデル（安全側減衰付き）</text>')

for i, d in enumerate(D_vals):
    y = top + i * ch
    svg.append(f'<text x="84" y="{y + ch*0.62:.1f}" font-size="13" fill="#444">D{d}</text>')

for j, s in enumerate(S_vals):
    x = left + j * cw
    svg.append(f'<text x="{x + cw*0.36:.1f}" y="{top + grid_h + 26:.1f}" font-size="13" fill="#444">S{s}</text>')

for i, d in enumerate(D_vals):
    for j, s in enumerate(S_vals):
        rec = lookup[(s, d)]
        x = left + j * cw
        y = top + i * ch
        fill = color(rec['net'])
        stroke = '#eee'
        sw = 1
        if rec['S'] == 6 and rec['D'] == 0:
            stroke = '#111'
            sw = 2
        svg.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{cw:.1f}" height="{ch:.1f}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
        svg.append(f'<text x="{x + 8:.1f}" y="{y + 20:.1f}" font-size="12" fill="#fff">{rec["net"]:.1f}</text>')
        svg.append(f'<text x="{x + 8:.1f}" y="{y + 37:.1f}" font-size="11" fill="#fff">L8:{rec["loss8"]}</text>')

# highlight top 3
top3 = records[:3]
for idx, rec in enumerate(top3, start=1):
    x = left + S_vals.index(rec['S']) * cw
    y = top + D_vals.index(rec['D']) * ch
    svg.append(f'<rect x="{x+2:.1f}" y="{y+2:.1f}" width="{cw-4:.1f}" height="{ch-4:.1f}" fill="none" stroke="#111" stroke-width="3"/>')
    svg.append(f'<text x="{x+cw-24:.1f}" y="{y+18:.1f}" font-size="14" fill="#111">#{idx}</text>')

# legend
lx, ly, lw, lh = 1160, 140, 220, 22
for i in range(11):
    t = i / 10
    v = min_v + span * t
    svg.append(f'<rect x="{lx + i*(lw/11):.1f}" y="{ly}" width="{lw/11 + 1:.1f}" height="{lh}" fill="{color(v)}"/>')
svg.append(f'<text x="{lx}" y="{ly-8}" font-size="12" fill="#333">net {min_v:.1f} → {max_v:.1f}</text>')
svg.append(f'<text x="{1160}" y="{200}" font-size="13" fill="#222">#1 S{top3[0]["S"]} D{top3[0]["D"]} net={top3[0]["net"]:.2f}</text>')
svg.append(f'<text x="{1160}" y="{222}" font-size="13" fill="#222">#2 S{top3[1]["S"]} D{top3[1]["D"]} net={top3[1]["net"]:.2f}</text>')
svg.append(f'<text x="{1160}" y="{244}" font-size="13" fill="#222">#3 S{top3[2]["S"]} D{top3[2]["D"]} net={top3[2]["net"]:.2f}</text>')
svg.append('<text x="1160" y="282" font-size="12" fill="#666">※濃い緑ほど改善寄り、赤ほど悪化寄り</text>')
svg.append('<text x="1160" y="304" font-size="12" fill="#666">※太枠: 現在の暫定基準(S6,D0)</text>')

svg.append('</svg>')
out_svg.write_text(''.join(svg), encoding='utf-8')

print(f'Wrote {out_csv}')
print(f'Wrote {out_svg}')
print('Top 5:')
for row in records[:5]:
    print(row)
