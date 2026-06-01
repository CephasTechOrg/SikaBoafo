/* screens-payment.jsx — Scan to Pay sheet with waiting / verifying / success / failed states */

/* deterministic faux-QR matrix (finder + timing + alignment + pseudo-random data) */
function qrMatrix(size, seed) {
  const m = Array.from({ length: size }, () => Array(size).fill(0));
  const finder = (r, c) => {
    for (let i = 0; i < 7; i++) for (let j = 0; j < 7; j++) {
      const edge = i === 0 || i === 6 || j === 0 || j === 6;
      const inner = i >= 2 && i <= 4 && j >= 2 && j <= 4;
      m[r + i][c + j] = edge || inner ? 1 : 0;
    }
  };
  finder(0, 0); finder(0, size - 7); finder(size - 7, 0);
  for (let i = 8; i < size - 8; i++) { m[6][i] = i % 2 === 0 ? 1 : 0; m[i][6] = i % 2 === 0 ? 1 : 0; }
  const a = size - 9;
  for (let i = 0; i < 5; i++) for (let j = 0; j < 5; j++) {
    const edge = i === 0 || i === 4 || j === 0 || j === 4, ctr = i === 2 && j === 2;
    m[a + i][a + j] = edge || ctr ? 1 : 0;
  }
  let s = 2166136261; for (let k = 0; k < seed.length; k++) { s ^= seed.charCodeAt(k); s = (s * 16777619) >>> 0; }
  const rnd = () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
  const reserved = (r, c) => (
    (r < 8 && c < 8) || (r < 8 && c >= size - 8) || (r >= size - 8 && c < 8) ||
    r === 6 || c === 6 || (r >= a - 1 && r <= a + 5 && c >= a - 1 && c <= a + 5)
  );
  for (let r = 0; r < size; r++) for (let c = 0; c < size; c++) if (!reserved(r, c)) m[r][c] = rnd() > 0.52 ? 1 : 0;
  return m;
}

const QRCode = ({ seed = 'sikabofo', size = 210, color = '#073B2A' }) => {
  const N = 29;
  const mat = React.useMemo(() => qrMatrix(N, seed), [seed]);
  const cell = size / N;
  const rects = [];
  for (let r = 0; r < N; r++) for (let c = 0; c < N; c++) if (mat[r][c]) {
    const isFinder = (r < 7 && c < 7) || (r < 7 && c >= N - 7) || (r >= N - 7 && c < 7);
    rects.push(<rect key={r + '-' + c} x={(c * cell).toFixed(2)} y={(r * cell).toFixed(2)} width={(cell * 1.02).toFixed(2)} height={(cell * 1.02).toFixed(2)} rx={cell * 0.28} fill={isFinder ? '#0F7A4A' : color} />);
  }
  return (
    <div style={{ position: 'relative', width: size, height: size }}>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} shapeRendering="crispEdges">{rects}</svg>
      <div style={{ position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%,-50%)', width: size * 0.2, height: size * 0.2, borderRadius: 12, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 2px 8px rgba(7,28,20,.18)' }}>
        <div style={{ width: '78%', height: '78%', borderRadius: 9, background: 'var(--green-900)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: size * 0.085 }}>₵</div>
      </div>
    </div>
  );
};

const Spinner = ({ size = 20, color = 'currentColor', sw = 2.4 }) => (
  <svg className="spin" width={size} height={size} viewBox="0 0 24 24" fill="none">
    <circle cx="12" cy="12" r="9" stroke={color} strokeOpacity="0.22" strokeWidth={sw} />
    <path d="M21 12a9 9 0 0 0-9-9" stroke={color} strokeWidth={sw} strokeLinecap="round" />
  </svg>
);

