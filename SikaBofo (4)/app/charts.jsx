/* charts.jsx — lightweight SVG chart primitives (brand-consistent) */

const LineChart = ({ labels, series, height = 148 }) => {
  const W = 324, H = height, padL = 6, padR = 6, padT = 12, padB = 8;
  const n = labels.length;
  const max = Math.max(1, ...series.flatMap(s => s.data)) * 1.18;
  const x = i => padL + (i * (W - padL - padR)) / Math.max(1, n - 1);
  const y = v => padT + (1 - v / max) * (H - padT - padB);
  const path = d => d.map((v, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)} ${y(v).toFixed(1)}`).join(' ');
  const area = d => `${path(d)} L${x(n - 1).toFixed(1)} ${H - padB} L${x(0).toFixed(1)} ${H - padB} Z`;
  const grid = [0, 0.33, 0.66, 1].map(t => padT + t * (H - padT - padB));
  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" height={height} style={{ display: 'block', overflow: 'visible' }}>
      {grid.map((gy, i) => <line key={i} x1={padL} x2={W - padR} y1={gy} y2={gy} stroke="var(--line-soft)" strokeWidth="1" />)}
      {series.filter(s => s.area).map((s, i) => <path key={'a' + i} d={area(s.data)} fill={s.color} opacity="0.10" />)}
      {series.map((s, i) => <path key={'l' + i} d={path(s.data)} fill="none" stroke={s.color} strokeWidth="2.4" strokeLinejoin="round" strokeLinecap="round" strokeDasharray={s.dash ? '5 4' : 'none'} opacity={s.dash ? 0.9 : 1} />)}
      {series[0].data.map((v, j) => <circle key={'p' + j} cx={x(j)} cy={y(v)} r="2.7" fill="#fff" stroke={series[0].color} strokeWidth="1.8" />)}
    </svg>
  );
};

const ChartXAxis = ({ labels }) => (
  <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6, padding: '0 2px' }}>
    {labels.map((l, i) => <span key={i} style={{ fontSize: 11, color: 'var(--ink-3)', fontWeight: 600 }}>{l}</span>)}
  </div>
);

const Legend = ({ items }) => (
  <div style={{ display: 'flex', gap: 16, justifyContent: 'center', marginTop: 12, flexWrap: 'wrap' }}>
    {items.map((it, i) => (
      <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <span style={{ width: 9, height: 9, borderRadius: it.dash ? 1 : '50%', background: it.color }} />
        <span style={{ fontSize: 12, color: 'var(--ink-2)', fontWeight: 600 }}>{it.name}</span>
      </div>
    ))}
  </div>
);

const Donut = ({ segments, size = 132, thickness = 20, center }) => {
  const r = (size - thickness) / 2, c = 2 * Math.PI * r, cx = size / 2;
  const total = segments.reduce((s, x) => s + x.value, 0) || 1;
  let acc = 0;
  return (
    <div style={{ position: 'relative', width: size, height: size, flex: '0 0 auto' }}>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <circle cx={cx} cy={cx} r={r} fill="none" stroke="var(--line-soft)" strokeWidth={thickness} />
        {segments.map((seg, i) => {
          const frac = seg.value / total, dash = frac * c;
          const el = <circle key={i} cx={cx} cy={cx} r={r} fill="none" stroke={seg.color} strokeWidth={thickness}
            strokeDasharray={`${dash} ${c - dash}`} strokeDashoffset={-acc * c}
            transform={`rotate(-90 ${cx} ${cx})`} strokeLinecap="butt" />;
          acc += frac; return el;
        })}
      </svg>
      {center && <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>{center}</div>}
    </div>
  );
};

/* horizontal track bar used for payment methods & debt aging */
const TrackBar = ({ pct, color, height = 8 }) => (
  <div style={{ height, borderRadius: height, background: 'var(--line-soft)', overflow: 'hidden' }}>
    <div style={{ width: Math.max(2, pct) + '%', height: '100%', background: color, borderRadius: height, transition: 'width .4s' }} />
  </div>
);

Object.assign(window, { LineChart, ChartXAxis, Legend, Donut, TrackBar });
