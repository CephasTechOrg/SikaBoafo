/* screens-reports.jsx — business insights dashboard + empty states */

const EmptyState = ({ icon, title, sub, minH = 120 }) => (
  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', gap: 8, minHeight: minH, padding: '20px 12px' }}>
    <div style={{ width: 46, height: 46, borderRadius: 14, background: 'var(--bg)', border: '1px solid var(--line)', color: 'var(--ink-3)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name={icon} size={22} /></div>
    <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--ink)' }}>{title}</div>
    <div style={{ fontSize: 12.5, color: 'var(--ink-2)', maxWidth: 220 }}>{sub}</div>
  </div>
);

const SectionTitle = ({ title, pill }) => (
  <div className="sec-head" style={{ marginBottom: 12 }}>
    <h2 className="sec-title">{title}</h2>
    {pill && <span className="badge badge--green">{pill}</span>}
  </div>
);

const KpiCard = ({ icon, label, value, delta, tone, down }) => {
  const tint = tone === 'warn' ? 'var(--warn-tint)' : tone === 'neutral' ? '#F1F3F5' : 'var(--green-tint)';
  const fg = tone === 'warn' ? 'var(--warn)' : tone === 'neutral' ? 'var(--ink-2)' : 'var(--green-700)';
  return (
    <div className="card" style={{ padding: 14 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ width: 34, height: 34, borderRadius: 10, background: tint, color: fg, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name={icon} size={18} /></div>
        {delta && <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3, fontSize: 11.5, fontWeight: 700, color: down ? 'var(--ink-3)' : 'var(--ok)' }}><Icon name="trend" size={12} />{delta}</span>}
      </div>
      <div className="tnum" style={{ fontSize: 20, fontWeight: 800, color: 'var(--ink)', letterSpacing: '-0.01em', marginTop: 11 }}>{value}</div>
      <div style={{ fontSize: 12.5, color: 'var(--ink-2)', fontWeight: 500, marginTop: 2 }}>{label}</div>
    </div>
  );
};

const EXP_COLOR = '#C66A57';   /* soft, controlled — expenses */
const PROFIT_COLOR = '#BE8A2C'; /* muted gold — profit */

const Reports = ({ onNav, empty }) => {
  const [period, setPeriod] = React.useState('This Month');
  const r = REPORTS[period];
  const t = TREND[period];
  const catTotal = EXPENSE_CATS.reduce((s, c) => s + c.amount, 0);
  const payTotal = PAYMENT_METHODS.reduce((s, m) => s + m.amount, 0);
  const maxAging = Math.max(1, ...DEBT_AGING.map(d => d.amount));
  const recv = topReceivables();

  return (
    <Screen nav={<BottomNav active="more" onNav={onNav} />}
      hero={
        <TitleHero title="Reports" subtitle="Business insights" onBack={() => onNav('more')} right={<HeaderIconBtn icon="refresh" />} />
      }>
      <Segmented tabs={['Today', 'This Week', 'This Month']} value={period} onChange={setPeriod} />

      {/* KPI grid */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 11, marginTop: 16 }}>
        <KpiCard icon="trend"   label="Sales"          value={empty ? '₵0.00' : money(r.sales)}    delta={empty ? null : r.dS} tone="green" />
        <KpiCard icon="expense" label="Expenses"       value={empty ? '₵0.00' : money(r.expenses)} delta={empty ? null : r.dE} tone="warn" down />
        <KpiCard icon="coins"   label="Est. Profit"    value={empty ? '₵0.00' : money(r.profit)}   delta={empty ? null : r.dS} tone="green" />
        <KpiCard icon="wallet"  label="Receivables"    value={money(r.recv)} delta={empty ? null : (recv.length + ' owing')} tone="neutral" down />
      </div>

      {/* Sales vs Expenses trend */}
      <div className="card" style={{ padding: 16, marginTop: 16 }}>
        <SectionTitle title="Sales vs Expenses" pill={period} />
        {empty ? <EmptyState icon="trend" title="No sales data yet" sub="Record your first sale to see trends here." minH={150} /> : (
          <>
            <LineChart labels={t.labels} series={[
              { name: 'Sales', color: 'var(--green-700)', data: t.sales, area: true },
              { name: 'Expenses', color: EXP_COLOR, data: t.expenses },
            ]} />
            <ChartXAxis labels={t.labels} />
            <Legend items={[{ name: 'Sales', color: 'var(--green-700)' }, { name: 'Expenses', color: EXP_COLOR }]} />
          </>
        )}
      </div>

      {/* Expenses by category */}
      <div className="card" style={{ padding: 16, marginTop: 14 }}>
        <SectionTitle title="Expenses by Category" />
        {empty ? <EmptyState icon="expense" title="No expenses recorded" sub="Log expenses to see your category breakdown." /> : (
          <div style={{ display: 'flex', alignItems: 'center', gap: 18 }}>
            <Donut segments={EXPENSE_CATS.map(c => ({ value: c.amount, color: c.color }))} size={124} thickness={19}
              center={<><div style={{ fontSize: 10.5, color: 'var(--ink-3)', fontWeight: 700, letterSpacing: '.05em' }}>TOTAL</div><div className="tnum" style={{ fontSize: 16, fontWeight: 800, color: 'var(--ink)' }}>{money(catTotal)}</div></>} />
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 9 }}>
              {EXPENSE_CATS.map(c => (
                <div key={c.name} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span style={{ width: 9, height: 9, borderRadius: '50%', background: c.color, flex: '0 0 auto' }} />
                  <span style={{ flex: 1, fontSize: 13, color: 'var(--ink-2)', fontWeight: 600 }}>{c.name}</span>
                  <span className="tnum" style={{ fontSize: 13, fontWeight: 700, color: 'var(--ink)' }}>{money(c.amount)}</span>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Payment method performance */}
      <div className="card" style={{ padding: 16, marginTop: 14 }}>
        <SectionTitle title="Payment Methods" />
        {empty ? <EmptyState icon="wallet" title="No payments yet" sub="Completed sales will appear here by method." /> : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            {PAYMENT_METHODS.map((m, i) => {
              const pct = Math.round((m.amount / payTotal) * 100);
              const color = i === 0 ? 'var(--green-600)' : 'var(--info)';
              return (
                <div key={m.name}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 11, marginBottom: 9 }}>
                    <div style={{ width: 34, height: 34, borderRadius: 10, background: i === 0 ? 'var(--green-tint)' : 'var(--info-tint)', color, display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' }}><Icon name={m.icon} size={18} /></div>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--ink)' }}>{m.name}</div>
                      <div style={{ fontSize: 12, color: 'var(--ink-3)', fontWeight: 600 }}>{m.count} sales</div>
                    </div>
                    <div style={{ textAlign: 'right' }}>
                      <div className="tnum" style={{ fontSize: 14.5, fontWeight: 800, color: 'var(--ink)' }}>{money(m.amount)}</div>
                      <div className="tnum" style={{ fontSize: 12, color: color, fontWeight: 700 }}>{pct}%</div>
                    </div>
                  </div>
                  <TrackBar pct={pct} color={color} />
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Top selling items */}
      <div style={{ marginTop: 24 }}>
        <SectionTitle title="Top Selling Items" pill="By revenue" />
        {empty ? <div className="card"><EmptyState icon="inventory" title="No sales yet" sub="Your best sellers will rank here." /></div> : (
          <div className="card" style={{ padding: '4px 6px' }}>
            {TOP_SELLING.map((it, i) => (
              <div className="row" key={it.p.id}>
                <div style={{ width: 30, height: 30, borderRadius: 9, flex: '0 0 auto', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 13, fontWeight: 800, background: i === 0 ? 'var(--green-tint)' : '#F1F3F5', color: i === 0 ? 'var(--green-700)' : 'var(--ink-2)' }}>{i + 1}</div>
                <Thumb src={it.p.img} size={40} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--ink)' }}>{it.p.name}</div>
                  <div style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 1 }}>{it.units} units sold</div>
                </div>
                <div className="tnum" style={{ fontSize: 14.5, fontWeight: 800, color: 'var(--ink)' }}>{money(it.revenue)}</div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Top customers / receivables */}
      <div style={{ marginTop: 24 }}>
        <SectionTitle title="Top Receivables" pill="By balance" />
        <div className="card" style={{ padding: (empty || !recv.length) ? 0 : '4px 6px' }}>
          {(empty || !recv.length)
            ? <EmptyState icon="check" title="No open debts" sub="Every customer is fully settled. Nice work." />
            : recv.slice(0, 3).map(c => (
              <div className="row" key={c.id}>
                <Avatar init={c.init} size={40} bg="var(--warn-tint)" fg="var(--warn)" />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--ink)' }}>{c.name}</div>
                  <div style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 1 }}>{c.phone}</div>
                </div>
                <div className="tnum" style={{ fontSize: 14.5, fontWeight: 800, color: 'var(--warn)' }}>{money(c.debt)}</div>
              </div>
            ))}
        </div>
      </div>

      {/* Debt aging */}
      <div style={{ marginTop: 24 }}>
        <SectionTitle title="Debt Aging" pill="Receivables" />
        <div className="card" style={{ padding: 16 }}>
          {empty ? <EmptyState icon="clock" title="No open debts" sub="Aging breakdown appears when debts exist." /> : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 15 }}>
              {DEBT_AGING.map(d => {
                const tone = d.tone;
                const color = tone === 'danger' ? 'var(--danger)' : tone === 'warn' ? 'var(--warn)' : tone === 'ok' ? 'var(--ok)' : 'var(--ink-3)';
                const tint = tone === 'danger' ? 'var(--danger-tint)' : tone === 'warn' ? 'var(--warn-tint)' : tone === 'ok' ? 'var(--ok-tint)' : '#F1F3F5';
                return (
                  <div key={d.label} style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    <span style={{ width: 108, flex: '0 0 auto', fontSize: 13, color: 'var(--ink-2)', fontWeight: 600 }}>{d.label}</span>
                    <div style={{ flex: 1 }}><TrackBar pct={(d.amount / maxAging) * 100} color={color} /></div>
                    <span style={{ minWidth: 26, height: 26, padding: '0 7px', borderRadius: 8, background: tint, color, fontSize: 12.5, fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' }}>{d.count}</span>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
      <div style={{ height: 8 }} />
    </Screen>
  );
};

Object.assign(window, { Reports, EmptyState });
