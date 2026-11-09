"""Written with AI assistance (Claude, Anthropic).
Builds PNG charts for business_insights.md from orders_anonymized.xlsx (delivered orders only)."""
import sys, glob
import pandas as pd, numpy as np
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager as fm
from matplotlib.colors import LinearSegmentedColormap

SRC = sys.argv[1]; OUT = sys.argv[2] if len(sys.argv) > 2 else '.'
for f in glob.glob('/usr/share/fonts/opentype/inter/Inter-*.otf'): fm.fontManager.addfont(f)
BLUE, ORANGE, GRAY = '#2a78d6', '#eb6834', '#b9b8b2'
INK, INK2, GRID, SURF = '#0b0b0b', '#52514e', '#e6e5e0', '#fcfcfb'
plt.rcParams.update({'font.family': ['Inter', 'DejaVu Sans'], 'figure.facecolor': SURF, 'axes.facecolor': SURF,
    'axes.edgecolor': GRID, 'axes.labelcolor': INK2, 'xtick.color': INK2, 'ytick.color': INK2, 'text.color': INK,
    'axes.spines.top': False, 'axes.spines.right': False, 'axes.grid': True, 'grid.color': GRID, 'grid.linewidth': .8,
    'axes.axisbelow': True, 'savefig.facecolor': SURF, 'font.size': 11})

df = pd.read_csv(SRC, parse_dates=['Date']) if SRC.endswith('.csv') else pd.read_excel(SRC); Q = 'Количество воды'
d = df[df.Status == 'Доставлено'].copy(); d['m'] = d.Date.dt.to_period('M')

def title(fig, t, sub):
    fig.text(.06, .965, t, fontsize=16, fontweight='bold', va='top')
    fig.text(.06, .915, sub, fontsize=11, color=INK2, va='top')
def save(fig, name):
    fig.savefig(f'{OUT}/{name}.png', dpi=160); plt.close(fig)
def clean(ax, ygrid=True):
    ax.grid(axis='x', visible=False) if ygrid else ax.grid(axis='y', visible=False)
    ax.tick_params(length=0)

# 1. monthly bottles + orders (two panels, one axis each)
m = d.groupby('m').agg(orders=(Q, 'size'), bottles=(Q, 'sum'), addr=('address_id', 'nunique'))
lab = [p.strftime('%b\n%y') if p.month in (1,) or i == 0 else p.strftime('%b') for i, p in enumerate(m.index)]
fig, axs = plt.subplots(2, 1, figsize=(11, 7.6), sharex=True); fig.subplots_adjust(top=.80, hspace=.28, left=.09, right=.97, bottom=.08)
title(fig, 'Bottles fell faster than orders', 'Delivered bottles and orders per month. Lighter bars: partial months (data starts 29 Jul 2025, ends 29 Oct 2026)')
for ax, col, name in [(axs[0], 'bottles', 'Bottles per month'), (axs[1], 'orders', 'Delivered orders per month')]:
    cols = [BLUE if i not in (0, len(m)-1) else '#a9c8ee' for i in range(len(m))]
    ax.bar(range(len(m)), m[col], color=cols, width=.68); clean(ax)
    ax.set_title(name, loc='left', fontsize=11, color=INK2, pad=6)
    for i, v in enumerate(m[col]):
        if i in (1, 8, 9, 10, len(m)-2): ax.text(i, v + m[col].max()*.02, f'{v:,}', ha='center', fontsize=9, color=INK2)
axs[0].annotate('Mar 2026: 14-day gap in data\n(22 Feb – 6 Mar)', xy=(8, 1330), xytext=(4.3, 2060), fontsize=9, color=INK2, arrowprops=dict(arrowstyle='-', color=GRAY))
axs[1].set_xticks(range(len(m))); axs[1].set_xticklabels(lab)
save(fig, '01_monthly_bottles_orders')

# 2. active vs first-observed addresses
fo = d.groupby('address_id').Date.min().dt.to_period('M').value_counts().sort_index()
fig, ax = plt.subplots(figsize=(11, 5.6)); fig.subplots_adjust(top=.80, left=.08, right=.86, bottom=.19)
title(fig, 'The active base is shrinking, and fewer first-observed addresses are arriving', 'Addresses with at least one delivery in the month, and addresses with their first observed delivery')
x = range(1, len(m)-1)  # drop partial months
act = m.addr.iloc[1:-1]; new = fo.reindex(m.index).fillna(0).iloc[1:-1]
ax.plot(x, act.values, color=BLUE, lw=2, marker='o', ms=5); ax.plot(x, new.values, color=ORANGE, lw=2, marker='o', ms=5)
ax.text(x[-1]+.25, act.values[-1], 'Active addresses', color=INK, va='center', fontsize=10); ax.text(x[-1]+.25, new.values[-1], 'First-observed\naddresses*', color=INK, va='center', fontsize=10)
ax.scatter([x[-1]+.25-.45], [act.values[-1]], s=0)
for i, v in zip(x, act.values):
    if i in (1, 8, len(m)-2): ax.text(i, v+12, int(v), ha='center', fontsize=9, color=INK2)
