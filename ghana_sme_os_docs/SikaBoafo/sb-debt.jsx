// DebtScreen — Invoice & Debt collection

const DEBTORS = [
  {id:1, name:'Akosua Boateng', phone:'0244 123 456', total:300, paid:0,   days:5, items:['Nivea Lotion x1','Milo 400g x1']},
  {id:2, name:'Kwame Oti',      phone:'0557 891 234', total:480, paid:0,   days:3, items:['Paracetamol x4','Omo 1kg x2']},
  {id:3, name:'Mary Darko',     phone:'0208 445 678', total:150, paid:50,  days:8, items:['Vitamin C x2','Antiseptic x1']},
  {id:4, name:'Yaw Asante',     phone:'0244 776 543', total:310, paid:100, days:1, items:['Amoxicillin x3','Fanta x4']},
];

function DebtScreen({data, onNav}) {
  const [recording, setRecording] = React.useState(null);   // debtor id
  const [amounts,   setAmounts]   = React.useState({});
  const [paid,      setPaid]      = React.useState({});
  const [sentWA,    setSentWA]    = React.useState({});

  const debtors = DEBTORS.map(d => ({
    ...d,
    paid: d.paid + (paid[d.id] || 0),
  })).filter(d => d.paid < d.total);

  const totalOwed = debtors.reduce((s,d) => s + (d.total - d.paid), 0);

  const recordPayment = (id) => {
    const amt = parseFloat(amounts[id] || 0);
    if(amt <= 0) return;
    setPaid(p => ({...p, [id]: (p[id]||0) + amt}));
    setAmounts(a => ({...a, [id]: ''}));
    setRecording(null);
  };

  const dayColor = (d) => d >= 7 ? B.red : d >= 3 ? B.gold : B.green;
  const initials = data.name.split(' ').map(w=>w[0]).join('');

  return (
    <HeroLayout navScreen="debt" onNav={onNav} hero={
      <>
        <HeroBar title="Debt & Invoices" initials={initials}/>
        <div style={{display:'flex',alignItems:'flex-end',justifyContent:'space-between'}}>
          <div>
            <div style={{fontSize:11,color:'rgba(255,255,255,.4)',fontWeight:600,letterSpacing:'.07em',textTransform:'uppercase',marginBottom:6}}>Total Uncollected</div>
            <div style={{fontSize:36,fontWeight:800,color:'#fff',fontFamily:'Plus Jakarta Sans,sans-serif',letterSpacing:'-0.02em',lineHeight:1}}>{ghs(totalOwed)}</div>
            <div style={{marginTop:8,display:'flex',gap:6,alignItems:'center'}}>
              <div style={{width:6,height:6,borderRadius:'50%',background:B.gold}}/>
              <span style={{fontSize:11,color:'rgba(255,255,255,.5)'}}>{debtors.length} customers owe you</span>
            </div>
          </div>
          <button style={{border:'none',cursor:'pointer',background:B.gold,color:B.navy,borderRadius:14,padding:'12px 18px',fontSize:12,fontWeight:800,fontFamily:'Plus Jakarta Sans,sans-serif',boxShadow:'0 4px 14px rgba(196,154,42,.4)',display:'flex',alignItems:'center',gap:6}}>
            📱 Remind All
          </button>
        </div>
        {/* Quick stats */}
        <div style={{display:'grid',gridTemplateColumns:'1fr 1fr 1fr',gap:1,marginTop:18,background:'rgba(255,255,255,.06)',borderRadius:14,overflow:'hidden',border:'1px solid rgba(255,255,255,.08)'}}>
          {[
            {label:'Oldest',value:`${Math.max(...debtors.map(d=>d.days))} days`,color:'#FF8080'},
            {label:'This Week',value:ghs(debtors.filter(d=>d.days<=7).reduce((s,d)=>s+(d.total-d.paid),0)),color:B.gold},
            {label:'Collected',value:ghs(DEBTORS.reduce((s,d)=>s+(paid[d.id]||0),0)),color:'#6EE7B7'},
          ].map((s,i)=>(
            <div key={i} style={{padding:'10px 6px',textAlign:'center',borderRight:i<2?'1px solid rgba(255,255,255,.08)':'none'}}>
              <div style={{fontSize:13,fontWeight:700,color:s.color,fontFamily:'Plus Jakarta Sans,sans-serif'}}>{s.value}</div>
              <div style={{fontSize:9,color:'rgba(255,255,255,.4)',marginTop:2}}>{s.label}</div>
            </div>
          ))}
        </div>
      </>
    }>
      <div style={{flex:1,overflow:'auto',padding:'16px'}} className="sb-hide">
        <SLabel action="Export PDF">Customer Debts</SLabel>
        {debtors.length === 0 ? (
          <div style={{textAlign:'center',padding:'48px 24px'}}>
            <div style={{fontSize:40,marginBottom:12}}>🎉</div>
            <div style={{fontFamily:'Plus Jakarta Sans,sans-serif',fontSize:17,fontWeight:800,color:B.g900,marginBottom:6}}>All Cleared!</div>
            <div style={{fontSize:13,color:B.g400}}>No outstanding debts right now.</div>
          </div>
        ) : (
          <div style={{display:'flex',flexDirection:'column',gap:12}}>
            {debtors.map(d=>{
              const owed = d.total - d.paid;
              const pctPaid = (d.paid/d.total)*100;
              const isRecording = recording === d.id;
              const waColor = '#25D366';
              return (
                <div key={d.id} style={{background:B.white,borderRadius:18,overflow:'hidden',boxShadow:'0 2px 8px rgba(0,0,0,.06)'}}>
                  <div style={{padding:'16px 16px 12px'}}>
                    {/* Top row */}
                    <div style={{display:'flex',alignItems:'flex-start',gap:12,marginBottom:12}}>
                      <div style={{width:42,height:42,borderRadius:14,background:B.navy+'12',display:'flex',alignItems:'center',justifyContent:'center',fontSize:16,fontWeight:800,color:B.navy,fontFamily:'Plus Jakarta Sans,sans-serif',flexShrink:0}}>
                        {d.name.split(' ').map(w=>w[0]).join('')}
                      </div>
                      <div style={{flex:1}}>
                        <div style={{fontSize:14,fontWeight:700,color:B.g900}}>{d.name}</div>
                        <div style={{fontSize:11,color:B.g400,marginTop:2}}>{d.phone}</div>
                      </div>
                      <div style={{textAlign:'right'}}>
                        <div style={{fontSize:16,fontWeight:800,color:B.red,fontFamily:'Plus Jakarta Sans,sans-serif'}}>{ghs(owed)}</div>
                        <div style={{marginTop:2}}>
                          <Badge color={dayColor(d.days)} size={10}>{d.days}d overdue</Badge>
                        </div>
                      </div>
                    </div>

                    {/* Items */}
                    <div style={{fontSize:11,color:B.g400,marginBottom:10,lineHeight:1.5}}>{d.items.join('  ·  ')}</div>

                    {/* Progress bar (if partial payment) */}
                    {d.paid > 0 && (
                      <div style={{marginBottom:12}}>
                        <div style={{display:'flex',justifyContent:'space-between',marginBottom:4}}>
                          <span style={{fontSize:10,color:B.g400}}>Paid {ghs(d.paid)} of {ghs(d.total)}</span>
                          <span style={{fontSize:10,fontWeight:700,color:B.green}}>{Math.round(pctPaid)}%</span>
                        </div>
                        <div style={{height:4,borderRadius:2,background:B.g100,overflow:'hidden'}}>
                          <div style={{height:'100%',borderRadius:2,background:B.green,width:`${pctPaid}%`,transition:'width .5s'}}/>
                        </div>
                      </div>
                    )}

                    {/* Action buttons */}
                    {!isRecording ? (
                      <div style={{display:'flex',gap:8}}>
                        <button onClick={()=>{setSentWA(s=>({...s,[d.id]:true}));}} style={{flex:1,border:'none',cursor:'pointer',background:sentWA[d.id]?B.greenL:'#E8F9EF',color:sentWA[d.id]?B.green:'#128C7E',borderRadius:12,padding:'10px 0',fontSize:12,fontWeight:700,fontFamily:'Plus Jakarta Sans,sans-serif',display:'flex',alignItems:'center',justifyContent:'center',gap:6,transition:'all .2s'}}>
                          {sentWA[d.id]?<Ic n="check" s={13} c={B.green} w={2.5}/>:'📱'}
                          {sentWA[d.id]?'Sent!':'WhatsApp'}
                        </button>
                        <button onClick={()=>setRecording(d.id)} style={{flex:1,border:'none',cursor:'pointer',background:B.navy,color:'#fff',borderRadius:12,padding:'10px 0',fontSize:12,fontWeight:700,fontFamily:'Plus Jakarta Sans,sans-serif',display:'flex',alignItems:'center',justifyContent:'center',gap:6}}>
                          <Ic n="check" s={13} c="#fff" w={2.5}/> Record
                        </button>
                      </div>
                    ) : (
                      <div style={{background:B.g50,borderRadius:12,padding:12}}>
                        <div style={{fontSize:12,fontWeight:700,color:B.g900,marginBottom:8}}>Record Payment</div>
                        <div style={{display:'flex',gap:8}}>
                          <div style={{flex:1,background:B.white,borderRadius:10,padding:'9px 12px',display:'flex',alignItems:'center',gap:4,border:`1.5px solid ${B.g200}`}}>
                            <span style={{fontSize:13,color:B.g400,fontFamily:'Plus Jakarta Sans,sans-serif'}}>{'\u20B5'}</span>
                            <input type="number" value={amounts[d.id]||''} onChange={e=>setAmounts(a=>({...a,[d.id]:e.target.value}))} placeholder={owed.toFixed(2)} style={{border:'none',outline:'none',background:'none',fontSize:13,fontWeight:700,color:B.g900,width:'100%',fontFamily:'Plus Jakarta Sans,sans-serif'}}/>
                          </div>
                          <button onClick={()=>recordPayment(d.id)} style={{border:'none',cursor:'pointer',background:B.green,color:'#fff',borderRadius:10,padding:'0 18px',fontSize:13,fontWeight:700,fontFamily:'Plus Jakarta Sans,sans-serif'}}>Save</button>
                          <button onClick={()=>setRecording(null)} style={{border:'none',cursor:'pointer',background:B.g100,color:B.g600,borderRadius:10,padding:'0 12px',fontSize:13,fontWeight:700,fontFamily:'Plus Jakarta Sans,sans-serif'}}>✕</button>
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </HeroLayout>
  );
}

Object.assign(window, {DebtScreen});
