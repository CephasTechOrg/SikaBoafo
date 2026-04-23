// ReportsScreen — Analytics & insights

const WEEK_DATA = [
  {day:'Mon', date:'14 Apr', sales:2100, txns:12, momo:1300, cash:800},
  {day:'Tue', date:'15 Apr', sales:3400, txns:19, momo:2200, cash:1200},
  {day:'Wed', date:'16 Apr', sales:2800, txns:15, momo:1750, cash:1050},
  {day:'Thu', date:'17 Apr', sales:4200, txns:23, momo:2800, cash:1400},
  {day:'Fri', date:'18 Apr', sales:3600, txns:20, momo:2100, cash:1500},
  {day:'Sat', date:'19 Apr', sales:5100, txns:31, momo:3200, cash:1900},
  {day:'Sun', date:'20 Apr', sales:4850, txns:28, momo:3000, cash:1850},
];

const MONTH_DATA = Array.from({length:4},(_, i)=>({
  day:`Wk ${i+1}`, date:'', sales:[11200,14800,18900,21400][i], txns:[58,72,94,112][i], momo:[7000,9200,11800,13300][i], cash:[4200,5600,7100,8100][i],
}));

function ReportsScreen({data, onNav}) {
  const [period, setPeriod] = React.useState('week');
  const chartData = period==='week' ? WEEK_DATA : MONTH_DATA;
  const maxVal = Math.max(...chartData.map(d=>d.sales));
  const totalSales = chartData.reduce((s,d)=>s+d.sales,0);
  const totalTxns  = chartData.reduce((s,d)=>s+d.txns,0);
  const totalMoMo  = chartData.reduce((s,d)=>s+d.momo,0);
  const totalCash  = chartData.reduce((s,d)=>s+d.cash,0);
  const momoPct    = Math.round((totalMoMo/totalSales)*100);
  const [hovered, setHovered] = React.useState(null);
  const initials = data.name.split(' ').map(w=>w[0]).join('');

  const topProducts = [
    {name:'Nivea Body Lotion', rev:2160, sold:90, color:B.navy},
    {name:'Milo 400g',         rev:1800, sold:90, color:B.green},
    {name:'Paracetamol 500mg', rev:1050, sold:210,color:B.gold},
    {name:'Amoxicillin 250mg', rev:840,  sold:70, color:B.red},
  ];
  const maxRev = topProducts[0].rev;

  return (
    <HeroLayout navScreen="reports" onNav={onNav} hero={
      <>
        <HeroBar title="Reports" initials={initials}/>
        <div>
          <div style={{fontSize:11,color:'rgba(255,255,255,.4)',fontWeight:600,letterSpacing:'.07em',textTransform:'uppercase',marginBottom:6}}>
            {period==='week'?'This Week':'This Month'}
          </div>
          <div style={{fontSize:36,fontWeight:800,color:'#fff',fontFamily:'Plus Jakarta Sans,sans-serif',letterSpacing:'-0.02em',lineHeight:1}}>{ghs(totalSales)}</div>
          <div style={{marginTop:8,display:'flex',gap:16,alignItems:'center'}}>
            <span style={{fontSize:11,color:'rgba(255,255,255,.5)'}}>{totalTxns} transactions</span>
            <span style={{fontSize:11,color:B.gold,fontWeight:600}}>📱 {momoPct}% MoMo</span>
          </div>
        </div>
        {/* Period selector */}
        <div style={{display:'flex',gap:6,marginTop:16}}>
          {['week','month'].map(p=>(
            <button key={p} onClick={()=>setPeriod(p)} style={{border:'none',cursor:'pointer',padding:'6px 16px',borderRadius:100,fontSize:11,fontWeight:700,background:period===p?B.gold:' rgba(255,255,255,.1)',color:period===p?B.navy:'rgba(255,255,255,.7)',fontFamily:'Plus Jakarta Sans,sans-serif',transition:'all .15s',letterSpacing:'.03em',textTransform:'capitalize'}}>
              {p==='week'?'This Week':'This Month'}
            </button>
          ))}
        </div>
      </>
    }>
      <div style={{flex:1,overflow:'auto',padding:'16px'}} className="sb-hide">

        {/* Bar chart */}
        <div style={{background:B.white,borderRadius:18,padding:'16px',marginBottom:16,boxShadow:'0 1px 4px rgba(0,0,0,.06)'}}>
          <SLabel>Revenue Trend</SLabel>
          <div style={{display:'flex',alignItems:'flex-end',gap:period==='week'?8:12,height:90,padding:'0 2px',marginBottom:8}}>
            {chartData.map((d,i)=>{
              const h = Math.max((d.sales/maxVal)*80, 4);
              const isHov = hovered===i;
              const isLast = i===chartData.length-1;
              return (
                <div key={i} style={{flex:1,display:'flex',flexDirection:'column',alignItems:'center',gap:4,cursor:'pointer'}}
                  onMouseEnter={()=>setHovered(i)} onMouseLeave={()=>setHovered(null)}
                  onClick={()=>setHovered(hovered===i?null:i)}>
                  {isHov&&(
                    <div style={{background:B.navy,color:'#fff',borderRadius:8,padding:'3px 6px',fontSize:9,fontWeight:700,fontFamily:'Plus Jakarta Sans,sans-serif',whiteSpace:'nowrap',position:'absolute',marginBottom:0,transform:'translateY(-24px)'}}>
                      {ghs(d.sales)}
                    </div>
                  )}
                  <div style={{width:'100%',height:h,borderRadius:'6px 6px 3px 3px',background:isLast||isHov?B.navy:B.navy+'30',transition:'all .2s'}}/>
                </div>
              );
            })}
          </div>
          <div style={{display:'flex',gap:period==='week'?8:12}}>
            {chartData.map((d,i)=>(
              <div key={i} style={{flex:1,textAlign:'center',fontSize:9,color:i===chartData.length-1?B.navy:B.g400,fontWeight:i===chartData.length-1?700:400}}>{d.day}</div>
            ))}
          </div>
        </div>

        {/* Payment split */}
        <div style={{background:B.white,borderRadius:18,padding:'16px',marginBottom:16,boxShadow:'0 1px 4px rgba(0,0,0,.06)'}}>
          <SLabel>Payment Methods</SLabel>
          <div style={{display:'flex',gap:4,height:10,borderRadius:6,overflow:'hidden',marginBottom:12}}>
            <div style={{width:`${momoPct}%`,background:B.gold,transition:'width .5s'}}/>
            <div style={{flex:1,background:B.green}}/>
          </div>
          <div style={{display:'flex',gap:16}}>
            {[
              {label:'Mobile Money',value:ghs(totalMoMo),pct:momoPct,color:B.gold,icon:'📱'},
              {label:'Cash',value:ghs(totalCash),pct:100-momoPct,color:B.green,icon:'💵'},
            ].map((m,i)=>(
              <div key={i} style={{flex:1,background:m.color+'10',borderRadius:14,padding:'12px 14px'}}>
                <div style={{fontSize:20,marginBottom:6}}>{m.icon}</div>
                <div style={{fontSize:15,fontWeight:800,color:m.color,fontFamily:'Plus Jakarta Sans,sans-serif'}}>{m.value}</div>
                <div style={{fontSize:11,color:B.g400,marginTop:2}}>{m.label}</div>
                <div style={{fontSize:12,fontWeight:700,color:m.color,marginTop:2}}>{m.pct}%</div>
              </div>
            ))}
          </div>
        </div>

        {/* Top products */}
        <div style={{background:B.white,borderRadius:18,padding:'16px',marginBottom:16,boxShadow:'0 1px 4px rgba(0,0,0,.06)'}}>
          <SLabel>Top Products</SLabel>
          <div style={{display:'flex',flexDirection:'column',gap:12}}>
            {topProducts.map((p,i)=>(
              <div key={i} style={{display:'flex',alignItems:'center',gap:12}}>
                <div style={{width:28,height:28,borderRadius:9,background:p.color+'15',display:'flex',alignItems:'center',justifyContent:'center',fontSize:12,fontWeight:800,color:p.color,fontFamily:'Plus Jakarta Sans,sans-serif',flexShrink:0}}>{i+1}</div>
                <div style={{flex:1}}>
                  <div style={{display:'flex',justifyContent:'space-between',marginBottom:5}}>
                    <span style={{fontSize:12,fontWeight:600,color:B.g900}}>{p.name}</span>
                    <span style={{fontSize:12,fontWeight:700,color:p.color}}>{ghs(p.rev)}</span>
                  </div>
                  <div style={{height:4,borderRadius:2,background:B.g100,overflow:'hidden'}}>
                    <div style={{height:'100%',borderRadius:2,background:p.color,width:`${(p.rev/maxRev)*100}%`,transition:'width .5s'}}/>
                  </div>
                  <div style={{fontSize:10,color:B.g400,marginTop:3}}>{p.sold} units sold</div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Summary cards */}
        <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10,marginBottom:8}}>
          {[
            {label:'Avg per Day',value:ghs(Math.round(totalSales/chartData.length)),icon:'📊'},
            {label:'Avg per Sale',value:ghs(Math.round(totalSales/totalTxns)),icon:'🧾'},
            {label:'Best Day',value:chartData.reduce((a,b)=>a.sales>b.sales?a:b).day,icon:'🏆'},
            {label:'Total Txns',value:totalTxns,icon:'✅'},
          ].map((c,i)=>(
            <div key={i} style={{background:B.white,borderRadius:16,padding:'14px',boxShadow:'0 1px 4px rgba(0,0,0,.06)'}}>
              <div style={{fontSize:20,marginBottom:6}}>{c.icon}</div>
              <div style={{fontSize:16,fontWeight:800,color:B.navy,fontFamily:'Plus Jakarta Sans,sans-serif'}}>{c.value}</div>
              <div style={{fontSize:11,color:B.g400,marginTop:2}}>{c.label}</div>
            </div>
          ))}
        </div>
      </div>
    </HeroLayout>
  );
}

Object.assign(window, {ReportsScreen});
