/* screens-detail.jsx — Customer/Debt Detail + Settings (pushed sub-screens) */

/* native-style switch */
const Toggle = ({ on }) => (
  <div style={{ width: 48, height: 28, borderRadius: 999, background: on ? 'var(--green-600)' : '#D7DCDA', position: 'relative', transition: '.2s', flex: '0 0 auto' }}>
    <div style={{ position: 'absolute', top: 3, left: on ? 23 : 3, width: 22, height: 22, borderRadius: '50%', background: '#fff', boxShadow: '0 1px 3px rgba(0,0,0,.25)', transition: 'left .2s' }} />
  </div>
);

/* ---------------- CUSTOMER / DEBT DETAIL ---------------- */
const HISTORY_BADGE = { Partial: 'badge--warn', Settled: 'badge--ok', Overdue: 'badge--danger' };

const CustomerDetail = ({ onBack, customer }) => {
  const c = customer || CUSTOMERS[0];
  const history = [
    { inv: 'INV-2026-0026', date: '20 Jun 2026', amt: 300, status: 'Partial' },
    { inv: 'INV-2026-0025', date: '11 Jun 2026', amt: 0,   status: 'Settled' },
    { inv: 'INV-2026-0024', date: '27 May 2026', amt: 0,   status: 'Settled' },
  ];
  return (
    <div className="screen">
      <div className="screen__scroll">
        <Hero glow>
          <StatusBar dark />
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 4 }}>
            <button onClick={onBack} style={{ display: 'flex', alignItems: 'center', gap: 4, marginLeft: -6, background: 'none', border: 'none', color: 'rgba(255,255,255,.85)', cursor: 'pointer', padding: '6px 6px' }}>
              <Icon name="back" size={20} /><span style={{ fontSize: 14.5, fontWeight: 600 }}>Customers</span>
            </button>
            <HeaderIconBtn icon="refresh" />
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginTop: 14, marginBottom: 4 }}>
            <div className="avatar" style={{ width: 58, height: 58, borderRadius: 18, background: 'rgba(255,255,255,.14)', border: '1.5px solid rgba(255,255,255,.22)', color: '#fff', fontSize: 22, fontWeight: 800 }}>{c.init}</div>
            <div>
              <div style={{ fontSize: 23, fontWeight: 800, color: '#fff', letterSpacing: '-0.02em' }}>{c.name}</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13.5, color: 'rgba(255,255,255,.72)', marginTop: 3 }}>
                <Icon name="phone" size={14} />{c.phone}
              </div>
            </div>
          </div>
        </Hero>

        <div className="sheet">
          {/* outstanding summary */}
          <div className="card" style={{ padding: 18 }}>
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
              <div>
                <div className="sec-label">Total Outstanding</div>
                <div className="tnum" style={{ fontSize: 33, fontWeight: 800, color: 'var(--ink)', letterSpacing: '-0.02em', marginTop: 4 }}>{money(c.debt)}</div>
              </div>
              <span className="badge badge--warn badge--dot" style={{ height: 27, padding: '0 11px', borderRadius: 9 }}>Active balance</span>
            </div>
            <div style={{ display: 'flex', gap: 11, marginTop: 16 }}>
              <div style={{ flex: 1, border: '1px solid var(--line-soft)', borderRadius: 14, padding: '13px 14px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 7, color: 'var(--ink-2)', marginBottom: 7 }}>
                  <Icon name="receipt" size={16} /><span style={{ fontSize: 11.5, fontWeight: 700, letterSpacing: '.06em', textTransform: 'uppercase' }}>Open Debts</span>
                </div>
                <div className="tnum" style={{ fontSize: 22, fontWeight: 800, color: 'var(--ink)' }}>1</div>
              </div>
              <div style={{ flex: 1, border: '1px solid var(--line-soft)', borderRadius: 14, padding: '13px 14px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 7, color: 'var(--ink-2)', marginBottom: 7 }}>
                  <Icon name="clock" size={16} /><span style={{ fontSize: 11.5, fontWeight: 700, letterSpacing: '.06em', textTransform: 'uppercase' }}>All Time</span>
                </div>
                <div className="tnum" style={{ fontSize: 22, fontWeight: 800, color: 'var(--ink)' }}>3</div>
              </div>
            </div>
          </div>

          {/* call / message */}
          <div style={{ display: 'flex', gap: 11, marginTop: 14 }}>
            <button className="btn btn--primary" style={{ flex: 1, height: 48 }}><Icon name="phone" size={18} /> Call</button>
            <button className="btn btn--ghost" style={{ flex: 1, height: 48 }}><Icon name="message" size={18} /> Message</button>
          </div>

          {/* debt history */}
          <div className="sec-head" style={{ marginTop: 24, marginBottom: 12 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <Icon name="history" size={18} color="var(--green-700)" />
              <h2 className="sec-title">Debt history</h2>
            </div>
            <span style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--ink-2)', background: '#F1F3F5', padding: '2px 10px', borderRadius: 999 }}>{history.length}</span>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {history.map(h => (
              <button key={h.inv} className="card" style={{ width: '100%', padding: 14, display: 'flex', alignItems: 'center', gap: 13, cursor: 'pointer', textAlign: 'left', border: '1px solid var(--line-soft)' }}>
                <div className="avatar" style={{ width: 44, height: 44, borderRadius: 13, fontSize: 16, fontWeight: 800,
                  background: h.status === 'Partial' ? 'var(--warn-tint)' : '#F1F3F5',
                  color: h.status === 'Partial' ? 'var(--warn)' : 'var(--ink-2)' }}>{c.init}</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div className="tnum" style={{ fontSize: 14, fontWeight: 700, color: 'var(--ink)' }}>{h.inv}</div>
                  <div style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 2 }}>{h.date}</div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div className="tnum" style={{ fontSize: 15.5, fontWeight: 800, color: h.amt > 0 ? 'var(--ink)' : 'var(--ink-3)' }}>{money(h.amt)}</div>
                  <span className={'badge ' + HISTORY_BADGE[h.status]} style={{ marginTop: 5 }}>{h.status}</span>
                </div>
                <Icon name="chevron" size={18} color="var(--ink-3)" />
              </button>
            ))}
          </div>
          <div style={{ height: 84 }} />
        </div>
      </div>

      <div style={{ flex: '0 0 auto', background: 'var(--card)', borderTop: '1px solid var(--line)', padding: '12px 16px', boxShadow: '0 -6px 20px rgba(16,24,40,.05)' }}>
        <button className="btn btn--primary" style={{ width: '100%' }}><Icon name="plus" size={20} /> Record new debt</button>
      </div>
    </div>
  );
};

