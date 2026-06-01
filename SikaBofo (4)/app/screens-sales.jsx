/* screens-sales.jsx — Sales (POS) + Order Review bottom sheet */

const Segmented = ({ tabs, value, onChange }) => (
  <div style={{ display: 'flex', background: '#EBEFED', borderRadius: 14, padding: 4, gap: 4 }}>
    {tabs.map(t => (
      <button key={t} onClick={() => onChange(t)} style={{ flex: 1, height: 42, border: 'none', cursor: 'pointer',
        borderRadius: 11, fontSize: 14.5, fontWeight: 700,
        background: value === t ? 'var(--green-900)' : 'transparent',
        color: value === t ? '#fff' : 'var(--ink-2)',
        boxShadow: value === t ? '0 2px 8px rgba(7,59,42,.25)' : 'none', transition: '.18s' }}>{t}</button>
    ))}
  </div>
);

const Stepper = ({ qty, onInc, onDec }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: 0, background: 'var(--green-900)', borderRadius: 11, height: 36 }}>
    <button onClick={onDec} style={{ width: 36, height: 36, border: 'none', background: 'none', color: '#fff', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22, fontWeight: 600, lineHeight: 1, paddingBottom: 3 }}>−</button>
    <span className="tnum" style={{ minWidth: 22, textAlign: 'center', color: '#fff', fontWeight: 800, fontSize: 15 }}>{qty}</span>
    <button onClick={onInc} style={{ width: 36, height: 36, border: 'none', background: 'none', color: '#fff', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="plus" size={17} /></button>
  </div>
);

const ProductCard = ({ p, qty, onAdd, onInc, onDec }) => (
  <div className="card" style={{ overflow: 'hidden', display: 'flex', flexDirection: 'column', borderColor: qty > 0 ? 'var(--green-600)' : 'var(--line-soft)', boxShadow: qty > 0 ? '0 0 0 1.5px var(--green-600), var(--sh-card)' : 'var(--sh-card)', transition: '.15s' }}>
    <div style={{ position: 'relative', height: 98, background: 'linear-gradient(180deg,#FBFCFB,#F4F7F5)', display: 'flex', alignItems: 'center', justifyContent: 'center', borderBottom: '1px solid var(--line-soft)' }}>
      <img src={p.img} alt="" style={{ height: '74%', width: '74%', objectFit: 'contain' }} />
      <span style={{ position: 'absolute', top: 9, left: 9 }}><CatBadge cat={p.cat} /></span>
      {p.low && <span style={{ position: 'absolute', top: 9, right: 9 }} className="badge badge--warn">{p.stock} left</span>}
    </div>
    <div style={{ padding: '11px 13px 13px' }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 7 }}>
        <span style={{ fontSize: 15, fontWeight: 700, color: 'var(--ink)' }}>{p.name}</span>
        {p.size && <span style={{ fontSize: 11, fontWeight: 600, color: 'var(--ink-3)' }}>{p.size}</span>}
      </div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 10 }}>
        <div>
          <div className="tnum" style={{ fontSize: 17, fontWeight: 800, color: 'var(--green-700)' }}>{money(p.price)}</div>
          {!p.low && <div className="tnum" style={{ fontSize: 11.5, color: 'var(--ink-3)', fontWeight: 600, marginTop: 1 }}>{p.stock} in stock</div>}
        </div>
        {qty > 0
          ? <Stepper qty={qty} onInc={onInc} onDec={onDec} />
          : <button onClick={onAdd} style={{ width: 40, height: 40, borderRadius: 12, background: 'var(--green-tint)', color: 'var(--green-700)', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="plus" size={21} sw={2.2} /></button>}
      </div>
    </div>
  </div>
);

const SALES_HISTORY = [
  { id: 'INV-2026-0034', items: 'Indomie ×3, Malt ×1', total: 41, time: 'Today · 5:42 PM', pay: 'Cash', status: 'Paid' },
  { id: 'INV-2026-0033', items: 'Geisha Soap ×1',       total: 11, time: 'Today · 11:08 AM', pay: 'MoMo', status: 'Paid' },
  { id: 'INV-2026-0032', items: 'Milo ×2, Ideal Milk ×4', total: 82, time: 'Yesterday · 6:20 PM', pay: 'Cash', status: 'Paid' },
  { id: 'INV-2026-0031', items: 'Kivo Gari ×5',         total: 25, time: 'Yesterday · 2:14 PM', pay: 'Credit', status: 'Partial' },
];

const Sales = ({ onNav, cart, addItem, incItem, decItem, openReview }) => {
  const [tab, setTab] = React.useState('New Sale');
  const count = Object.values(cart).reduce((a, b) => a + b, 0);
  const total = Object.entries(cart).reduce((s, [id, q]) => s + byId(id).price * q, 0);

  return (
    <Screen nav={<BottomNav active="sales" onNav={onNav} />}
      bottomBar={
        <div style={{ flex: '0 0 auto', background: 'var(--card)', borderTop: '1px solid var(--line)', padding: '11px 16px', display: 'flex', alignItems: 'center', gap: 12, boxShadow: '0 -6px 20px rgba(16,24,40,.05)' }}>
          <div style={{ width: 46, height: 46, borderRadius: 13, background: count ? 'var(--green-tint)' : '#F1F3F5', color: count ? 'var(--green-700)' : 'var(--ink-3)', display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative', flex: '0 0 auto' }}>
            <Icon name="cart" size={22} />
            {count > 0 && <span style={{ position: 'absolute', top: -5, right: -5, minWidth: 19, height: 19, borderRadius: 10, background: 'var(--green-600)', color: '#fff', fontSize: 11, fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center', border: '2px solid #fff' }}>{count}</span>}
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div className="tnum" style={{ fontSize: 19, fontWeight: 800, color: 'var(--ink)' }}>{money(total)}</div>
            <div style={{ fontSize: 12, color: 'var(--ink-2)', fontWeight: 600 }}>{count ? `${count} item${count > 1 ? 's' : ''} · Cash` : 'Cart is empty'}</div>
          </div>
          <button disabled={!count} onClick={openReview} className={'btn ' + (count ? 'btn--primary' : 'btn--disabled')} style={{ height: 48, padding: '0 22px' }}>
            Checkout <Icon name="arrowright" size={19} />
          </button>
        </div>
      }
      hero={
        <TitleHero title="Sales" subtitle="Record today's sales">
          <div style={{ display: 'flex', alignItems: 'center', gap: 13, marginTop: 18, background: 'rgba(255,255,255,.10)', border: '1px solid rgba(255,255,255,.14)', borderRadius: 16, padding: '11px 13px' }}>
            <div style={{ background: '#fff', borderRadius: 12, padding: 5, flex: '0 0 auto' }}>
              <img src={byId('indomie').img} alt="" style={{ width: 40, height: 40, objectFit: 'contain' }} />
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 11.5, color: 'rgba(255,255,255,.66)', fontWeight: 700, letterSpacing: '.08em', textTransform: 'uppercase' }}>Top seller this month</div>
              <div style={{ fontSize: 16, fontWeight: 700, color: '#fff', marginTop: 2 }}>Indomie · 31 units</div>
            </div>
            <Icon name="trend" size={20} color="#7CE0B0" />
          </div>
        </TitleHero>
      }>
      <Segmented tabs={['New Sale', 'History']} value={tab} onChange={setTab} />

      {tab === 'New Sale' ? (
        <>
          <div className="search" style={{ marginTop: 16 }}>
            <Icon name="search" size={19} color="var(--ink-3)" />
            <input placeholder="Search by product name" />
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginTop: 16 }}>
            {PRODUCTS.map(p => (
              <ProductCard key={p.id} p={p} qty={cart[p.id] || 0}
                onAdd={() => addItem(p.id)} onInc={() => incItem(p.id)} onDec={() => decItem(p.id)} />
            ))}
          </div>
        </>
      ) : (
        <div style={{ marginTop: 16, display: 'flex', flexDirection: 'column', gap: 11 }}>
          {SALES_HISTORY.map(s => (
            <div className="card" key={s.id} style={{ padding: 15 }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <span style={{ fontSize: 13, fontWeight: 700, color: 'var(--ink)' }}>{s.id}</span>
                <span className={'badge ' + (s.status === 'Paid' ? 'badge--green' : 'badge--warn')}>{s.status}</span>
              </div>
              <div style={{ fontSize: 14, color: 'var(--ink)', fontWeight: 600, marginTop: 9 }}>{s.items}</div>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 9 }}>
                <span style={{ fontSize: 12.5, color: 'var(--ink-2)' }}>{s.time} · {s.pay}</span>
                <span className="tnum" style={{ fontSize: 16, fontWeight: 800, color: 'var(--green-700)' }}>{money(s.total)}</span>
              </div>
            </div>
          ))}
        </div>
      )}
      <div style={{ height: 8 }} />
    </Screen>
  );
};

/* ---------------- ORDER REVIEW BOTTOM SHEET ---------------- */
const OrderReview = ({ cart, incItem, decItem, removeItem, onClose, onCheckout }) => {
  const entries = Object.entries(cart).filter(([, q]) => q > 0);
  const count = entries.reduce((a, [, q]) => a + q, 0);
  const total = entries.reduce((s, [id, q]) => s + byId(id).price * q, 0);
  return (
    <div className="modal-scrim" onClick={onClose}>
      <div className="bottomsheet" onClick={e => e.stopPropagation()}>
        <div className="grip" />
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
          <div style={{ width: 44, height: 44, borderRadius: 13, background: 'var(--green-tint)', color: 'var(--green-700)', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' }}>
            <Icon name="receipt" size={22} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 19, fontWeight: 800, color: 'var(--ink)' }}>Order Review</div>
            <div style={{ fontSize: 13, color: 'var(--ink-2)', fontWeight: 500, marginTop: 1 }}>{count} item{count > 1 ? 's' : ''} · {money(total)}</div>
          </div>
          <button onClick={onClose} style={{ width: 36, height: 36, borderRadius: 11, border: 'none', background: '#F1F3F5', color: 'var(--ink-2)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="x" size={19} /></button>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column' }}>
          {entries.map(([id, q]) => {
            const p = byId(id);
            return (
              <div key={id} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '13px 0', borderTop: '1px solid var(--line-soft)' }}>
                <Thumb src={p.img} size={46} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 7 }}>
                    <span style={{ fontSize: 15, fontWeight: 700, color: 'var(--ink)' }}>{p.name}</span>
                    {p.size && <span style={{ fontSize: 11, fontWeight: 600, color: 'var(--ink-3)' }}>{p.size}</span>}
                  </div>
                  <div style={{ marginTop: 8 }}><Stepper qty={q} onInc={() => incItem(id)} onDec={() => decItem(id)} /></div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div className="tnum" style={{ fontSize: 15.5, fontWeight: 800, color: 'var(--ink)' }}>{money(p.price * q)}</div>
                  <button onClick={() => removeItem(id)} style={{ marginTop: 6, border: 'none', background: 'none', padding: 0, cursor: 'pointer', fontSize: 12.5, fontWeight: 600, color: 'var(--ink-3)', display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                    <Icon name="x" size={13} sw={2.2} /> Remove
                  </button>
                </div>
              </div>
            );
          })}
        </div>

        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '14px 16px', borderRadius: 14, background: 'var(--green-tint)', marginTop: 14 }}>
          <div>
            <div style={{ fontSize: 15, fontWeight: 700, color: 'var(--ink)' }}>Total</div>
            <div style={{ fontSize: 12, color: 'var(--ink-2)', fontWeight: 500, marginTop: 1 }}>{count} item{count > 1 ? 's' : ''} · Cash payment</div>
          </div>
          <span className="tnum" style={{ fontSize: 24, fontWeight: 800, color: 'var(--green-700)', letterSpacing: '-0.01em' }}>{money(total)}</span>
        </div>

        <div style={{ marginTop: 14 }}>
          <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--ink)', marginBottom: 8 }}>Note <span style={{ color: 'var(--ink-3)', fontWeight: 500 }}>(optional)</span></div>
          <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10, border: '1px solid var(--line)', borderRadius: 14, padding: '12px 14px', minHeight: 52 }}>
            <Icon name="note" size={18} color="var(--ink-3)" style={{ marginTop: 1 }} />
            <span style={{ fontSize: 14.5, color: 'var(--ink-3)' }}>Add a note for this sale…</span>
          </div>
        </div>

        <div style={{ display: 'flex', gap: 12, marginTop: 18 }}>
          <button onClick={onClose} className="btn btn--ghost" style={{ flex: 1 }}>Keep editing</button>
          <button onClick={onCheckout} className="btn btn--primary" style={{ flex: 1.5 }}><Icon name="check" size={20} /> Proceed to checkout</button>
        </div>
      </div>
    </div>
  );
};

Object.assign(window, { Sales, OrderReview, Segmented });
