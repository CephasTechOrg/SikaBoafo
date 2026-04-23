// HomeScreen — Dashboard B (Money First)

function HomeScreen({data, onNav}) {
  const up = data.sales >= data.salesYest;
  const pct = Math.abs((data.sales - data.salesYest) / data.salesYest * 100).toFixed(1);
  const initials = data.name.split(' ').map(w=>w[0]).join('');

  return (
    <HeroLayout navScreen="home" onNav={onNav} hero={
      <>
        <HeroBar title="SikaBoafo" initials={initials}/>
        <div style={{textAlign:'center'}}>
          <div style={{fontSize:11,color:'rgba(255,255,255,.4)',fontWeight:500,letterSpacing:'.08em',textTransform:'uppercase',marginBottom:5}}>
            {data.greet} {data.name.split(' ')[0]} &middot; {data.biz}
          </div>
          <div style={{fontSize:11,color:'rgba(255,255,255,.3)',marginBottom:12}}>Mon, 21 Apr 2026</div>
          <div style={{fontSize:40,fontWeight:800,color:'#fff',fontFamily:'Plus Jakarta Sans,sans-serif',letterSpacing:'-0.02em',lineHeight:1}}>{ghs(data.sales)}</div>
          <div style={{fontSize:11,color:'rgba(255,255,255,.4)',marginTop:6,marginBottom:12}}>Sales Today</div>
          <div style={{display:'flex',justifyContent:'center'}}>
            <span style={{background:up?'rgba(45,180,100,.2)':'rgba(220,50,50,.2)',color:up?'#6EE7B7':'#FCA5A5',borderRadius:100,padding:'4px 14px',fontSize:12,fontWeight:700,border:`1px solid ${up?'rgba(45,180,100,.3)':'rgba(220,50,50,.3)'}`}}>
              {up?'▲':'▼'} {pct}% from yesterday
            </span>
          </div>
        </div>
        {/* Stat row */}
        <div style={{display:'grid',gridTemplateColumns:'1fr 1fr 1fr',gap:1,marginTop:20,background:'rgba(255,255,255,.06)',borderRadius:16,overflow:'hidden',border:'1px solid rgba(255,255,255,.08)'}}>
          {[
            {label:'Unpaid',value:ghsK(data.unpaid),color:B.gold},
            {label:'Low Stock',value:`${data.lowStock} items`,color:'#FF8080'},
            {label:'Staff Active',value:`${data.staff}`,color:'#6EE7B7'},
          ].map((s,i)=>(
            <div key={i} style={{padding:'12px 6px',textAlign:'center',borderRight:i<2?'1px solid rgba(255,255,255,.08)':'none',cursor:'pointer'}} onClick={()=>i===0?onNav('debt'):i===1?onNav('stock'):null}>
              <div style={{fontSize:14,fontWeight:700,color:s.color,fontFamily:'Plus Jakarta Sans,sans-serif'}}>{s.value}</div>
              <div style={{fontSize:10,color:'rgba(255,255,255,.4)',marginTop:2}}>{s.label}</div>
            </div>
          ))}
        </div>
      </>
    }>
      {/* Quick actions */}
      <div style={{padding:'18px 16px 0',flexShrink:0}}>
        <div style={{display:'flex',gap:10,overflowX:'auto',paddingBottom:2}} className="sb-hide">
          {[
            {label:'New Sale',icon:'receipt',bg:B.navy,fg:'#fff',screen:'sales'},
            {label:'Collect Debt',icon:'wallet',bg:B.green,fg:'#fff',screen:'debt'},
            {label:'Add Stock',icon:'package',bg:B.goldL,fg:B.gold,screen:'stock'},
            {label:'Reports',icon:'trending',bg:B.g50,fg:B.g600,screen:'reports'},
          ].map((a,i)=>(
            <div key={i} onClick={()=>onNav(a.screen)} style={{flexShrink:0,background:a.bg,borderRadius:14,padding:'10px 16px',display:'flex',alignItems:'center',gap:8,cursor:'pointer',boxShadow:i<2?'0 4px 14px rgba(0,0,0,.14)':'none'}}>
              <Ic n={a.icon} s={16} c={a.fg}/>
              <span style={{fontSize:12,fontWeight:700,color:a.fg,fontFamily:'Plus Jakarta Sans,sans-serif',whiteSpace:'nowrap'}}>{a.label}</span>
            </div>
          ))}
        </div>
      </div>
      {/* Activity */}
      <div style={{flex:1,overflow:'auto',padding:'16px'}} className="sb-hide">
        <SLabel>Recent Activity</SLabel>
        <div style={{display:'flex',flexDirection:'column',gap:8}}>
          {data.activity.map((a,i)=>(
            <div key={i} style={{background:B.white,borderRadius:14,padding:'12px 14px',display:'flex',alignItems:'center',gap:12,boxShadow:'0 1px 3px rgba(0,0,0,.05)'}}>
              <div style={{width:36,height:36,borderRadius:12,background:a.st==='paid'?B.greenL:a.st==='warn'?B.goldL:B.redL,display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
                <Ic n={a.st==='paid'?'check':a.st==='warn'?'alert':'wallet'} s={16} c={a.st==='paid'?B.green:a.st==='warn'?B.gold:B.red}/>
              </div>
              <div style={{flex:1,minWidth:0}}>
                <div style={{fontSize:12,fontWeight:600,color:B.g900,whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis'}}>{a.label}</div>
                <div style={{fontSize:10,color:B.g400,marginTop:2}}>{a.time}</div>
              </div>
              {a.amt&&<div style={{fontSize:13,fontWeight:700,color:a.st==='paid'?B.green:B.red}}>{ghs(a.amt)}</div>}
              {!a.amt&&<Badge color={B.gold} size={10}>Alert</Badge>}
            </div>
          ))}
        </div>
      </div>
    </HeroLayout>
  );
}

Object.assign(window, {HomeScreen});
