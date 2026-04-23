// SalesScreen — New Sale + History

const PRODUCTS = [
  {id:1, name:'Paracetamol 500mg', price:5.00,  cat:'Medicine',   stock:8},
  {id:2, name:'Amoxicillin 250mg', price:12.00, cat:'Medicine',   stock:3},
  {id:3, name:'Vitamin C 1000mg',  price:18.00, cat:'Medicine',   stock:31},
  {id:4, name:'Antiseptic Cream',  price:8.50,  cat:'Medicine',   stock:5},
  {id:5, name:'Nivea Body Lotion', price:24.00, cat:'Personal',   stock:24},
  {id:6, name:'Milo 400g',         price:20.00, cat:'Food',       stock:15},
  {id:7, name:'Omo Detergent 1kg', price:15.00, cat:'Household',  stock:7},
  {id:8, name:'Fanta 330ml',       price:4.00,  cat:'Drinks',     stock:48},
];

const HISTORY = [
  {id:'T001', name:'Kofi Agyemang',       items:3, total:480, method:'MoMo',  time:'9:02 AM'},
  {id:'T002', name:'Cash Sale',           items:1, total:120, method:'Cash',  time:'9:41 AM'},
  {id:'T003', name:'Akua Serwaa',         items:5, total:315, method:'MoMo',  time:'10:15 AM'},
  {id:'T004', name:'Cash Sale',           items:2, total:88,  method:'Cash',  time:'11:03 AM'},
  {id:'T005', name:'Kwame Mensah',        items:4, total:650, method:'MoMo',  time:'11:50 AM'},
  {id:'T006', name:'Cash Sale',           items:1, total:24,  method:'Cash',  time:'12:18 PM'},
  {id:'T007', name:'Abena Osei',          items:6, total:720, method:'MoMo',  time:'1:05 PM'},
  {id:'T008', name:'Cash Sale',           items:2, total:58,  method:'Cash',  time:'2:40 PM'},
];

