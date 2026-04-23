// SikaBoafo — Shared tokens, icons, layout primitives

const B = {
  navy:'#1A2744', navyM:'#243459', navyL:'#2D4070',
  green:'#1D7A4E', greenM:'#2A9960', greenL:'#E8F5EE',
  gold:'#C49A2A', goldL:'#FDF4DC',
  red:'#D94040', redL:'#FEF0F0',
  white:'#FFFFFF', bg:'#F6F7FA',
  g50:'#F0F2F6', g100:'#E4E7EE', g200:'#C8CEDB',
  g400:'#8892A4', g600:'#4A5568', g900:'#1A202C',
};

const ghs = (v) => '\u20B5' + Number(v).toLocaleString('en-GH',{minimumFractionDigits:2,maximumFractionDigits:2});
const ghsK = (v) => '\u20B5' + (v>=1000 ? (v/1000).toFixed(1)+'k' : Number(v).toLocaleString('en-GH',{maximumFractionDigits:0}));

const P = {
  home:<><path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></>,
  receipt:<><path d="M4 2v20l4-3 4 3 4-3 4 3V2"/><line x1="9" y1="9" x2="15" y2="9"/><line x1="9" y1="13" x2="15" y2="13"/></>,
  package:<><path d="M21 16V8a2 2 0 00-1-1.73l-7-4a2 2 0 00-2 0l-7 4A2 2 0 003 8v8a2 2 0 001 1.73l7 4a2 2 0 002 0l7-4A2 2 0 0021 16z"/><polyline points="3.27 6.96 12 12.01 20.73 6.96"/><line x1="12" y1="22.08" x2="12" y2="12"/></>,
  wallet:<><rect x="2" y="7" width="20" height="14" rx="2"/><path d="M16 3H8a1 1 0 00-1 1v3h10V4a1 1 0 00-1-1z"/><circle cx="16" cy="14" r="1.2" fill="currentColor" stroke="none"/></>,
  trending:<><polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/><polyline points="17 6 23 6 23 12"/></>,
  bell:<><path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 01-3.46 0"/></>,
  plus:<><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></>,
  minus:<line x1="5" y1="12" x2="19" y2="12"/>,
  send:<><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></>,
  search:<><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></>,
  alert:<><path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></>,
  check:<polyline points="20 6 9 17 4 12"/>,
  chevR:<polyline points="9 18 15 12 9 6"/>,
  chevL:<polyline points="15 18 9 12 15 6"/>,
  x:<><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></>,
  edit:<><path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/></>,
  filter:<><line x1="4" y1="6" x2="20" y2="6"/><line x1="8" y1="12" x2="16" y2="12"/><line x1="11" y1="18" x2="13" y2="18"/></>,
  phone:<><path d="M22 16.92v3a2 2 0 01-2.18 2 19.79 19.79 0 01-8.63-3.07A19.5 19.5 0 013.07 9.81 19.79 19.79 0 01.13 1.2 2 2 0 012.11 0h3a2 2 0 012 1.72c.127.96.361 1.903.7 2.81a2 2 0 01-.45 2.11L6.41 7.6a16 16 0 006 6l.96-.95a2 2 0 012.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0122 14.92z"/></>,
  users:<><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 00-3-3.87"/><path d="M16 3.13a4 4 0 010 7.75"/></>,
  barChart:<><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></>,
  momo: null,
};

function Ic({n,s=20,c='currentColor',w=1.8,fill='none'}) {
  return (
    <svg width={s} height={s} viewBox="0 0 24 24" fill={fill} stroke={c} strokeWidth={w} strokeLinecap="round" strokeLinejoin="round">
      {P[n]}
    </svg>
  );
}