/* ---------------- SETTINGS ---------------- */
const SettingRow = ({ icon, tint, fg, title, sub, toggle, on }) => (
  <button className="card" style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 14, padding: 14, cursor: 'pointer', textAlign: 'left', border: '1px solid var(--line-soft)' }}>
    <div style={{ width: 44, height: 44, borderRadius: 13, flex: '0 0 auto', display: 'flex', alignItems: 'center', justifyContent: 'center', background: tint, color: fg }}>
      <Icon name={icon} size={21} />
    </div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontSize: 15.5, fontWeight: 700, color: 'var(--ink)' }}>{title}</div>
      <div style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 2 }}>{sub}</div>
    </div>
    {toggle ? <Toggle on={on} /> : <Icon name="chevron" size={20} color="var(--ink-3)" />}
  </button>
);

const Settings = ({ onBack }) => (
  <div className="screen">
    <div className="screen__scroll">
      <Hero glow>
        <StatusBar dark />
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 4 }}>
          <button onClick={onBack} style={{ width: 36, height: 36, marginLeft: -6, borderRadius: 12, background: 'rgba(255,255,255,.12)', border: 'none', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <Icon name="back" size={20} />
          </button>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 7, background: 'rgba(255,255,255,.12)', border: '1px solid rgba(255,255,255,.14)', borderRadius: 999, padding: '6px 13px', fontSize: 12.5, fontWeight: 600, color: '#fff' }}>
            <Icon name="sliders" size={15} /> Account &amp; device
          </span>
        </div>
        <div style={{ marginTop: 16, marginBottom: 6 }}>
          <h1 style={{ margin: 0, fontSize: 28, fontWeight: 800, color: '#fff', letterSpacing: '-0.02em' }}>Settings</h1>
          <div style={{ fontSize: 14, color: 'rgba(255,255,255,.72)', fontWeight: 500, marginTop: 4 }}>Cephas Ventures</div>
        </div>
      </Hero>

      <div className="sheet sheet--white">
        <div className="sec-label" style={{ marginBottom: 12 }}>Business</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <SettingRow icon="building" tint="#EAF1FB" fg="#2563A8" title="Business Profile" sub="Edit name, type and store details" />
          <SettingRow icon="users" tint="var(--green-tint)" fg="var(--green-700)" title="Staff & Team" sub="Invite teammates and manage access" />
          <SettingRow icon="card" tint="var(--warn-tint)" fg="var(--warn)" title="Paystack Payments" sub="Connect your Paystack account" />
          <SettingRow icon="history" tint="#F1F3F5" fg="var(--ink-2)" title="Activity" sub="Review owner audit trail" />
        </div>

        <div className="sec-label" style={{ margin: '24px 0 12px' }}>Notifications</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <SettingRow icon="sync" tint="#EAF1FB" fg="#2563A8" title="Sync status" sub="Offline and syncing updates" toggle on />
          <SettingRow icon="bell2" tint="var(--warn-tint)" fg="var(--warn)" title="Debt reminders" sub="Notify customers before due dates" toggle on />
          <SettingRow icon="shield" tint="var(--green-tint)" fg="var(--green-700)" title="Low-stock alerts" sub="Warn when items run low" toggle />
        </div>
        <div style={{ height: 16 }} />
      </div>
    </div>
  </div>
);

Object.assign(window, { Toggle, CustomerDetail, Settings });
