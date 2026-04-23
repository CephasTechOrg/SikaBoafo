// StockScreen — Inventory management

const STOCK_ITEMS = [
  {id:1,  name:'Paracetamol 500mg', cat:'Medicine',  qty:8,   max:50, price:5.00,  unit:'tablets'},
  {id:2,  name:'Amoxicillin 250mg', cat:'Medicine',  qty:3,   max:40, price:12.00, unit:'packs'},
  {id:3,  name:'Antiseptic Cream',  cat:'Medicine',  qty:5,   max:30, price:8.50,  unit:'tubes'},
  {id:4,  name:'Vitamin C 1000mg',  cat:'Medicine',  qty:31,  max:60, price:18.00, unit:'bottles'},
  {id:5,  name:'Nivea Body Lotion', cat:'Personal',  qty:24,  max:60, price:24.00, unit:'bottles'},
  {id:6,  name:'Omo Detergent 1kg', cat:'Household', qty:7,   max:40, price:15.00, unit:'bags'},
  {id:7,  name:'Milo 400g',         cat:'Food',      qty:15,  max:50, price:20.00, unit:'tins'},
  {id:8,  name:'Fanta 330ml',       cat:'Drinks',    qty:48,  max:72, price:4.00,  unit:'bottles'},
  {id:9,  name:'Indomie Noodles',   cat:'Food',      qty:0,   max:60, price:3.50,  unit:'packs'},
  {id:10, name:'Bread 700g',        cat:'Food',      qty:6,   max:20, price:6.00,  unit:'loaves'},
];

