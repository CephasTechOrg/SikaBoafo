/* screens-auth.jsx — Welcome / landing + Login */

const BrandMark = ({ size = 44, radius = 13, light }) => (
  <div style={{ width: size, height: size, borderRadius: radius, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto', boxShadow: light ? '0 4px 14px rgba(7,28,20,.18)' : '0 2px 8px rgba(7,28,20,.12)', padding: size * 0.13 }}>
    <img src="assets/logo.png" alt="SikaBoafo" style={{ width: '100%', height: '100%', objectFit: 'contain' }} />
  </div>
);

/* ---------------- WELCOME / LANDING ---------------- */
const Welcome = ({ onNav }) => (
  <div className="screen" style={{ background: 'var(--card)' }}>
    <div className="screen__scroll" style={{ display: 'flex', flexDirection: 'column' }}>
      {/* hero image */}
      <div style={{ position: 'relative', height: 446, flex: '0 0 auto', backgroundImage: 'url(assets/businesswoman.png)', backgroundSize: 'cover', backgroundPosition: '50% 12%' }}>
        <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, rgba(7,40,28,.35) 0%, rgba(7,40,28,0) 28%, rgba(7,40,28,0) 60%, rgba(7,59,42,.55) 100%)' }} />
        <div style={{ position: 'relative', zIndex: 2 }}><StatusBar dark /></div>
        <div style={{ position: 'absolute', left: 'var(--gutter)', bottom: 40, zIndex: 2, display: 'flex', alignItems: 'center', gap: 12 }}>
          <BrandMark size={46} light />
          <span style={{ fontSize: 22, fontWeight: 800, color: '#fff', letterSpacing: '-0.01em', textShadow: '0 2px 12px rgba(0,0,0,.35)' }}>SikaBoafo</span>
        </div>
      </div>

      {/* content sheet with curved top */}
      <div style={{ flex: 1, background: 'var(--card)', borderRadius: '32px 32px 0 0', marginTop: -28, position: 'relative', zIndex: 3, padding: '34px var(--gutter) 24px', display: 'flex', flexDirection: 'column' }}>
        <h1 style={{ margin: 0, fontSize: 32, fontWeight: 800, color: 'var(--ink)', letterSpacing: '-0.03em', lineHeight: 1.08 }}>Your business,<br />simplified.</h1>
        <p style={{ margin: '14px 0 0', fontSize: 15, lineHeight: 1.5, color: 'var(--ink-2)', maxWidth: 320 }}>
          Track sales, stock, customers and debts — all in one calm, trustworthy workspace built for Ghanaian shops.
        </p>

        <div style={{ flex: 1 }} />

        <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginTop: 30 }}>
          <button className="btn btn--primary" style={{ width: '100%', height: 54 }} onClick={() => onNav('login')}>Sign In</button>
          <button className="btn btn--ghost" style={{ width: '100%', height: 54 }} onClick={() => onNav('login')}>Create account</button>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7, marginTop: 20, marginBottom: 4 }}>
          <span style={{ width: 7, height: 7, borderRadius: '50%', background: 'var(--green-600)' }} />
          <span style={{ fontSize: 11.5, fontWeight: 700, letterSpacing: '.08em', textTransform: 'uppercase', color: 'var(--ink-3)' }}>Secure workspace · v2.4</span>
        </div>
      </div>
    </div>
  </div>
);

/* ---------------- LOGIN ---------------- */
const Field = ({ icon, children, focus }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: 11, height: 54, padding: '0 15px', borderRadius: 14, background: 'var(--card)', border: '1.5px solid ' + (focus ? 'var(--green-600)' : 'var(--line)'), boxShadow: 'var(--sh-card)' }}>
    <Icon name={icon} size={19} color={focus ? 'var(--green-700)' : 'var(--ink-3)'} />
    {children}
  </div>
);

