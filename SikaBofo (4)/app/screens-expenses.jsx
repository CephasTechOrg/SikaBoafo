/* screens-expenses.jsx — Expenses: Log expense + History */

const EXP_ICON = { Inventory: 'box', Transport: 'sales', Utilities: 'expense', Rent: 'store', Salary: 'users', Tax: 'building', Other: 'grid' };

const Expenses = ({ onNav }) => {
  const [tab, setTab] = React.useState('Log expense');
  const [cat, setCat] = React.useState('Inventory');
  const [amount, setAmount] = React.useState('');
  const ready = cat && parseFloat(amount) > 0;

  return (
    <Screen
      bottomBar={
        <div style={{ flex: '0 0 auto', background: 'var(--card)', borderTop: '1px solid var(--line)', padding: '11px 16px', display: 'flex', alignItems: 'center', gap: 12, boxShadow: '0 -6px 20px rgba(16,24,40,.05)' }}>
          <div style={{ width: 44, height: 44, borderRadius: 12, background: ready ? 'var(--green-tint)' : '#F1F3F5', color: ready ? 'var(--green-700)' : 'var(--ink-3)', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' }}><Icon name="receipt" size={21} /></div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--ink)' }}>{ready ? `${cat} · ${money(parseFloat(amount))}` : 'Enter amount'}</div>
            <div style={{ fontSize: 12, color: 'var(--ink-2)' }}>{ready ? 'Ready to save this expense' : 'Choose a category and amount'}</div>
          </div>
          <button className={'btn ' + (ready ? 'btn--primary' : 'btn--disabled')} style={{ height: 46, padding: '0 20px' }}><Icon name="check" size={18} /> Save</button>
        </div>
      }
      hero={
        <TitleHero title="Expenses" subtitle="Track daily spending" onBack={() => onNav('more')} right={<HeaderIconBtn icon="refresh" />}>
          <div style={{ marginTop: 16 }}>
            <div className="sec-label" style={{ color: 'rgba(255,255,255,.6)' }}>Spent this month</div>
            <div className="tnum" style={{ fontSize: 38, fontWeight: 800, color: '#fff', letterSpacing: '-0.03em', marginTop: 3 }}>₵1,240.00</div>
          </div>
          <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
            <HeroStat icon="expense" value="₵180" label="Today" />
            <HeroStat icon="receipt" value="4" label="Entries" />
            <HeroStat icon="grid" value="5" label="Categories" />
          </div>
        </TitleHero>
      }>
      <Segmented tabs={['Log expense', 'History']} value={tab} onChange={setTab} />

      {tab === 'Log expense' ? (
        <>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 18 }}>
            <div style={{ width: 38, height: 38, borderRadius: 11, background: 'var(--warn-tint)', color: 'var(--warn)', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' }}><Icon name="report" size={19} /></div>
            <div>
              <div style={{ fontSize: 15.5, fontWeight: 700, color: 'var(--ink)' }}>Record spending</div>
              <div style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 1 }}>Pick a category and enter the amount.</div>
            </div>
          </div>

          {/* category */}
          <div className="sec-label" style={{ margin: '20px 0 10px' }}>Category</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            {EXPENSE_CHIPS.map(c => (
              <div key={c} className="chip" data-on={cat === c} onClick={() => setCat(c)} style={{ height: 38 }}>
                <Icon name={EXP_ICON[c]} size={15} /> {c}
              </div>
            ))}
          </div>

          {/* amount — strongest field */}
          <div className="sec-label" style={{ margin: '20px 0 10px' }}>Amount</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, border: '1.5px solid ' + (amount ? 'var(--green-600)' : 'var(--line)'), borderRadius: 16, padding: '14px 16px', background: 'var(--card)', boxShadow: 'var(--sh-card)', transition: '.15s' }}>
            <span style={{ fontSize: 28, fontWeight: 800, color: amount ? 'var(--ink)' : 'var(--ink-3)' }}>₵</span>
            <input value={amount} onChange={e => setAmount(e.target.value.replace(/[^0-9.]/g, ''))} inputMode="decimal" placeholder="0.00"
              className="tnum" style={{ flex: 1, border: 'none', outline: 'none', background: 'transparent', fontSize: 30, fontWeight: 800, color: 'var(--ink)', minWidth: 0, letterSpacing: '-0.02em' }} />
            <span style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--ink-3)' }}>GHS</span>
          </div>

          {/* note */}
          <div className="sec-label" style={{ margin: '18px 0 10px' }}>Note <span style={{ textTransform: 'none', letterSpacing: 0, color: 'var(--ink-3)', fontWeight: 500 }}>· optional</span></div>
          <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10, border: '1px solid var(--line)', borderRadius: 14, padding: '12px 14px', minHeight: 56, background: 'var(--card)' }}>
            <Icon name="note" size={18} color="var(--ink-3)" style={{ marginTop: 1 }} />
            <span style={{ fontSize: 14.5, color: 'var(--ink-3)' }}>Add a note for this expense…</span>
          </div>
          <div style={{ height: 90 }} />
        </>
      ) : (
        <>
          <div className="sec-head" style={{ marginTop: 18, marginBottom: 12 }}>
            <span className="sec-label">This Month</span>
            <span style={{ fontSize: 12.5, color: 'var(--ink-3)', fontWeight: 600 }}>{EXPENSE_LOG.length} entries</span>
          </div>
          <div className="card" style={{ padding: '4px 6px' }}>
            {EXPENSE_LOG.map(e => (
              <div className="row" key={e.id}>
                <div style={{ width: 42, height: 42, borderRadius: 12, flex: '0 0 auto', background: 'var(--warn-tint)', color: 'var(--warn)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name={e.icon} size={19} /></div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <span style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--ink)' }}>{e.cat}</span>
                  </div>
                  <div style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 2, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{e.note}</div>
                </div>
                <div style={{ textAlign: 'right', flex: '0 0 auto' }}>
                  <div className="tnum" style={{ fontSize: 15, fontWeight: 800, color: 'var(--ink)' }}>−{money(e.amount)}</div>
                  <div style={{ fontSize: 11.5, color: 'var(--ink-3)', fontWeight: 600, marginTop: 2 }}>{e.date}</div>
                </div>
              </div>
            ))}
          </div>
          <div style={{ height: 16 }} />
        </>
      )}
    </Screen>
  );
};

Object.assign(window, { Expenses });