function StockScreen({data, onNav}) {
  const [filter, setFilter] = React.useState('all');
  const [adding, setAdding] = React.useState(false);
  const [restocking, setRestocking] = React.useState(null);
  const [addQtys, setAddQtys] = React.useState({});
  const [stockOverride, setStockOverride] = React.useState({});

  const items = STOCK_ITEMS.map(it => ({
    ...it,
    qty: it.qty + (stockOverride[it.id] || 0),
  }));

  const low   = items.filter(it => it.qty > 0 && it.qty <= 8);
  const out   = items.filter(it => it.qty === 0);
  const displayed = filter==='low' ? low : filter==='out' ? out : items;

  const totalSKUs  = items.length;
  const totalValue = items.reduce((s,it)=>s+it.qty*it.price, 0);

  const initials = data.name.split(' ').map(w=>w[0]).join('');

  const statusColor = (it) => it.qty===0 ? B.red : it.qty<=8 ? B.gold : B.green;
  const statusLabel = (it) => it.qty===0 ? 'Out' : it.qty<=8 ? 'Low' : 'OK';

  const doRestock = (id) => {
    const qty = parseInt(addQtys[id]||0);
    if(qty>0) setStockOverride(s=>({...s,[id]:(s[id]||0)+qty}));
    setAddQtys(a=>({...a,[id]:''}));
    setRestocking(null);
  };

  return (
    <HeroLayout navScreen="stock" onNav={onNav} hero={
      <>
        <HeroBar title="Inventory" initials={initials}/>
        <div style={{display:'flex',alignItems:'flex-end',justifyContent:'space-between',marginBottom:18}}>
          <div>
            <div style={{fontSize:11,color:'rgba(255,255,255,.4)',fontWeight:600,letterSpacing:'.07em',textTransform:'uppercase',marginBottom:6}}>Stock Value</div>
            <div style={{fontSize:36,fontWeight:800,color:'#fff',fontFamily:'Plus Jakarta Sans,sans-serif',letterSpacing:'-0.02em',lineHeight:1}}>{ghs(totalValue)}</div>
            <div style={{marginTop:8,display:'flex',gap:6,alignItems:'center'}}>
              <span style={{fontSize:11,color:'rgba(255,255,255,.5)'}}>{totalSKUs} products tracked</span>
            </div>
          </div>
          <div style={{display:'flex',gap:8}}>
            <div style={{background:'rgba(255,255,255,.08)',borderRadius:12,padding:'10px 14px',textAlign:'center',border:'1px solid rgba(255,255,255,.08)'}}>
              <div style={{fontSize:16,fontWeight:800,color:'#FF8080',fontFamily:'Plus Jakarta Sans,sans-serif'}}>{low.length}</div>
              <div style={{fontSize:9,color:'rgba(255,255,255,.4)',marginTop:2}}>Low Stock</div>
            </div>
            <div style={{background:'rgba(255,255,255,.08)',borderRadius:12,padding:'10px 14px',textAlign:'center',border:'1px solid rgba(255,255,255,.08)'}}>
              <div style={{fontSize:16,fontWeight:800,color:B.red,fontFamily:'Plus Jakarta Sans,sans-serif'}}>{out.length}</div>
              <div style={{fontSize:9,color:'rgba(255,255,255,.4)',marginTop:2}}>Out of Stock</div>
            </div>
          </div>
        </div>
      </>
    }>
      {/* Filter tabs */}
      <div style={{display:'flex',padding:'14px 16px 0',gap:8,flexShrink:0}}>
        {[['all','All'],['low','Low Stock'],['out','Out of Stock']].map(([k,l])=>(
          <button key={k} onClick={()=>setFilter(k)} style={{border:'none',cursor:'pointer',padding:'7px 14px',borderRadius:100,fontSize:12,fontWeight:700,background:filter===k?B.navy:B.g50,color:filter===k?'#fff':B.g400,fontFamily:'Plus Jakarta Sans,sans-serif',transition:'all .15s',whiteSpace:'nowrap'}}>
            {l}{k!=='all'&&<span style={{marginLeft:5,background:filter===k?'rgba(255,255,255,.2)':B.g200,borderRadius:100,padding:'0 5px',fontSize:10}}>{k==='low'?low.length:out.length}</span>}
          </button>
        ))}
      </div>

      {/* Product list */}
      <div style={{flex:1,overflow:'auto',padding:'14px 16px'}} className="sb-hide">
        <SLabel action="+ Add Product" onAction={()=>setAdding(true)}>
          {filter==='all'?'All Products':filter==='low'?'Low Stock Items':'Out of Stock'}
        </SLabel>

        {displayed.length===0 && (
          <div style={{textAlign:'center',padding:'32px 0'}}>
            <div style={{fontSize:36,marginBottom:10}}>✅</div>
            <div style={{fontSize:14,fontWeight:700,color:B.g900,fontFamily:'Plus Jakarta Sans,sans-serif'}}>No items here</div>
            <div style={{fontSize:12,color:B.g400,marginTop:4}}>All stock levels look good!</div>
          </div>
        )}

        <div style={{display:'flex',flexDirection:'column',gap:10}}>
          {displayed.map(it=>{
            const pct = Math.min((it.qty/it.max)*100,100);
            const sc = statusColor(it);
            const isRestocking = restocking===it.id;
            return (
              <div key={it.id} style={{background:B.white,borderRadius:16,padding:'14px 16px',boxShadow:'0 1px 4px rgba(0,0,0,.06)',border:it.qty<=8?`1.5px solid ${sc}20`:'1.5px solid transparent'}}>
                <div style={{display:'flex',alignItems:'flex-start',gap:12,marginBottom:10}}>
                  <div style={{width:40,height:40,borderRadius:12,background:sc+'15',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
                    <span style={{fontSize:18}}>{it.cat==='Medicine'?'💊':it.cat==='Personal'?'🧴':it.cat==='Food'?'🥫':it.cat==='Drinks'?'🥤':'🧹'}</span>
                  </div>
                  <div style={{flex:1}}>
                    <div style={{fontSize:13,fontWeight:700,color:B.g900,lineHeight:1.3}}>{it.name}</div>
                    <div style={{fontSize:11,color:B.g400,marginTop:2}}>{it.cat} &nbsp;·&nbsp; {ghs(it.price)} each</div>
                  </div>
                  <div style={{textAlign:'right'}}>
                    <div style={{fontSize:16,fontWeight:800,color:it.qty===0?B.red:B.g900,fontFamily:'Plus Jakarta Sans,sans-serif'}}>{it.qty}<span style={{fontSize:10,fontWeight:400,color:B.g400,marginLeft:2}}>{it.unit}</span></div>
                    <Badge color={sc} size={9}>{statusLabel(it)}</Badge>
                  </div>
                </div>

                {/* Stock bar */}
                <div style={{height:4,borderRadius:2,background:B.g100,marginBottom:isRestocking?12:0,overflow:'hidden'}}>
                  <div style={{height:'100%',borderRadius:2,background:sc,width:`${pct}%`,transition:'width .5s'}}/>
                </div>

                {/* Restock form */}
                {!isRestocking ? (
                  it.qty <= 8 && (
                    <div style={{marginTop:10}}>
                      <button onClick={()=>setRestocking(it.id)} style={{border:`1.5px solid ${sc}`,cursor:'pointer',background:sc+'10',color:sc,borderRadius:10,padding:'8px 16px',fontSize:12,fontWeight:700,fontFamily:'Plus Jakarta Sans,sans-serif',width:'100%',display:'flex',alignItems:'center',justifyContent:'center',gap:6}}>
                        <Ic n="plus" s={13} c={sc}/> Restock {it.name.split(' ')[0]}
                      </button>
                    </div>
                  )
                ) : (
                  <div style={{background:B.g50,borderRadius:10,padding:10,display:'flex',gap:8,alignItems:'center'}}>
                    <span style={{fontSize:12,color:B.g600}}>Add units:</span>
                    <input type="number" value={addQtys[it.id]||''} onChange={e=>setAddQtys(a=>({...a,[it.id]:e.target.value}))} placeholder="e.g. 20" style={{flex:1,border:`1.5px solid ${B.g200}`,borderRadius:8,padding:'7px 10px',fontSize:13,fontWeight:700,color:B.g900,outline:'none',background:B.white,fontFamily:'Plus Jakarta Sans,sans-serif'}}/>
                    <button onClick={()=>doRestock(it.id)} style={{border:'none',cursor:'pointer',background:B.green,color:'#fff',borderRadius:8,padding:'8px 14px',fontSize:12,fontWeight:700,fontFamily:'Plus Jakarta Sans,sans-serif'}}>Save</button>
                    <button onClick={()=>setRestocking(null)} style={{border:'none',cursor:'pointer',background:B.g100,color:B.g600,borderRadius:8,padding:'8px 10px',fontSize:12,fontFamily:'Plus Jakarta Sans,sans-serif'}}>✕</button>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>

      {/* Add product modal */}
      {adding && (
        <div style={{position:'absolute',inset:0,background:'rgba(26,39,68,.6)',backdropFilter:'blur(6px)',display:'flex',alignItems:'flex-end',zIndex:10}} onClick={()=>setAdding(false)}>
          <div style={{background:B.white,borderRadius:'24px 24px 0 0',width:'100%',padding:'24px 20px 32px'}} onClick={e=>e.stopPropagation()}>
            <div style={{fontFamily:'Plus Jakarta Sans,sans-serif',fontSize:17,fontWeight:800,color:B.g900,marginBottom:4}}>Add New Product</div>
            <div style={{fontSize:12,color:B.g400,marginBottom:20}}>Fill in the details below</div>
            {['Product Name','Category','Selling Price (₵)','Opening Stock'].map((lbl,i)=>(
              <div key={i} style={{marginBottom:12}}>
                <div style={{fontSize:11,fontWeight:700,color:B.g400,textTransform:'uppercase',letterSpacing:'.06em',marginBottom:5}}>{lbl}</div>
                <input placeholder={lbl} style={{width:'100%',border:`1.5px solid ${B.g100}`,borderRadius:12,padding:'11px 14px',fontSize:13,color:B.g900,outline:'none',background:B.bg,fontFamily:'DM Sans,sans-serif'}}/>
              </div>
            ))}
            <div style={{display:'flex',gap:10,marginTop:8}}>
              <button style={{flex:1,border:'none',cursor:'pointer',background:B.navy,color:'#fff',borderRadius:14,padding:'14px 0',fontSize:14,fontWeight:700,fontFamily:'Plus Jakarta Sans,sans-serif'}}>Add Product</button>
              <button onClick={()=>setAdding(false)} style={{border:'none',cursor:'pointer',background:B.g50,color:B.g600,borderRadius:14,padding:'14px 20px',fontSize:14,fontWeight:700,fontFamily:'Plus Jakarta Sans,sans-serif'}}>Cancel</button>
            </div>
          </div>
        </div>
      )}
    </HeroLayout>
  );
}

Object.assign(window, {StockScreen});