/* status band — the dedicated payment-status area */
const StatusBand = ({ state, ctx }) => {
  if (state === 'verifying') return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 16px', borderRadius: 16, background: '#EAF1FB', border: '1px solid #DCE7F6' }}>
      <Spinner size={22} color="#2563A8" />
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 14.5, fontWeight: 700, color: '#1E4E86' }}>Verifying payment…</div>
        <div style={{ fontSize: 12.5, color: '#4B72A8', marginTop: 1 }}>Confirming with Paystack, please wait</div>
      </div>
    </div>
  );
  if (state === 'success') return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 16px', borderRadius: 16, background: 'var(--green-tint)', border: '1px solid #CDEAD9' }}>
      <div style={{ width: 30, height: 30, borderRadius: '50%', background: 'var(--green-600)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto', animation: 'popcheck .35s cubic-bezier(.22,1,.36,1)' }}><Icon name="check" size={18} sw={2.6} /></div>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--green-700)' }}>Payment received</div>
        <div style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 1 }}>{money(ctx.amount)} · just now</div>
      </div>
    </div>
  );
  if (state === 'failed') return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 16px', borderRadius: 16, background: 'var(--danger-tint)', border: '1px solid #F6D9D9' }}>
      <div style={{ width: 30, height: 30, borderRadius: '50%', background: 'var(--danger)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' }}><Icon name="lowstock" size={17} sw={2.2} /></div>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--danger)' }}>QR expired</div>
        <div style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 1 }}>This code timed out. Generate a new one to retry.</div>
      </div>
    </div>
  );
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 16px', borderRadius: 16, background: 'var(--bg)', border: '1px solid var(--line)' }}>
      <div style={{ position: 'relative', width: 14, height: 14, flex: '0 0 auto' }}>
        <span style={{ position: 'absolute', inset: 0, borderRadius: '50%', background: 'var(--green-600)', animation: 'pingring 1.6s ease-out infinite' }} />
        <span style={{ position: 'absolute', inset: 3, borderRadius: '50%', background: 'var(--green-600)', animation: 'pulsedot 1.6s ease-in-out infinite' }} />
      </div>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--ink)' }}>Waiting for payment</div>
        <div style={{ fontSize: 12.5, color: 'var(--ink-2)', marginTop: 1 }}>We'll confirm automatically once it's paid</div>
      </div>
    </div>
  );
};

const ReceiptRow = ({ label, value, valueColor, last }) => (
  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '11px 0', borderBottom: last ? 'none' : '1px solid var(--line-soft)' }}>
    <span style={{ fontSize: 13.5, color: 'var(--ink-2)', fontWeight: 500 }}>{label}</span>
    <span className="tnum" style={{ fontSize: 14, fontWeight: 700, color: valueColor || 'var(--ink)' }}>{value}</span>
  </div>
);

