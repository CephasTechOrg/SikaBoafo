/* screens-notifications.jsx — Notifications center */

const NOTIF_FILTERS = ['All', 'Unread', 'Debts', 'Stock', 'Sales'];
const FILTER_MATCH = {
  All: () => true,
  Unread: n => n.unread,
  Debts: n => n.type === 'debt' || n.type === 'payment',
  Stock: n => n.type === 'stock',
  Sales: n => n.type === 'sale',
};

const NotifRow = ({ n, onNav, onRead }) => {
  const tone = NOTIF_TONE[n.type] || NOTIF_TONE.system;
  return (
    <button onClick={() => { onRead(n.id); onNav && onNav(n.go); }} className="row"
      style={{ width: '100%', alignItems: 'flex-start', cursor: 'pointer', textAlign: 'left', border: 'none', background: 'none', padding: '14px 14px' }}>
      <div style={{ width: 40, height: 40, borderRadius: 11, flex: '0 0 auto', background: tone.bg, color: tone.fg, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Icon name={n.icon} size={19} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
          <span style={{ flex: 1, minWidth: 0, fontSize: 14.5, fontWeight: n.unread ? 700 : 600, color: n.unread ? 'var(--ink)' : 'var(--ink-2)' }}>{n.title}</span>
          <span style={{ flex: '0 0 auto', fontSize: 11.5, color: 'var(--ink-3)', fontWeight: 600 }}>{n.time}</span>
        </div>
        <div style={{ fontSize: 13, color: 'var(--ink-2)', marginTop: 3, lineHeight: 1.4, textWrap: 'pretty' }}>{n.body}</div>
      </div>
      <span style={{ width: 8, height: 8, borderRadius: '50%', flex: '0 0 auto', alignSelf: 'center', background: n.unread ? 'var(--green-600)' : 'transparent' }} />
    </button>
  );
};

const Notifications = ({ onNav, onBack }) => {
  const [filter, setFilter] = React.useState('All');
  const [items, setItems] = React.useState(NOTIFICATIONS);
  const markRead = (id) => setItems(arr => arr.map(n => n.id === id ? { ...n, unread: false } : n));
  const markAll = () => setItems(arr => arr.map(n => ({ ...n, unread: false })));

  const unread = items.filter(n => n.unread).length;
  const visible = items.filter(FILTER_MATCH[filter]);
  const groups = ['Today', 'Yesterday', 'Earlier'].map(g => ({ g, rows: visible.filter(n => n.group === g) })).filter(x => x.rows.length);

  return (
    <Screen nav={<BottomNav active="dashboard" onNav={onNav} />}
      hero={
        <TitleHero title="Notifications"
          subtitle={unread ? `${unread} unread update${unread > 1 ? 's' : ''}` : 'You\u2019re all caught up'}
          onBack={onBack}
          right={<HeaderIconBtn icon="settings" onClick={() => onNav('settings')} />} />
      }>
      <div className="chiprow">
        {NOTIF_FILTERS.map(f => {
          const n = items.filter(FILTER_MATCH[f]).length;
          return (
            <div key={f} className="chip" data-on={filter === f} onClick={() => setFilter(f)}>
              {f}{f !== 'All' && <span className="chip__count">{n}</span>}
            </div>
          );
        })}
      </div>

      {/* mark all read — light inline action */}
      {unread > 0 && (
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 18 }}>
          <span style={{ fontSize: 13, color: 'var(--ink-2)', fontWeight: 500 }}><b style={{ color: 'var(--ink)', fontWeight: 700 }}>{unread}</b> unread</span>
          <button onClick={markAll} style={{ flex: '0 0 auto', whiteSpace: 'nowrap', border: 'none', background: 'none', cursor: 'pointer', fontSize: 13, fontWeight: 700, color: 'var(--green-700)', display: 'inline-flex', alignItems: 'center', gap: 5, padding: 0 }}>
            <Icon name="check" size={15} sw={2.2} /> Mark all read
          </button>
        </div>
      )}

      {groups.length === 0 ? (
        <div className="card" style={{ marginTop: 16 }}>
          <EmptyState icon="bell" title="Nothing here yet" sub={filter === 'Unread' ? 'No unread notifications — you\u2019re all caught up.' : 'New activity will show up here as it happens.'} minH={180} />
        </div>
      ) : groups.map(({ g, rows }) => (
        <div key={g} style={{ marginTop: g === groups[0].g ? 18 : 22 }}>
          <div className="sec-label" style={{ marginBottom: 10 }}>{g}</div>
          <div className="card" style={{ padding: '2px 0' }}>
            {rows.map(n => <NotifRow key={n.id} n={n} onNav={onNav} onRead={markRead} />)}
          </div>
        </div>
      ))}
      <div style={{ height: 8 }} />
    </Screen>
  );
};

Object.assign(window, { Notifications });