const Login = ({ onNav }) => {
  const [show, setShow] = React.useState(false);
  return (
    <div className="screen">
      <div className="screen__scroll" style={{ display: 'flex', flexDirection: 'column' }}>
        {/* green hero */}
        <div style={{ position: 'relative', background: 'linear-gradient(178deg,#0A4A34 0%, var(--green-900) 75%)', overflow: 'hidden', flex: '0 0 auto', paddingBottom: 52 }}>
          <div className="hero__glow" style={{ position: 'absolute', width: 230, height: 230, right: -70, top: -80, borderRadius: '50%', background: 'radial-gradient(circle, rgba(46,160,110,.4), transparent 70%)' }} />
          <div className="hero__glow" style={{ position: 'absolute', width: 200, height: 200, left: -70, bottom: -40, borderRadius: '50%', background: 'radial-gradient(circle, rgba(20,90,60,.5), transparent 70%)' }} />
          <div style={{ position: 'relative', zIndex: 2 }}>
            <StatusBar dark />
            <div style={{ padding: '0 var(--gutter)' }}>
              <button onClick={() => onNav('welcome')} style={{ width: 38, height: 38, marginLeft: -6, marginTop: 2, borderRadius: 12, background: 'rgba(255,255,255,.12)', border: 'none', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}><Icon name="back" size={20} /></button>
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', marginTop: 16 }}>
                <BrandMark size={62} radius={18} light />
                <div style={{ fontSize: 23, fontWeight: 800, color: '#fff', marginTop: 14, letterSpacing: '-0.01em' }}>SikaBoafo</div>
                <div style={{ fontSize: 14, color: 'rgba(255,255,255,.72)', marginTop: 4 }}>Welcome back</div>
              </div>
            </div>
          </div>
        </div>

        {/* form sheet */}
        <div style={{ flex: 1, background: 'var(--bg)', borderRadius: '28px 28px 0 0', marginTop: -28, position: 'relative', zIndex: 3, padding: '28px var(--gutter) 24px' }}>
          <label className="sec-label" style={{ display: 'block', marginBottom: 9 }}>Phone Number</label>
          <Field icon="phone">
            <input placeholder="+233 55 123 4567" className="tnum" style={{ flex: 1, border: 'none', outline: 'none', background: 'transparent', fontSize: 15.5, color: 'var(--ink)' }} />
          </Field>

          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', margin: '20px 0 9px' }}>
            <label className="sec-label">Security PIN</label>
            <span className="link" style={{ cursor: 'pointer' }}>Forgot PIN?</span>
          </div>
          <Field icon="lock">
            <input type={show ? 'text' : 'password'} defaultValue="4821" inputMode="numeric" maxLength={4}
              style={{ flex: 1, border: 'none', outline: 'none', background: 'transparent', fontSize: 20, fontWeight: 700, letterSpacing: '.4em', color: 'var(--ink)' }} />
            <button onClick={() => setShow(s => !s)} style={{ border: 'none', background: 'none', cursor: 'pointer', color: 'var(--ink-3)', display: 'flex', padding: 4 }}>
              <Icon name={show ? 'eyeoff' : 'eye'} size={19} />
            </button>
          </Field>

          <button className="btn btn--primary" style={{ width: '100%', height: 54, marginTop: 24 }} onClick={() => onNav('dashboard')}>Sign In</button>

          <div style={{ display: 'flex', alignItems: 'center', gap: 12, margin: '22px 0 16px' }}>
            <div style={{ flex: 1, height: 1, background: 'var(--line)' }} />
            <span style={{ fontSize: 11, fontWeight: 700, letterSpacing: '.08em', color: 'var(--ink-3)' }}>NEW TO SIKABOAFO?</span>
            <div style={{ flex: 1, height: 1, background: 'var(--line)' }} />
          </div>
          <button className="btn btn--ghost" style={{ width: '100%', height: 52 }}>Create account</button>

          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, marginTop: 22 }}>
            <Icon name="shield" size={14} color="var(--green-600)" />
            <span style={{ fontSize: 12, color: 'var(--ink-3)', fontWeight: 600 }}>Bank-grade security · your data stays private</span>
          </div>
          <div style={{ height: 8 }} />
        </div>
      </div>
    </div>
  );
};

Object.assign(window, { Welcome, Login, BrandMark });
