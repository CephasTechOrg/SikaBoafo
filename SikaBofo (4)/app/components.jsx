/* components.jsx — shared shell + chrome for SikaBofo */

/* Ghana map silhouette — used as a low-opacity header watermark */
const GhanaMap = ({ style, color = '#ffffff', opacity = 0.12 }) => (
  <svg viewBox="0 0 200 240" style={style} fill={color} opacity={opacity} aria-hidden="true">
    <path d="M40 18 L70 14 L96 17 L128 14 L150 20 L156 34 L150 52 L158 70
      L150 86 L160 104 L152 120 L160 140 L150 158 L156 178 L150 198
      L130 214 L112 210 L96 220 L78 214 L70 222 L58 210 L50 214 L46 198
      L52 180 L44 162 L52 144 L44 126 L52 106 L44 86 L50 66 L42 46 Z" />
  </svg>
);

/* status bar — light text for dark hero, dark text otherwise */
const StatusBar = ({ dark = true }) => {
  const c = dark ? '#fff' : '#111827';
  return (
    <div style={{ height: 38, flex: '0 0 38px', display: 'flex', alignItems: 'center',
      justifyContent: 'space-between', padding: '0 22px 0 26px', position: 'relative', zIndex: 30 }}>
      <span style={{ fontSize: 14.5, fontWeight: 700, color: c, letterSpacing: '.02em' }}>9:41</span>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <svg width="17" height="12" viewBox="0 0 17 12" fill={c}><rect x="0" y="7" width="3" height="5" rx="1"/><rect x="4.5" y="4.5" width="3" height="7.5" rx="1"/><rect x="9" y="2" width="3" height="10" rx="1"/><rect x="13.5" y="0" width="3" height="12" rx="1"/></svg>
        <svg width="16" height="12" viewBox="0 0 16 12" fill={c}><path d="M8 2.4c2 0 3.9.8 5.3 2.1l1.1-1.2A9.4 9.4 0 0 0 8 .8 9.4 9.4 0 0 0 1.6 3.3l1.1 1.2A7.6 7.6 0 0 1 8 2.4Zm0 3.1c1.1 0 2.2.45 3 1.2l1.15-1.2A6.1 6.1 0 0 0 8 4.7a6.1 6.1 0 0 0-4.15 1.8L5 7.7A4.3 4.3 0 0 1 8 5.5Z"/><circle cx="8" cy="10" r="1.7"/></svg>
        <svg width="25" height="12" viewBox="0 0 25 12" fill="none"><rect x="0.6" y="0.6" width="21" height="10.8" rx="2.6" stroke={c} strokeOpacity="0.5"/><rect x="2.2" y="2.2" width="17" height="7.6" rx="1.4" fill={c}/><rect x="22.6" y="3.6" width="1.6" height="4.8" rx="0.8" fill={c} fillOpacity="0.5"/></svg>
      </div>
    </div>
  );
};

