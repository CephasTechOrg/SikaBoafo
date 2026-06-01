/* screens-more.jsx — More + Customers + Debts */

/* ---------------- MORE ---------------- */
const MoreRow = ({ icon, title, sub, onClick, danger }) => (
  <button onClick={onClick} className="card" style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 14, padding: 15, cursor: 'pointer', textAlign: 'left', border: '1px solid var(--line-soft)' }}>
    <div style={{ width: 46, height: 46, borderRadius: 13, flex: '0 0 auto', display: 'flex', alignItems: 'center', justifyContent: 'center',
      background: danger ? 'var(--danger-tint)' : 'var(--green-tint)', color: danger ? 'var(--danger)' : 'var(--green-700)' }}>
      <Icon name={icon} size={22} />
    </div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 16, fontWeight: 700, color: 'var(--ink)' }}>{title}</div>
      <div style={{ fontSize: 13, color: 'var(--ink-2)', marginTop: 2 }}>{sub}</div>
    </div>
    <Icon name="chevron" size={20} color="var(--ink-3)" />
  </button>
);

const More = ({ onNav }) => (
  <div className="screen">
    <div className="screen__scroll" style={{ background: 'var(--bg)' }}>
      <StatusBar dark={false} />
      <div style={{ padding: '14px var(--gutter) 0' }}>
        <h1 style={{ margin: 0, fontSize: 32, fontWeight: 800, color: 'var(--ink)', letterSpacing: '-0.02em' }}>More</h1>
        <div style={{ fontSize: 14.5, color: 'var(--ink-2)', marginTop: 4 }}>Manage your business operations and settings</div>
      </div>

      <div style={{ padding: '24px var(--gutter) 24px' }}>
        {/* business card */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 14, background: 'linear-gradient(135deg,#0F7A4A,#073B2A)', borderRadius: 'var(--r-card)', padding: '16px 18px', marginBottom: 26, boxShadow: '0 10px 24px rgba(11,74,46,.22)' }}>
          <Avatar init="CV" size={48} bg="rgba(255,255,255,.16)" ring="rgba(255,255,255,.25)" />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 17, fontWeight: 700, color: '#fff' }}>Cephas Ventures</div>
            <div style={{ fontSize: 13, color: 'rgba(255,255,255,.7)', marginTop: 2 }}>Accra · Owner account</div>
          </div>
          <div style={{ width: 34, height: 34, borderRadius: 11, background: 'rgba(255,255,255,.14)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="edit" size={18} /></div>
        </div>

        <div className="sec-label" style={{ marginBottom: 12 }}>Operations</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 11 }}>
          <MoreRow icon="expense" title="Expenses" sub="Track costs and daily spending" onClick={() => onNav('expenses')} />
          <MoreRow icon="debt" title="Debts" sub="Manage receivables and repayments" onClick={() => onNav('debts')} />
          <MoreRow icon="users" title="Customers" sub="Client directory and history" onClick={() => onNav('customers')} />
        </div>

        <div className="sec-label" style={{ margin: '26px 0 12px' }}>Business Management</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 11 }}>
          <MoreRow icon="report" title="Reports" sub="Deep insights into performance" onClick={() => onNav('reports')} />
          <MoreRow icon="settings" title="Settings" sub="Profile, staff, and preferences" onClick={() => onNav('settings')} />
        </div>
      </div>
    </div>
    <BottomNav active="more" onNav={onNav} />
  </div>
);

/* ---------------- CUSTOMERS ---------------- */
const TAG_CLASS = { Owing: 'badge--warn', Regular: 'badge--ok', Active: 'badge--neutral' };