// Reusable hero layout — navy top + white card slides up
function HeroLayout({hero, children, navScreen, onNav}) {
  return (
    <div style={{height:'100%',display:'flex',flexDirection:'column',background:B.navy,overflow:'hidden',fontFamily:'DM Sans,sans-serif'}}>
      {/* Decorative circles */}
      <div style={{position:'absolute',top:-60,right:-40,width:200,height:200,borderRadius:'50%',background:'rgba(255,255,255,.03)',pointerEvents:'none',zIndex:0}}/>
      <div style={{position:'absolute',top:-10,right:60,width:90,height:90,borderRadius:'50%',background:'rgba(255,255,255,.04)',pointerEvents:'none',zIndex:0}}/>
      <div style={{position:'absolute',bottom:320,left:-30,width:130,height:130,borderRadius:'50%',background:B.gold+'10',pointerEvents:'none',zIndex:0}}/>
      {/* Hero content */}
      <div style={{flexShrink:0,padding:'14px 20px 22px',position:'relative',zIndex:1}}>
        {hero}
      </div>
      {/* White panel */}
      <div style={{flex:1,background:B.bg,borderRadius:'24px 24px 0 0',overflow:'hidden',display:'flex',flexDirection:'column',position:'relative',zIndex:1}}>
        {children}
        <Nav5 screen={navScreen} onNav={onNav}/>
      </div>
    </div>
  );
}

// Top bar for hero
function HeroBar({title, onNotif, initials, right}) {
  return (
    <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',marginBottom:18}}>
      <div style={{fontSize:15,fontWeight:700,fontFamily:'Plus Jakarta Sans,sans-serif',color:'rgba(255,255,255,.9)',letterSpacing:'.01em'}}>{title}</div>
      <div style={{display:'flex',gap:12,alignItems:'center'}}>
        {right}
        <div style={{position:'relative',cursor:'pointer'}} onClick={onNotif}>
          <Ic n="bell" s={19} c="rgba(255,255,255,.6)"/>
          <div style={{position:'absolute',top:-2,right:-2,width:7,height:7,borderRadius:'50%',background:B.gold}}/>
        </div>
        {initials && <div style={{width:32,height:32,borderRadius:'50%',background:`linear-gradient(135deg,${B.gold},${B.gold}BB)`,display:'flex',alignItems:'center',justifyContent:'center',fontSize:11,fontWeight:800,color:B.navy,fontFamily:'Plus Jakarta Sans,sans-serif'}}>{initials}</div>}
      </div>
    </div>
  );
}

// 5-tab bottom nav
function Nav5({screen,onNav}) {
  const tabs = [
    {id:'home',  icon:'home',    label:'Home'},
    {id:'sales', icon:'receipt', label:'Sales'},
    {id:'stock', icon:'package', label:'Stock'},
    {id:'debt',  icon:'wallet',  label:'Debt'},
    {id:'reports',icon:'trending',label:'Reports'},
  ];
  return (
    <div style={{background:B.white,borderTop:`1px solid ${B.g100}`,display:'flex',paddingBottom:4,paddingTop:6,flexShrink:0}}>
      {tabs.map(t=>(
        <div key={t.id} onClick={()=>onNav(t.id)} style={{flex:1,display:'flex',flexDirection:'column',alignItems:'center',gap:2,cursor:'pointer',paddingTop:2}}>
          <div style={{width:26,height:3,borderRadius:2,background:screen===t.id?B.gold:'transparent',marginBottom:2}}/>
          <Ic n={t.icon} s={20} c={screen===t.id?B.navy:B.g400}/>
          <span style={{fontSize:9.5,fontWeight:screen===t.id?700:400,color:screen===t.id?B.navy:B.g400,fontFamily:'Plus Jakarta Sans,sans-serif',letterSpacing:'.01em'}}>{t.label}</span>
        </div>
      ))}
    </div>
  );
}

// Pill badge
function Badge({children,color,bg,size=11}) {
  return <span style={{background:bg||(color+'18'),color,borderRadius:100,padding:'2px 9px',fontSize:size,fontWeight:700,whiteSpace:'nowrap',fontFamily:'Plus Jakarta Sans,sans-serif'}}>{children}</span>;
}

// Section label
function SLabel({children,action,onAction}) {
  return (
    <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:12}}>
      <span style={{fontSize:11,fontWeight:700,color:B.g400,textTransform:'uppercase',letterSpacing:'.07em'}}>{children}</span>
      {action&&<span onClick={onAction} style={{fontSize:11,fontWeight:700,color:B.green,cursor:'pointer'}}>{action}</span>}
    </div>
  );
}

Object.assign(window, {B, ghs, ghsK, Ic, HeroLayout, HeroBar, Nav5, Badge, SLabel});