ax.set_xticks(list(x)); ax.set_xticklabels([p.strftime('%b\n%y') if p.month in (1,) or i == 1 else p.strftime('%b') for i, p in zip(x, m.index[1:-1])])
ax.set_ylim(0, 420); ax.set_xlim(.6, len(m)-.6); clean(ax); ax.set_ylabel('Addresses')
fig.text(.08, .025, '* First-observed = first delivery in this dataset, not necessarily a new customer of the business: Aug 2025 includes customers who ordered before the data starts.\n  Partial months (Jul 2025, Oct 2026) excluded.', fontsize=9, color=INK2)
save(fig, '02_active_and_first_observed_addresses')

# 3. segments
a = d.groupby('address_id').agg(o=(Q, 'size'), b=(Q, 'sum'))
a['seg'] = pd.cut(a.o, [0, 1, 3, 6, 12, 1e9], labels=['One-time\n(1)', 'Occasional\n(2–3)', 'Regular\n(4–6)', 'Frequent\n(7–12)', 'High frequency\n(13+)'])
s = a.groupby('seg', observed=True).agg(n=('o', 'size'), b=('b', 'sum')); s['n%'] = 100*s.n/s.n.sum(); s['b%'] = 100*s.b/s.b.sum()
fig, ax = plt.subplots(figsize=(11, 5.8)); fig.subplots_adjust(top=.80, left=.07, right=.97, bottom=.14)
title(fig, '6% of addresses bring 58% of the bottles', 'Share of addresses vs share of bottles by order-frequency segment (delivered orders, whole period)')
w = .36; xs = np.arange(len(s))
b1 = ax.bar(xs-w/2-.01, s['n%'], w, color=BLUE, label='% of addresses'); b2 = ax.bar(xs+w/2+.01, s['b%'], w, color=ORANGE, label='% of bottles')
for bars in (b1, b2):
    for r in bars: ax.text(r.get_x()+r.get_width()/2, r.get_height()+1, f'{r.get_height():.1f}%', ha='center', fontsize=9.5, color=INK2)
ax.set_xticks(xs); ax.set_xticklabels(s.index); ax.set_ylim(0, 66); ax.set_yticks([]); ax.grid(False); ax.spines['left'].set_visible(False)
ax.legend(frameon=False, loc='upper center', ncol=2, bbox_to_anchor=(.5, 1.03)); ax.tick_params(length=0)
save(fig, '03_customer_segments')

# 4. concentration curve
t = a.sort_values(['o','b'], ascending=False); cx = np.arange(1, len(t)+1)/len(t)*100; cy = (t.b.cumsum()/t.b.sum()*100).values
fig, ax = plt.subplots(figsize=(9, 6.6)); fig.subplots_adjust(top=.84, left=.1, right=.96, bottom=.1)
title(fig, 'A few addresses carry the volume', 'Cumulative share of delivered bottles, addresses ranked by number of delivered orders')
ax.plot([0, 100], [0, 100], color=GRAY, lw=1.2, ls='--'); ax.plot(np.r_[0, cx], np.r_[0, cy], color=BLUE, lw=2.4)
ax.text(52, 41, 'Equal share line', color=INK2, fontsize=9.5, rotation=34)
for p in (1, 10, 20):
    v = cy[int(round(len(t)*p/100))-1]; ax.scatter([p], [v], color=BLUE, s=50, zorder=5, edgecolor=SURF, linewidth=2)
    ax.annotate(f'Top {p}% of addresses\n= {v:.0f}% of bottles', (p, v), xytext=(p+9, v-16 if p == 1 else v-14), fontsize=10, color=INK, arrowprops=dict(arrowstyle='-', color=GRAY))
ax.set_xlim(0, 100); ax.set_ylim(0, 102); ax.set_xlabel('% of addresses (largest first)'); ax.set_ylabel('% of bottles'); ax.tick_params(length=0)
save(fig, '04_concentration_curve')