/* gesture nav pill */
const GestureBar = () => (
  <div style={{ height: 22, flex: '0 0 22px', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--card)' }}>
    <div style={{ width: 128, height: 5, borderRadius: 3, background: '#111827', opacity: 0.85 }} />
  </div>
);

/* Phone shell — fixed-size device, hosts a single screen */
const Phone = ({ children, statusDark = true }) => (
  <div className="sb-app" style={{
    width: 392, height: 830, borderRadius: 44, padding: 5, background: '#0c0c0d',
    boxShadow: '0 40px 90px -20px rgba(7,28,20,.45), 0 0 0 1px rgba(0,0,0,.6)', flex: '0 0 auto',
  }}>
    <div style={{ width: '100%', height: '100%', borderRadius: 39, overflow: 'hidden',
      background: 'var(--bg)', display: 'flex', flexDirection: 'column', position: 'relative' }}>
      {/* status bar floats over hero, so render inside screen; keep gesture bar pinned */}
      <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
        {children}
      </div>
      <GestureBar />
    </div>
  </div>
);

/* Avatar / initials */
const Avatar = ({ init, size = 42, bg = 'rgba(255,255,255,.16)', fg = '#fff', ring }) => (
  <div className="avatar" style={{ width: size, height: size, background: bg, color: fg,
    fontSize: size * 0.36, flex: '0 0 auto', border: ring ? `1.5px solid ${ring}` : 'none' }}>{init}</div>
);

/* Product thumbnail */
const Thumb = ({ src, size = 52, radius = 13 }) => (
  <div className="thumb" style={{ width: size, height: size, borderRadius: radius, flex: '0 0 auto' }}>
    <img src={src} alt="" />
  </div>
);

/* Category badge */
const CatBadge = ({ cat }) => {
  const c = CAT_COLOR[cat] || CAT_COLOR.Grocery;
  return <span className="badge" style={{ background: c.bg, color: c.fg }}>{cat}</span>;
};

/* Hero header — shared across primary pages */
const Hero = ({ children, tall, map, glow = true }) => (
  <div className={'hero' + (tall ? ' hero--tall' : '')}>
    {glow && <div className="hero__glow" style={{ position: 'absolute', width: 240, height: 240, right: -70, top: -90, background: 'radial-gradient(circle, rgba(46,160,110,.45), transparent 70%)' }} />}
    {glow && <div className="hero__glow" style={{ position: 'absolute', width: 200, height: 200, left: -80, bottom: -70, background: 'radial-gradient(circle, rgba(20,90,60,.5), transparent 70%)' }} />}
    {map && <GhanaMap style={{ position: 'absolute', width: 320, right: -40, top: 4, height: 'auto' }} opacity={0.10} />}
    {children}
  </div>
);

/* small hero stat tile (glassy) */
const HeroStat = ({ icon, value, label }) => (
  <div style={{ flex: 1, background: 'rgba(255,255,255,.10)', border: '1px solid rgba(255,255,255,.14)',
    borderRadius: 14, padding: '11px 13px', backdropFilter: 'blur(4px)' }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
      <Icon name={icon} size={17} color="rgba(255,255,255,.85)" />
      <span className="tnum" style={{ fontSize: 19, fontWeight: 800, color: '#fff', lineHeight: 1 }}>{value}</span>
    </div>
    <div style={{ fontSize: 12.5, color: 'rgba(255,255,255,.72)', fontWeight: 600, marginTop: 5 }}>{label}</div>
  </div>
);

/* page-title hero header (Sales/Inventory/Customers/Debts) */
const TitleHero = ({ title, subtitle, onBack, right, children, map }) => (
  <Hero map={map}>
    <StatusBar dark />
    <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginTop: 6 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: onBack ? 8 : 0 }}>
        {onBack && (
          <button onClick={onBack} style={{ width: 36, height: 36, marginLeft: -6, borderRadius: 12, background: 'rgba(255,255,255,.12)', border: 'none', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <Icon name="back" size={21} />
          </button>
        )}
        <div>
          <h1 style={{ margin: 0, fontSize: 27, fontWeight: 800, color: '#fff', letterSpacing: '-0.02em' }}>{title}</h1>
          {subtitle && <div style={{ fontSize: 13.5, color: 'rgba(255,255,255,.72)', fontWeight: 500, marginTop: 3 }}>{subtitle}</div>}
        </div>
      </div>
      {right && <div style={{ display: 'flex', gap: 9 }}>{right}</div>}
    </div>
    {children}
  </Hero>
);

const HeaderIconBtn = ({ icon, badge, onClick }) => (
  <button onClick={onClick} style={{ position: 'relative', width: 42, height: 42, borderRadius: 13, background: 'rgba(255,255,255,.12)', border: '1px solid rgba(255,255,255,.10)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
    <Icon name={icon} size={20} />
    {badge != null && <span style={{ position: 'absolute', top: -4, right: -4, minWidth: 18, height: 18, padding: '0 4px', borderRadius: 9, background: 'var(--danger)', color: '#fff', fontSize: 11, fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center', border: '2px solid #0A4632' }}>{badge}</span>}
  </button>
);

/* Bottom navigation */
const NAV = [
  { id: 'dashboard', label: 'Dashboard', icon: 'home' },
  { id: 'sales',     label: 'Sales',     icon: 'sales' },
  { id: 'inventory', label: 'Inventory', icon: 'inventory' },
  { id: 'more',      label: 'More',      icon: 'grid' },
];
const BottomNav = ({ active, onNav }) => (
  <div className="tabbar" style={{ flex: '0 0 auto' }}>
    {NAV.map(t => {
      const on = active === t.id || (t.id === 'more' && ['customers', 'debts'].includes(active));
      return (
        <button key={t.id} className="tab" data-on={on} onClick={() => onNav(t.id)} style={{ background: 'none', border: 'none' }}>
          <Icon name={t.icon} size={23} sw={on ? 2.1 : 1.8} />
          <span className="tab__l">{t.label}</span>
        </button>
      );
    })}
  </div>
);

/* A scrollable content area with sheet + bottom nav layout */
const Screen = ({ hero, children, nav, fab, bottomBar }) => (
  <div className="screen">
    <div className="screen__scroll">
      {hero}
      <div className="sheet">{children}</div>
    </div>
    {fab}
    {bottomBar}
    {nav}
  </div>
);

Object.assign(window, { GhanaMap, StatusBar, GestureBar, Phone, Avatar, Thumb, CatBadge, Hero, HeroStat, TitleHero, HeaderIconBtn, BottomNav, Screen });
