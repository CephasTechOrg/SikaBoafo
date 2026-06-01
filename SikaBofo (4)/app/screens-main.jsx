/* screens-main.jsx — Dashboard + Inventory */

/* ---------------- DASHBOARD ---------------- */
const QuickAction = ({ icon, label, primary, onClick }) => (
  <button onClick={onClick} style={{ flex: 1, background: 'none', border: 'none', cursor: 'pointer',
    display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, padding: 0 }}>
    <div style={{ width: 52, height: 52, borderRadius: 17,
      background: primary ? 'var(--green-600)' : 'rgba(255,255,255,.12)',
      border: '1px solid ' + (primary ? 'transparent' : 'rgba(255,255,255,.14)'),
      boxShadow: primary ? '0 8px 18px rgba(22,138,85,.45)' : 'none',
      display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
      <Icon name={icon} size={23} />
    </div>
    <span style={{ fontSize: 12.5, fontWeight: 600, color: 'rgba(255,255,255,.92)' }}>{label}</span>
  </button>
);

const SummarySmall = ({ icon, value, label, tone }) => {
  const c = tone === 'warn' ? 'var(--warn)' : tone === 'danger' ? 'var(--danger)' : 'var(--green-700)';
  const bg = tone === 'warn' ? 'var(--warn-tint)' : tone === 'danger' ? 'var(--danger-tint)' : 'var(--green-tint)';
  return (
    <div className="card" style={{ flex: 1, padding: '15px 15px 14px' }}>
      <div style={{ width: 36, height: 36, borderRadius: 11, background: bg, color: c, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 11 }}>
        <Icon name={icon} size={19} />
      </div>
      <div className="tnum" style={{ fontSize: 21, fontWeight: 800, color: 'var(--ink)', letterSpacing: '-0.01em' }}>{value}</div>
      <div style={{ fontSize: 12.5, color: 'var(--ink-2)', fontWeight: 500, marginTop: 2 }}>{label}</div>
    </div>
  );
};

const Dashboard = ({ onNav, openSale }) => (
  <Screen nav={<BottomNav active="dashboard" onNav={onNav} />}
    hero={
      <Hero tall map>
        <StatusBar dark />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 6 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <Avatar init="CV" size={44} ring="rgba(255,255,255,.25)" />
            <div>
              <div style={{ fontSize: 13, color: 'rgba(255,255,255,.66)', fontWeight: 500 }}>Good evening</div>
              <div style={{ fontSize: 17.5, color: '#fff', fontWeight: 700, letterSpacing: '-0.01em' }}>Cephas Ventures</div>
            </div>
          </div>
          <HeaderIconBtn icon="bell" badge={6} onClick={() => onNav('notifications')} />
        </div>

        <div style={{ marginTop: 26 }}>
          <div className="sec-label" style={{ color: 'rgba(255,255,255,.6)' }}>Sales Today</div>
          <div className="tnum" style={{ fontSize: 46, fontWeight: 800, color: '#fff', letterSpacing: '-0.03em', marginTop: 4, lineHeight: 1 }}>₵80.00</div>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, marginTop: 11, background: 'rgba(255,255,255,.12)', padding: '5px 11px', borderRadius: 999 }}>
            <Icon name="trend" size={15} color="#7CE0B0" />
            <span style={{ fontSize: 12.5, fontWeight: 600, color: '#CFEFDD' }}>+12% vs yesterday · 8 sales</span>
          </div>
        </div>

        <div style={{ display: 'flex', gap: 6, marginTop: 26 }}>
          <QuickAction icon="plus"     label="New Sale" primary onClick={() => onNav('sales')} />
          <QuickAction icon="debt"     label="Debts"    onClick={() => onNav('debts')} />
          <QuickAction icon="restock"  label="Restock"  onClick={() => onNav('inventory')} />
          <QuickAction icon="expense"  label="Expenses" onClick={() => onNav('more')} />
        </div>
      </Hero>
    }>
    {/* est profit feature card */}
    <div style={{ borderRadius: 'var(--r-card)', padding: '18px 20px', position: 'relative', overflow: 'hidden',
      background: 'linear-gradient(135deg, #0F7A4A 0%, #0A5D38 100%)', boxShadow: '0 10px 24px rgba(11,74,46,.28)' }}>
      <div style={{ position: 'absolute', right: -10, bottom: -16, opacity: .9 }}>
        <Icon name="coins" size={108} color="rgba(255,255,255,.14)" />
      </div>
      <div className="sec-label" style={{ color: 'rgba(255,255,255,.7)' }}>Today's Est. Profit</div>
      <div className="tnum" style={{ fontSize: 32, fontWeight: 800, color: '#fff', letterSpacing: '-0.02em', marginTop: 4 }}>₵24.00</div>
      <div style={{ height: 6, borderRadius: 3, background: 'rgba(255,255,255,.18)', marginTop: 14, overflow: 'hidden', maxWidth: 230 }}>
        <div style={{ width: '30%', height: '100%', background: '#7CE0B0', borderRadius: 3 }} />
      </div>
      <div style={{ fontSize: 12.5, color: 'rgba(255,255,255,.78)', fontWeight: 600, marginTop: 8 }}>30% margin on today's sales</div>
    </div>

    <div style={{ display: 'flex', gap: 12, marginTop: 12 }}>
      <SummarySmall icon="wallet" value="₵505.00" label="Unpaid Debt" tone="danger" />
      <SummarySmall icon="lowstock" value="2" label="Low Stock" tone="warn" />
    </div>

    {/* top selling */}
    <div className="sec-head" style={{ marginTop: 26, marginBottom: 12 }}>
      <h2 className="sec-title">Top Selling Products</h2>
      <span className="link" onClick={() => onNav('inventory')}>See all</span>
    </div>
    <div className="card" style={{ padding: '4px 6px' }}>
      {TOP_SELLING.map((t, i) => (
        <div className="row" key={t.p.id}>
          <div style={{ position: 'relative' }}>
            <Thumb src={t.p.img} size={48} />
            <span style={{ position: 'absolute', top: -6, left: -6, width: 20, height: 20, borderRadius: 7, background: i === 0 ? 'var(--green-700)' : 'var(--ink)', color: '#fff', fontSize: 11, fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{i + 1}</span>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 15.5, fontWeight: 700, color: 'var(--ink)' }}>{t.p.name}</div>
            <div style={{ fontSize: 13, color: 'var(--ink-2)', marginTop: 2 }}>{t.units} units sold</div>
          </div>
          <div className="tnum" style={{ fontSize: 15.5, fontWeight: 800, color: 'var(--ink)' }}>{money(t.revenue)}</div>
        </div>
      ))}
    </div>

    {/* recent activity */}
    <div className="sec-head" style={{ marginTop: 24, marginBottom: 12 }}>
      <h2 className="sec-title">Recent Activity</h2>
      <span className="link">View all</span>
    </div>
    <div className="card" style={{ padding: '4px 6px' }}>
      {ACTIVITY.map(a => (
        <div className="row" key={a.id}>
          <div style={{ width: 42, height: 42, borderRadius: 12, flex: '0 0 auto', display: 'flex', alignItems: 'center', justifyContent: 'center',
            background: a.dir === 'in' ? 'var(--green-tint)' : '#F1F3F5', color: a.dir === 'in' ? 'var(--green-700)' : 'var(--ink-2)' }}>
            <Icon name={a.title.startsWith('Repayment') ? 'debt' : a.title.startsWith('Restock') ? 'restock' : 'sales'} size={19} />
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--ink)' }}>{a.title}</div>
            <div style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 2 }}>{a.sub} · {a.time}</div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div className="tnum" style={{ fontSize: 14.5, fontWeight: 800, color: a.dir === 'in' ? 'var(--green-700)' : 'var(--ink)' }}>{a.dir === 'in' ? '+' : ''}{money(a.amt)}</div>
            <div style={{ fontSize: 11.5, color: 'var(--ink-3)', fontWeight: 600, marginTop: 1 }}>{a.pay}</div>
          </div>
        </div>
      ))}
    </div>
    <div style={{ height: 8 }} />
  </Screen>
);