# 5. cohort heatmap (complete months through Sep 2026)
act_m = d.groupby('address_id').m.apply(set); fc = d.groupby('address_id').Date.min().dt.to_period('M')
cohorts = [c for c in sorted(fc.unique()) if c >= pd.Period('2025-08') and c <= pd.Period('2026-08')]
M = np.full((len(cohorts), 12), np.nan)
for i, c in enumerate(cohorts):
    ids = fc[fc == c].index
    for k in range(1, 13):
        if c + k <= pd.Period('2026-09'): M[i, k-1] = 100*sum((c+k) in act_m[j] for j in ids)/len(ids)
fig, ax = plt.subplots(figsize=(11, 6.8)); fig.subplots_adjust(top=.83, left=.14, right=.97, bottom=.14)
title(fig, 'Retention drops after the first month, then levels off', '% of each monthly cohort with a delivery in the n-th calendar month after the first order (complete months only)')
cm = LinearSegmentedColormap.from_list('b', ['#eef4fc', '#2a78d6', '#0f3a73'])
ax.imshow(np.ma.masked_invalid(M), cmap=cm, vmin=0, vmax=40, aspect='auto'); ax.grid(False)
for i in range(M.shape[0]):
    for k in range(12):
        if not np.isnan(M[i, k]): ax.text(k, i, f'{M[i,k]:.0f}', ha='center', va='center', fontsize=9, color='#fff' if M[i, k] > 22 else INK)
ax.set_xticks(range(12)); ax.set_xticklabels([f'+{k}' for k in range(1, 13)]); ax.set_xlabel('Months after first order')
ax.set_yticks(range(len(cohorts))); ax.set_yticklabels([f'{c.strftime("%b %Y")}  (n={(fc==c).sum()})' for c in cohorts]); ax.tick_params(length=0)
for sp in ax.spines.values(): sp.set_visible(False)
fig.text(.14, .025, 'Aug 2025 cohort includes customers who ordered before the data starts.', fontsize=9, color=INK2)
save(fig, '05_cohort_retention')

# 6. weekday workload
dd = d.groupby('Date').size().rename('o').to_frame(); dd['wd'] = dd.index.dayofweek
w = dd.groupby('wd').o.mean(); days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
fig, ax = plt.subplots(figsize=(10, 5.6)); fig.subplots_adjust(top=.80, left=.07, right=.97, bottom=.11)
title(fig, 'Mondays are the busiest delivery day', 'Average delivered orders per delivery day, by weekday')
cols = [ORANGE if i == 0 else BLUE for i in range(7)]; bars = ax.bar(days, w.values, color=cols, width=.62)
for r, v, n in zip(bars, w.values, dd.groupby('wd').size()):
    ax.text(r.get_x()+r.get_width()/2, v+.6, f'{v:.1f}', ha='center', fontsize=10.5, color=INK)
    ax.text(r.get_x()+r.get_width()/2, -2.6, f'{n} days', ha='center', fontsize=8.5, color=INK2)
ax.set_ylim(0, 29); ax.set_yticks([]); ax.grid(False); ax.spines['left'].set_visible(False); ax.tick_params(length=0)
ax.text(6, 9, 'Only 5 Sundays\nwith deliveries', ha='center', fontsize=9, color=INK2)
save(fig, '06_workload_by_weekday')

# 7. repeat intervals
d = d.sort_values(['address_id', 'Date']); iv = (d.Date - d.groupby('address_id').Date.shift()).dt.days.dropna()
g = pd.cut(iv, [-1, 7, 14, 30, 60, 1e5], labels=['0–7', '8–14', '15–30', '31–60', '60+']).value_counts().sort_index(); p = 100*g/g.sum()
fig, ax = plt.subplots(figsize=(10, 5.6)); fig.subplots_adjust(top=.80, left=.07, right=.97, bottom=.12)
title(fig, 'Repeat customers reorder fast: median gap is 12 days', f'Days between consecutive delivered orders of the same address ({len(iv):,} intervals). Beyond 60 days only {p.iloc[-1]:.1f}%')
bars = ax.bar(p.index.astype(str), p.values, color=[BLUE]*4+[ORANGE], width=.62)
for r, v in zip(bars, p.values): ax.text(r.get_x()+r.get_width()/2, v+.6, f'{v:.1f}%', ha='center', fontsize=10.5)
ax.set_ylim(0, 36); ax.set_yticks([]); ax.grid(False); ax.spines['left'].set_visible(False); ax.tick_params(length=0); ax.set_xlabel('Days between orders')
save(fig, '07_repeat_order_intervals')
print('ok')