const SuccessSheet = ({ ctx, isDebt, onDone, onClose }) => {
  const rows = isDebt
    ? [
        { label: 'Customer', value: ctx.party },
        { label: 'Amount paid', value: money(ctx.amount), valueColor: 'var(--ok)' },
        { label: 'Remaining balance', value: ctx.remaining > 0 ? money(ctx.remaining) : 'Cleared', valueColor: ctx.remaining > 0 ? 'var(--warn)' : 'var(--ok)' },
        { label: 'Payment method', value: ctx.method },
        { label: 'Reference', value: ctx.ref, last: true },
      ]
    : [
        { label: 'Amount paid', value: money(ctx.amount), valueColor: 'var(--ok)' },
        { label: 'Payment method', value: ctx.method },
        { label: 'Sale reference', value: ctx.ref },
        { label: 'Date & time', value: '30 May 2026 · 9:41 AM', last: true },
      ];
  return (
    <div className="modal-scrim" onClick={onClose}>
      <div className="bottomsheet" onClick={e => e.stopPropagation()} style={{ maxHeight: '95%', paddingBottom: 26 }}>
        <div className="grip" />
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, background: 'var(--bg)', border: '1px solid var(--line)', borderRadius: 999, padding: '5px 12px 5px 6px', marginBottom: 18 }}>
            <div style={{ width: 24, height: 24, borderRadius: 8, background: 'var(--green-900)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="store" size={14} /></div>
            <span style={{ fontSize: 13, fontWeight: 700, color: 'var(--ink)' }}>{ctx.merchant}</span>
            <Icon name="shield" size={14} color="var(--green-600)" />
          </div>
          <div style={{ position: 'relative', width: 76, height: 76, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <span style={{ position: 'absolute', inset: 0, borderRadius: '50%', background: 'var(--ok-tint)' }} />
            <div style={{ position: 'relative', width: 60, height: 60, borderRadius: '50%', background: 'var(--green-600)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 8px 20px rgba(22,138,85,.35)', animation: 'popcheck .4s cubic-bezier(.22,1,.36,1)' }}><Icon name="check" size={34} sw={2.6} /></div>
          </div>
          <h2 style={{ margin: '16px 0 0', fontSize: 23, fontWeight: 800, color: 'var(--ink)', letterSpacing: '-0.02em' }}>{isDebt ? 'Repayment recorded' : 'Payment received'}</h2>
          <div style={{ fontSize: 13.5, color: 'var(--ink-2)', marginTop: 5, maxWidth: 280 }}>
            {isDebt ? <><b style={{ color: 'var(--ink)' }}>{money(ctx.amount)}</b> collected from {ctx.party} via {ctx.method}.</> : <><b style={{ color: 'var(--ink)' }}>{money(ctx.amount)}</b> received via {ctx.method}.</>}
          </div>
        </div>

        {/* receipt */}
        <div style={{ marginTop: 18, border: '1px solid var(--line)', borderRadius: 18, background: 'var(--bg)', padding: '4px 16px' }}>
          {rows.map((r, i) => <ReceiptRow key={i} {...r} />)}
        </div>

        {/* actions */}
        <div style={{ marginTop: 16 }}>
          <div style={{ display: 'flex', gap: 11 }}>
            {!isDebt && <button className="btn btn--ghost" style={{ flex: 1, height: 48 }}><Icon name="receipt" size={17} /> View receipt</button>}
            <button className="btn btn--ghost" style={{ flex: 1, height: 48 }}><Icon name="arrowright" size={17} /> Share receipt</button>
          </div>
          <button className="btn btn--primary" style={{ width: '100%', marginTop: 11 }} onClick={onDone}><Icon name="check" size={19} /> Done</button>
        </div>
      </div>
    </div>
  );
};

const PaymentSheet = ({ ctx, state, onCheck, onClose, onRetry, onDone }) => {
  const isDebt = ctx.type === 'debt';
  const ctxBadge = isDebt
    ? { label: 'Debt Repayment', cls: 'badge--warn' }
    : { label: 'Sale Payment', cls: 'badge--green' };
  const done = state === 'success';
  const failed = state === 'failed';

  if (done) return <SuccessSheet ctx={ctx} isDebt={isDebt} onDone={onDone} onClose={onClose} />;

  return (
    <div className="modal-scrim" onClick={onClose}>
      <div className="bottomsheet" onClick={e => e.stopPropagation()} style={{ maxHeight: '95%', paddingBottom: 26 }}>
        <div className="grip" />

        {/* merchant + title */}
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, background: 'var(--bg)', border: '1px solid var(--line)', borderRadius: 999, padding: '5px 12px 5px 6px' }}>
            <div style={{ width: 24, height: 24, borderRadius: 8, background: 'var(--green-900)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="store" size={14} /></div>
            <span style={{ fontSize: 13, fontWeight: 700, color: 'var(--ink)' }}>{ctx.merchant}</span>
            <Icon name="shield" size={14} color="var(--green-600)" />
          </div>
          <h2 style={{ margin: '14px 0 0', fontSize: 23, fontWeight: 800, color: 'var(--ink)', letterSpacing: '-0.02em' }}>Scan to Pay</h2>
          <div style={{ fontSize: 13.5, color: 'var(--ink-2)', marginTop: 5, maxWidth: 270 }}>
            {isDebt ? <>Show this QR to <b style={{ color: 'var(--ink)' }}>{ctx.party}</b> to collect the repayment.</> : <>Show this QR to your customer. Payment confirms automatically.</>}
          </div>
        </div>

        {/* amount block */}
        <div style={{ marginTop: 16, borderRadius: 18, border: '1px solid var(--line)', background: 'linear-gradient(180deg,#FBFDFC,#F3F8F5)', padding: '15px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <div className="sec-label">{isDebt ? 'Repayment Amount' : 'Amount Due'}</div>
            <div className="tnum" style={{ fontSize: 32, fontWeight: 800, color: 'var(--ink)', letterSpacing: '-0.02em', marginTop: 3 }}>{money(ctx.amount)}</div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <span className={'badge ' + ctxBadge.cls + ' badge--dot'}>{ctxBadge.label}</span>
            <div style={{ display: 'flex', alignItems: 'center', gap: 5, justifyContent: 'flex-end', marginTop: 8, color: 'var(--ink-3)' }}>
              <Icon name="tag" size={13} />
              <span className="tnum" style={{ fontSize: 12, fontWeight: 600 }}>{ctx.ref}</span>
            </div>
          </div>
        </div>

        {/* QR container */}
        <div style={{ marginTop: 14, display: 'flex', justifyContent: 'center' }}>
          <div style={{ position: 'relative', background: '#fff', border: '1px solid var(--line)', borderRadius: 24, padding: 18, boxShadow: '0 6px 22px rgba(16,24,40,.07)' }}>
            <QRCode seed={ctx.link} size={206} />
            {(done || failed || state === 'verifying') && (
              <div style={{ position: 'absolute', inset: 18, borderRadius: 12, background: failed ? 'rgba(248,242,242,.86)' : 'rgba(255,255,255,.86)', backdropFilter: 'blur(2px)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 10 }}>
                {state === 'verifying' && <><Spinner size={40} color="var(--green-700)" /><span style={{ fontSize: 13.5, fontWeight: 700, color: 'var(--green-700)' }}>Verifying…</span></>}
                {done && <><div style={{ width: 58, height: 58, borderRadius: '50%', background: 'var(--green-600)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', animation: 'popcheck .4s cubic-bezier(.22,1,.36,1)' }}><Icon name="check" size={32} sw={2.6} /></div><span style={{ fontSize: 14, fontWeight: 700, color: 'var(--green-700)' }}>Paid</span></>}
                {failed && <><div style={{ width: 56, height: 56, borderRadius: '50%', background: 'var(--danger-tint)', color: 'var(--danger)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="clock" size={30} /></div><span style={{ fontSize: 14, fontWeight: 700, color: 'var(--danger)' }}>Expired</span></>}
              </div>
            )}
          </div>
        </div>

        {/* payment link */}
        <div style={{ marginTop: 16 }}>
          <div className="sec-label" style={{ marginBottom: 8 }}>Payment Link</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 9, height: 46, padding: '0 13px', background: 'var(--bg)', border: '1px solid var(--line)', borderRadius: 13 }}>
            <Icon name="tag" size={16} color="var(--green-700)" />
            <span className="tnum" style={{ flex: 1, minWidth: 0, fontSize: 13, color: 'var(--ink-2)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{ctx.link}</span>
          </div>
          <div style={{ display: 'flex', gap: 11, marginTop: 11 }}>
            <button className="btn btn--ghost" style={{ flex: 1, height: 48 }}><Icon name="grid" size={17} /> Copy link</button>
            <button className="btn btn--dark" style={{ flex: 1, height: 48 }}><Icon name="arrowright" size={17} /> Share</button>
          </div>
        </div>

        {/* status band */}
        <div style={{ marginTop: 16 }}>
          <StatusBand state={state} ctx={ctx} />
        </div>

        {/* primary CTA + close */}
        <div style={{ marginTop: 14 }}>
          {done ? (
            <button className="btn btn--primary" style={{ width: '100%' }} onClick={onDone}><Icon name="receipt" size={19} /> View receipt</button>
          ) : failed ? (
            <button className="btn btn--primary" style={{ width: '100%' }} onClick={onRetry}><Icon name="refresh" size={18} /> Generate new QR</button>
          ) : state === 'verifying' ? (
            <button className="btn btn--disabled" style={{ width: '100%' }} disabled><Spinner size={18} color="var(--ink-3)" /> Verifying payment…</button>
          ) : (
            <button className="btn btn--primary" style={{ width: '100%' }} onClick={onCheck}><Icon name="refresh" size={18} /> I've received payment</button>
          )}
          <button onClick={onClose} style={{ width: '100%', marginTop: 6, height: 46, background: 'none', border: 'none', cursor: 'pointer', fontSize: 14.5, fontWeight: 700, color: 'var(--ink-2)' }}>{done ? 'Close' : 'Cancel'}</button>
        </div>
      </div>
    </div>
  );
};

Object.assign(window, { QRCode, PaymentSheet, Spinner });