const Customers = ({ onNav, onOpen }) => {
  const owing = CUSTOMERS.filter(c => c.debt > 0).length;
  const active = CUSTOMERS.filter(c => !/week|month/.test(c.last)).length;
  return (
    <Screen nav={<BottomNav active="customers" onNav={onNav} />}
      hero={
        <TitleHero title="Customers" subtitle="Client directory & balances"
          onBack={() => onNav('more')}
          right={<HeaderIconBtn icon="userplus" />}>
          <div style={{ display: 'flex', gap: 10, marginTop: 20 }}>
            <HeroStat icon="users" value={CUSTOMERS.length} label="Total" />
            <HeroStat icon="wallet" value={owing} label="Owing" />
            <HeroStat icon="trend" value={active} label="Active" />
          </div>
        </TitleHero>
      }>
      <div className="search">
        <Icon name="search" size={19} color="var(--ink-3)" />
        <input placeholder="Search customers by name or phone" />
      </div>

      <div className="sec-head" style={{ marginTop: 20, marginBottom: 12 }}>
        <span className="sec-label">All Customers</span>
        <span style={{ fontSize: 12.5, color: 'var(--ink-3)', fontWeight: 600 }}>{CUSTOMERS.length}</span>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 11 }}>
        {CUSTOMERS.map(c => (
          <button className="card" key={c.id} onClick={() => onOpen && onOpen(c)} style={{ width: '100%', padding: 15, cursor: 'pointer', textAlign: 'left', border: '1px solid var(--line-soft)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 13 }}>
              <Avatar init={c.init} size={46} bg="var(--green-tint)" fg="var(--green-700)" />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 15.5, fontWeight: 700, color: 'var(--ink)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{c.name}</div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, color: 'var(--ink-2)', marginTop: 4 }}>
                  <Icon name="phone" size={14} color="var(--ink-3)" />{c.phone}
                </div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, flex: '0 0 auto' }}>
                {c.debt > 0
                  ? <div style={{ textAlign: 'right' }}>
                      <div className="tnum" style={{ fontSize: 15.5, fontWeight: 800, color: 'var(--warn)' }}>{money(c.debt)}</div>
                      <div style={{ fontSize: 11, color: 'var(--ink-3)', fontWeight: 600, marginTop: 1 }}>owing</div>
                    </div>
                  : <span className={'badge ' + TAG_CLASS[c.tag]}>{c.tag}</span>}
                <Icon name="chevron" size={18} color="var(--ink-3)" />
              </div>
            </div>
            <div style={{ display: 'flex', gap: 8, marginTop: 13, paddingTop: 13, borderTop: '1px solid var(--line-soft)' }}>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 11.5, color: 'var(--ink-3)', fontWeight: 600 }}>Total purchases</div>
                <div className="tnum" style={{ fontSize: 14.5, fontWeight: 800, color: 'var(--ink)', marginTop: 3 }}>{money(c.purchases)}</div>
              </div>
              <div style={{ width: 1, background: 'var(--line-soft)' }} />
              <div style={{ flex: 1, paddingLeft: 4 }}>
                <div style={{ fontSize: 11.5, color: 'var(--ink-3)', fontWeight: 600 }}>Last activity</div>
                <div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--ink)', marginTop: 3 }}>{c.last}</div>
              </div>
            </div>
          </button>
        ))}
      </div>
      <div style={{ height: 8 }} />
    </Screen>
  );
};

/* ---------------- DEBTS ---------------- */
const DEBT_FILTERS = ['All', 'Unpaid', 'Paid', 'Overdue'];
const DEBT_BADGE = { Unpaid: 'badge--neutral', Partial: 'badge--warn', Overdue: 'badge--danger', Paid: 'badge--ok' };
const debtTint = (s) => s === 'Overdue' ? 'var(--danger-tint)' : s === 'Paid' ? 'var(--ok-tint)' : s === 'Partial' ? 'var(--warn-tint)' : '#F1F3F5';
const debtFg = (s) => s === 'Overdue' ? 'var(--danger)' : s === 'Paid' ? 'var(--ok)' : s === 'Partial' ? 'var(--warn)' : 'var(--ink-2)';