function SalesScreen({data, onNav}) {
  const [tab, setTab] = React.useState('new');
  const [query, setQuery] = React.useState('');
  const [cart, setCart] = React.useState([]);
  const [paying, setPaying] = React.useState(false);
  const [payMethod, setPayMethod] = React.useState(null);
  const [success, setSuccess] = React.useState(false);

  const filtered = PRODUCTS.filter(p => p.name.toLowerCase().includes(query.toLowerCase()));
  const cartTotal = cart.reduce((s,c)=>s+c.price*c.qty, 0);
  const cartCount = cart.reduce((s,c)=>s+c.qty, 0);
  const todayTotal = HISTORY.reduce((s,h)=>s+h.total,0) + (success ? cartTotal : 0);

  const addToCart = (p) => {
    setCart(c => {
      const ex = c.find(x=>x.id===p.id);
      if(ex) return c.map(x=>x.id===p.id?{...x,qty:x.qty+1}:x);
      return [...c, {...p, qty:1}];
    });
  };
  const removeOne = (id) => {
    setCart(c => c.map(x=>x.id===id?{...x,qty:x.qty-1}:x).filter(x=>x.qty>0));
  };
  const confirmSale = (method) => {
    setPayMethod(method);
    setTimeout(()=>{setSuccess(true);setPaying(false);setCart([]);}, 900);
  };
  const resetSale = () => { setSuccess(false); setPayMethod(null); };

  const initials = data.name.split(' ').map(w=>w[0]).join('');

  return (
    <HeroLayout navScreen="sales" onNav={onNav} hero={
      <>
        <HeroBar title="Sales" initials={initials}/>
        <div style={{display:'flex',alignItems:'flex-end',justifyContent:'space-between'}}>
          <div>
            <div style={{fontSize:11,color:'rgba(255,255,255,.4)',fontWeight:600,letterSpacing:'.07em',textTransform:'uppercase',marginBottom:6}}>Today's Revenue</div>
            <div style={{fontSize:36,fontWeight:800,color:'#fff',fontFamily:'Plus Jakarta Sans,sans-serif',letterSpacing:'-0.02em',lineHeight:1}}>{ghs(todayTotal)}</div>
            <div style={{marginTop:8,display:'flex',gap:8,alignItems:'center'}}>
              <span style={{fontSize:11,color:'rgba(255,255,255,.5)'}}>{HISTORY.length + (success?1:0)} transactions</span>
              <span style={{width:4,height:4,borderRadius:'50%',background:'rgba(255,255,255,.25)',display:'inline-block'}}/>
              <span style={{fontSize:11,color:'#6EE7B7',fontWeight:600}}>MoMo + Cash</span>
            </div>
          </div>
          <div style={{display:'flex',gap:8}}>
            <div style={{textAlign:'center',background:'rgba(255,255,255,.08)',borderRadius:12,padding:'10px 14px',border:'1px solid rgba(255,255,255,.08)'}}>
              <div style={{fontSize:16,fontWeight:800,color:B.gold,fontFamily:'Plus Jakarta Sans,sans-serif'}}>
                {ghs(HISTORY.filter(h=>h.method==='MoMo').reduce((s,h)=>s+h.total,0))}
              </div>
              <div style={{fontSize:9,color:'rgba(255,255,255,.4)',marginTop:2}}>MoMo</div>
            </div>
            <div style={{textAlign:'center',background:'rgba(255,255,255,.08)',borderRadius:12,padding:'10px 14px',border:'1px solid rgba(255,255,255,.08)'}}>
              <div style={{fontSize:16,fontWeight:800,color:'#6EE7B7',fontFamily:'Plus Jakarta Sans,sans-serif'}}>
                {ghs(HISTORY.filter(h=>h.method==='Cash').reduce((s,h)=>s+h.total,0))}
              </div>
              <div style={{fontSize:9,color:'rgba(255,255,255,.4)',marginTop:2}}>Cash</div>
            </div>
          </div>
        </div>
      </>
    }>
      {/* Tabs */}
      <div style={{display:'flex',padding:'16px 16px 0',gap:8,flexShrink:0}}>
        {['New Sale','History'].map((t,i)=>(
          <button key={i} onClick={()=>{setTab(i===0?'new':'hist');resetSale();}} style={{border:'none',cursor:'pointer',padding:'8px 18px',borderRadius:100,fontSize:13,fontWeight:700,background:tab===(i===0?'new':'hist')?B.navy:B.g50,color:tab===(i===0?'new':'hist')?'#fff':B.g400,fontFamily:'Plus Jakarta Sans,sans-serif',transition:'all .15s'}}>{t}</button>
        ))}
      </div>

      {tab==='new' && (
        <>
          {success ? (
            <div style={{flex:1,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',padding:32,gap:16}}>
              <div style={{width:72,height:72,borderRadius:'50%',background:B.greenL,display:'flex',alignItems:'center',justifyContent:'center'}}>
                <Ic n="check" s={32} c={B.green} w={2.5}/>
              </div>
              <div style={{fontFamily:'Plus Jakarta Sans,sans-serif',fontSize:20,fontWeight:800,color:B.g900}}>Sale Recorded!</div>
              <div style={{fontSize:13,color:B.g400,textAlign:'center'}}>Payment via {payMethod} confirmed</div>
              <button onClick={resetSale} style={{marginTop:8,border:'none',cursor:'pointer',background:B.navy,color:'#fff',borderRadius:14,padding:'14px 32px',fontSize:14,fontWeight:700,fontFamily:'Plus Jakarta Sans,sans-serif'}}>New Sale</button>
            </div>
          ) : (
            <>
              {/* Search */}
              <div style={{padding:'12px 16px 8px',flexShrink:0}}>
                <div style={{background:B.white,borderRadius:14,padding:'10px 14px',display:'flex',alignItems:'center',gap:10,boxShadow:'0 1px 4px rgba(0,0,0,.06)'}}>
                  <Ic n="search" s={16} c={B.g400}/>
                  <input value={query} onChange={e=>setQuery(e.target.value)} placeholder="Search products…" style={{border:'none',outline:'none',background:'none',fontSize:13,color:B.g900,flex:1,fontFamily:'DM Sans,sans-serif'}}/>
                </div>
              </div>

              {/* Product grid */}
              <div style={{flex:1,overflow:'auto',padding:'0 16px'}} className="sb-hide">
                <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10,paddingBottom:cart.length?80:16}}>
                  {filtered.map(p=>{
                    const inCart = cart.find(x=>x.id===p.id);
                    const low = p.stock <= 8;
                    return (
                      <div key={p.id} style={{background:B.white,borderRadius:16,padding:'14px 12px',boxShadow:'0 1px 4px rgba(0,0,0,.06)',position:'relative',border:inCart?`2px solid ${B.navy}`:`2px solid transparent`}}>
                        {low&&<div style={{position:'absolute',top:8,right:8}}><Badge color={B.red} size={9}>Low</Badge></div>}
                        <div style={{fontSize:11,color:B.g400,marginBottom:4}}>{p.cat}</div>
                        <div style={{fontSize:13,fontWeight:700,color:B.g900,lineHeight:1.3,marginBottom:6}}>{p.name}</div>
                        <div style={{fontSize:15,fontWeight:800,color:B.navy,fontFamily:'Plus Jakarta Sans,sans-serif',marginBottom:10}}>{ghs(p.price)}</div>
                        {!inCart ? (
                          <button onClick={()=>addToCart(p)} style={{width:'100%',border:'none',cursor:'pointer',background:B.navy,color:'#fff',borderRadius:10,padding:'8px 0',fontSize:12,fontWeight:700,fontFamily:'Plus Jakarta Sans,sans-serif',display:'flex',alignItems:'center',justifyContent:'center',gap:6}}>
                            <Ic n="plus" s={13} c="#fff"/> Add
                          </button>
                        ) : (
                          <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',background:B.g50,borderRadius:10,overflow:'hidden'}}>
                            <button onClick={()=>removeOne(p.id)} style={{border:'none',cursor:'pointer',background:'none',padding:'8px 12px',color:B.navy,display:'flex',alignItems:'center'}}><Ic n="minus" s={14} c={B.navy} w={2.5}/></button>
                            <span style={{fontSize:13,fontWeight:800,color:B.navy,fontFamily:'Plus Jakarta Sans,sans-serif'}}>{inCart.qty}</span>
                            <button onClick={()=>addToCart(p)} style={{border:'none',cursor:'pointer',background:'none',padding:'8px 12px',color:B.navy,display:'flex',alignItems:'center'}}><Ic n="plus" s={14} c={B.navy} w={2.5}/></button>
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* Cart strip */}
              {cart.length > 0 && (
                <div style={{position:'absolute',bottom:56,left:0,right:0,padding:'12px 16px',background:'rgba(246,247,250,.96)',backdropFilter:'blur(8px)',borderTop:`1px solid ${B.g100}`}}>
                  <div style={{display:'flex',alignItems:'center',justifyContent:'space-between'}}>
                    <div>
                      <span style={{fontSize:12,color:B.g600}}>{cartCount} item{cartCount!==1?'s':''} &nbsp;</span>
                      <span style={{fontSize:15,fontWeight:800,color:B.navy,fontFamily:'Plus Jakarta Sans,sans-serif'}}>{ghs(cartTotal)}</span>
                    </div>
                    <button onClick={()=>setPaying(true)} style={{border:'none',cursor:'pointer',background:B.navy,color:'#fff',borderRadius:12,padding:'10px 22px',fontSize:13,fontWeight:700,fontFamily:'Plus Jakarta Sans,sans-serif'}}>
                      Pay Now →
                    </button>
                  </div>
                </div>
              )}

              {/* Payment modal */}
              {paying && (
                <div style={{position:'absolute',inset:0,background:'rgba(26,39,68,.6)',backdropFilter:'blur(6px)',display:'flex',alignItems:'flex-end',zIndex:10}} onClick={()=>setPaying(false)}>
                  <div style={{background:B.white,borderRadius:'24px 24px 0 0',width:'100%',padding:'24px 20px 32px'}} onClick={e=>e.stopPropagation()}>
                    <div style={{fontFamily:'Plus Jakarta Sans,sans-serif',fontSize:17,fontWeight:800,color:B.g900,marginBottom:4}}>Confirm Payment</div>
                    <div style={{fontSize:13,color:B.g400,marginBottom:20}}>{cartCount} items &nbsp;·&nbsp; <span style={{fontWeight:700,color:B.navy}}>{ghs(cartTotal)}</span></div>
                    <div style={{display:'flex',gap:12,marginBottom:16}}>
                      {['Cash','MoMo'].map(m=>(
                        <button key={m} onClick={()=>confirmSale(m)} style={{flex:1,border:'none',cursor:'pointer',borderRadius:16,padding:'16px 0',fontSize:14,fontWeight:700,fontFamily:'Plus Jakarta Sans,sans-serif',background:m==='MoMo'?B.gold:B.navy,color:'#fff',boxShadow:m==='MoMo'?'0 4px 14px rgba(196,154,42,.4)':'0 4px 14px rgba(26,39,68,.3)'}}>
                          {m==='MoMo'?'📱 MoMo':'💵 Cash'}
                        </button>
                      ))}
                    </div>
                    <button onClick={()=>setPaying(false)} style={{width:'100%',border:'none',cursor:'pointer',background:B.g50,color:B.g600,borderRadius:12,padding:'12px 0',fontSize:13,fontWeight:600,fontFamily:'Plus Jakarta Sans,sans-serif'}}>Cancel</button>
                  </div>
                </div>
              )}
            </>
          )}
        </>
      )}

      {tab==='hist' && (
        <div style={{flex:1,overflow:'auto',padding:'14px 16px'}} className="sb-hide">
          <SLabel>Today's Transactions</SLabel>
          <div style={{display:'flex',flexDirection:'column',gap:8}}>
            {HISTORY.map((h,i)=>(
              <div key={i} style={{background:B.white,borderRadius:14,padding:'13px 14px',display:'flex',alignItems:'center',gap:12,boxShadow:'0 1px 3px rgba(0,0,0,.05)'}}>
                <div style={{width:38,height:38,borderRadius:12,background:h.method==='MoMo'?B.goldL:B.greenL,display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,fontSize:16}}>
                  {h.method==='MoMo'?'📱':'💵'}
                </div>
                <div style={{flex:1}}>
                  <div style={{fontSize:13,fontWeight:600,color:B.g900}}>{h.name}</div>
                  <div style={{fontSize:11,color:B.g400,marginTop:2}}>{h.items} items &nbsp;·&nbsp; {h.time}</div>
                </div>
                <div style={{textAlign:'right'}}>
                  <div style={{fontSize:14,fontWeight:700,color:B.green}}>{ghs(h.total)}</div>
                  <Badge color={h.method==='MoMo'?B.gold:B.green} size={10}>{h.method}</Badge>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </HeroLayout>
  );
}

Object.assign(window, {SalesScreen});