/* ---------------- INVENTORY ---------------- */
const INV_CATS = ['All', 'Drinks', 'Milk', 'Grocery', 'Household'];

const Inventory = ({ onNav }) => {
  const [cat, setCat] = React.useState('All');
  const list = PRODUCTS.filter(p => cat === 'All' || p.cat === cat);
  const lowCount = PRODUCTS.filter(p => p.low).length;
  return (
    <Screen nav={<BottomNav active="inventory" onNav={onNav} />}
      fab={<div className="fab"><Icon name="plus" size={26} /></div>}
      hero={
        <TitleHero title="Inventory" subtitle="Updated 19h ago"
          right={<HeaderIconBtn icon="refresh" />}>
          <div style={{ display: 'flex', gap: 12, marginTop: 20 }}>
            <HeroStat icon="box" value={PRODUCTS.length} label="Active items" />
            <HeroStat icon="lowstock" value={lowCount} label="Low stock" />
          </div>
        </TitleHero>
      }>
      <div className="search">
        <Icon name="search" size={19} color="var(--ink-3)" />
        <input placeholder="Search items by name, category or SKU..." />
      </div>

      <div className="chiprow" style={{ marginTop: 16 }}>
        {INV_CATS.map(c => {
          const n = c === 'All' ? PRODUCTS.length : PRODUCTS.filter(p => p.cat === c).length;
          return (
            <div key={c} className="chip" data-on={cat === c} onClick={() => setCat(c)}>
              {c}<span className="chip__count">{n}</span>
            </div>
          );
        })}
      </div>

      <div className="sec-head" style={{ marginTop: 22, marginBottom: 12 }}>
        <span className="sec-label">Active Items</span>
        <span style={{ fontSize: 12.5, color: 'var(--ink-3)', fontWeight: 600 }}>{list.length} of {PRODUCTS.length}</span>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {list.map(p => (
          <div className="card" key={p.id} style={{ padding: 14, display: 'flex', alignItems: 'center', gap: 13 }}>
            <Thumb src={p.img} size={52} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
                <span style={{ fontSize: 15.5, fontWeight: 700, color: 'var(--ink)' }}>{p.name}</span>
                {p.low && <span className="badge badge--warn badge--dot">Low</span>}
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <CatBadge cat={p.cat} />
                <span className="tnum" style={{ fontSize: 12, color: 'var(--ink-3)', fontWeight: 600 }}>{p.sku}</span>
              </div>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 5, minWidth: 70 }}>
              <div className="tnum" style={{ fontSize: 16, fontWeight: 800, color: 'var(--green-700)' }}>{money(p.price)}</div>
              <div className="tnum" style={{ fontSize: 12, fontWeight: 700, padding: '2px 8px', borderRadius: 7, background: p.low ? 'var(--warn-tint)' : '#F1F3F5', color: p.low ? 'var(--warn)' : 'var(--ink-2)' }}>{p.stock} units</div>
            </div>
          </div>
        ))}
      </div>
      <div style={{ height: 96 }} />
    </Screen>
  );
};

Object.assign(window, { Dashboard, Inventory });