const Debts = ({ onNav, onPay }) => {
  const [filter, setFilter] = React.useState('All');
  const list = DEBTS.filter(d => {
    if (filter === 'All') return true;
    if (filter === 'Unpaid') return d.status === 'Unpaid' || d.status === 'Overdue';
    return d.status === filter;
  });
  const totalOutstanding = DEBTS.filter(d => d.status !== 'Paid').reduce((s, d) => s + d.amt, 0);
  const owing = DEBTS.filter(d => d.status !== 'Paid').length;
  const overdue = DEBTS.filter(d => d.status === 'Overdue').length;
  const collected = REPAYMENTS.reduce((s, r) => s + r.amt, 0);

  return (
    <Screen nav={<BottomNav active="debts" onNav={onNav} />}
      hero={
        <TitleHero title="Debts" subtitle="Receivables · updated 19h ago"
          onBack={() => onNav('more')}
          right={<><HeaderIconBtn icon="userplus" /><HeaderIconBtn icon="refresh" /></>}>
          <div style={{ marginTop: 18 }}>
            <div className="sec-label" style={{ color: 'rgba(255,255,255,.6)' }}>Total Outstanding</div>
            <div className="tnum" style={{ fontSize: 40, fontWeight: 800, color: '#fff', letterSpacing: '-0.03em', marginTop: 3 }}>{money(totalOutstanding)}</div>
          </div>
          <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
            <HeroStat icon="users" value={owing} label="Owing" />
            <HeroStat icon="lowstock" value={overdue} label="Overdue" />
            <HeroStat icon="trend" value={'₵' + collected} label="Collected" />
          </div>
        </TitleHero>
      }>
      <div className="chiprow">
        {DEBT_FILTERS.map(f => (
          <div key={f} className="chip" data-on={filter === f} onClick={() => setFilter(f)}>{f}</div>
        ))}
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 11, marginTop: 18 }}>
        {list.map(d => (
          <div className="card" key={d.id} style={{ padding: 15 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 13 }}>
              <Avatar init={d.init} size={46} bg={debtTint(d.status)} fg={debtFg(d.status)} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 15.5, fontWeight: 700, color: 'var(--ink)' }}>{d.name}</div>
                <div className="tnum" style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 3 }}>{d.inv}</div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div className="tnum" style={{ fontSize: 17, fontWeight: 800, color: d.status === 'Paid' ? 'var(--ink-3)' : 'var(--ink)' }}>{money(d.amt)}</div>
                <span className={'badge ' + DEBT_BADGE[d.status]} style={{ marginTop: 6 }}>{d.status}</span>
              </div>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 13, paddingTop: 13, borderTop: '1px solid var(--line-soft)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12.5, color: d.status === 'Overdue' ? 'var(--danger)' : 'var(--ink-2)', fontWeight: 600 }}>
                <Icon name="clock" size={15} />Due {d.due}
              </div>
              {d.status === 'Paid'
                ? <button className="btn btn--ghost btn--sm">View details</button>
                : <button className="btn btn--primary btn--sm" onClick={() => onPay && onPay(d)}><Icon name="grid" size={16} /> Collect via QR</button>}
            </div>
          </div>
        ))}
      </div>

      {/* recent repayments */}
      <div className="sec-head" style={{ marginTop: 26, marginBottom: 12 }}>
        <h2 className="sec-title">Recent Repayments</h2>
      </div>
      <div className="card" style={{ padding: '4px 6px' }}>
        {REPAYMENTS.map(r => (
          <div className="row" key={r.id}>
            <Avatar init={r.init} size={40} bg="var(--ok-tint)" fg="var(--ok)" />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--ink)' }}>{r.name}</div>
              <div style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 2 }}>{r.when}</div>
            </div>
            <div className="tnum" style={{ fontSize: 15, fontWeight: 800, color: 'var(--ok)' }}>+{money(r.amt)}</div>
          </div>
        ))}
      </div>
      <div style={{ height: 8 }} />
    </Screen>
  );
};

Object.assign(window, { More, Customers, Debts });
