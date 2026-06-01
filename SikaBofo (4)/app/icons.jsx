/* icons.jsx — one consistent stroke icon family (feather-style, 1.8 stroke) */
const Icon = ({ name, size = 22, sw = 1.8, color = 'currentColor', fill = 'none', style }) => {
  const P = ICON_PATHS[name] || ICON_PATHS.dot;
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={fill} stroke={color}
      strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" style={style}>
      {P}
    </svg>
  );
};

const ICON_PATHS = {
  dot: <circle cx="12" cy="12" r="2" />,
  home: <><path d="M3 10.5 12 3l9 7.5" /><path d="M5 9.5V20a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V9.5" /><path d="M9.5 21v-6h5v6" /></>,
  sales: <><rect x="3" y="8" width="18" height="12" rx="2" /><path d="M3 11h18" /><path d="M7 4h10l1 4H6z" /><circle cx="8.5" cy="15.5" r="1" /></>,
  inventory: <><path d="M3 7.5 12 3l9 4.5v9L12 21 3 16.5z" /><path d="M3 7.5 12 12l9-4.5" /><path d="M12 12v9" /></>,
  grid: <><rect x="3" y="3" width="7.5" height="7.5" rx="1.6" /><rect x="13.5" y="3" width="7.5" height="7.5" rx="1.6" /><rect x="3" y="13.5" width="7.5" height="7.5" rx="1.6" /><rect x="13.5" y="13.5" width="7.5" height="7.5" rx="1.6" /></>,
  bell: <><path d="M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9" /><path d="M13.7 21a2 2 0 0 1-3.4 0" /></>,
  insight: <><path d="M21 21H3V3" /><path d="M7 15l4-4 3 3 5-6" /></>,
  plus: <><path d="M12 5v14" /><path d="M5 12h14" /></>,
  search: <><circle cx="11" cy="11" r="7" /><path d="m21 21-4.3-4.3" /></>,
  chevron: <path d="m9 6 6 6-6 6" />,
  back: <path d="m15 6-6 6 6 6" />,
  cart: <><circle cx="9" cy="20" r="1.4" /><circle cx="18" cy="20" r="1.4" /><path d="M2.5 3h2.2l2 12.5h11.3l1.7-9H6.2" /></>,
  receipt: <><path d="M5 21V4a1 1 0 0 1 1-1h12a1 1 0 0 1 1 1v17l-2.5-1.5L14 21l-2-1.5L10 21l-2.5-1.5z" /><path d="M9 7h6" /><path d="M9 11h6" /></>,
  debt: <><path d="M3 7h18v11a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z" /><path d="M3 7V5a1 1 0 0 1 1-1h12" /><circle cx="16" cy="13" r="2.2" /></>,
  restock: <><path d="M3 7.5 12 3l9 4.5v9L12 21 3 16.5z" /><path d="M12 12v9" /><path d="M3 7.5 12 12l9-4.5" /><path d="M16.5 5.2 7.5 9.8" /></>,
  expense: <><circle cx="12" cy="12" r="9" /><path d="M12 7v10" /><path d="M14.5 9.3c-.6-.8-1.6-1-2.5-1-1.2 0-2.2.6-2.2 1.7 0 2.4 5 1.2 5 3.7 0 1.2-1.1 1.8-2.3 1.8-1 0-2-.3-2.6-1.1" /></>,
  wallet: <><rect x="3" y="6" width="18" height="13" rx="2.5" /><path d="M3 10h18" /><circle cx="16.5" cy="14" r="1.2" /></>,
  lowstock: <><path d="M12 3 2.5 20h19z" /><path d="M12 10v4" /><path d="M12 17.5v.2" /></>,
  box: <><rect x="3.5" y="6" width="17" height="14" rx="2" /><path d="M3.5 10h17" /><path d="M9 6V4.5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1V6" /></>,
  user: <><circle cx="12" cy="8" r="4" /><path d="M4 20c0-3.5 3.6-6 8-6s8 2.5 8 6" /></>,
  users: <><circle cx="9" cy="8" r="3.4" /><path d="M2.5 19c0-3 2.9-5 6.5-5s6.5 2 6.5 5" /><path d="M16 5.2a3.4 3.4 0 0 1 0 6.4" /><path d="M18 14.2c2.3.5 4 2.1 4 4.8" /></>,
  userplus: <><circle cx="10" cy="8" r="3.6" /><path d="M3 20c0-3.3 3.1-5.5 7-5.5" /><path d="M18 9v6" /><path d="M15 12h6" /></>,
  phone: <path d="M5 3.5h3l1.5 4-2 1.5a11 11 0 0 0 5 5l1.5-2 4 1.5v3a1.5 1.5 0 0 1-1.6 1.5C10.8 18.8 5.2 13.2 4.5 5.6A1.5 1.5 0 0 1 6 4" />,
  clock: <><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3.5 2" /></>,
  report: <><path d="M21 21H3V3" /><rect x="6.5" y="11" width="3" height="7" rx="1" /><rect x="11.5" y="7" width="3" height="11" rx="1" /><rect x="16.5" y="13" width="3" height="5" rx="1" /></>,
  settings: <><circle cx="12" cy="12" r="3" /><path d="M19.4 13.5a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-2.9 1.2v.2a2 2 0 0 1-4 0v-.1a1.7 1.7 0 0 0-2.9-1.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0-1.2-2.9H3a2 2 0 0 1 0-4h.1a1.7 1.7 0 0 0 1.3-2.9l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.9.3 1.7 1.7 0 0 0 1-1.5V3a2 2 0 0 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.9-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.5 1H21a2 2 0 0 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z" /></>,
  store: <><path d="M4 9.5 5.2 4h13.6L20 9.5" /><path d="M4 9.5h16v9a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1z" /><path d="M4 9.5a2.2 2.2 0 0 0 4 0 2.2 2.2 0 0 0 4 0 2.2 2.2 0 0 0 4 0 2.2 2.2 0 0 0 4 0" /></>,
  check: <path d="m5 12.5 4.5 4.5L19 7" />,
  x: <><path d="M6 6l12 12" /><path d="M18 6 6 18" /></>,
  note: <><path d="M4 6h16" /><path d="M4 11h16" /><path d="M4 16h9" /></>,
  trend: <><path d="M3 17 9 11l4 4 8-8" /><path d="M16 7h5v5" /></>,
  coins: <><ellipse cx="9" cy="6" rx="6" ry="2.6" /><path d="M3 6v5c0 1.4 2.7 2.6 6 2.6s6-1.2 6-2.6V6" /><path d="M3 11v5c0 1.4 2.7 2.6 6 2.6 1 0 2-.1 2.8-.3" /><ellipse cx="16.5" cy="14" rx="5" ry="2.3" /><path d="M11.5 14v4c0 1.2 2.2 2.2 5 2.2s5-1 5-2.2v-4" /></>,
  scan: <><path d="M4 8V6a2 2 0 0 1 2-2h2" /><path d="M16 4h2a2 2 0 0 1 2 2v2" /><path d="M20 16v2a2 2 0 0 1-2 2h-2" /><path d="M8 20H6a2 2 0 0 1-2-2v-2" /><path d="M7 12h10" /></>,
  filter: <><path d="M4 5h16" /><path d="M7 12h10" /><path d="M10 19h4" /></>,
  arrowright: <><path d="M5 12h14" /><path d="m13 6 6 6-6 6" /></>,
  tag: <><path d="M3 11.5V5a2 2 0 0 1 2-2h6.5a2 2 0 0 1 1.4.6l7 7a2 2 0 0 1 0 2.8l-6.5 6.5a2 2 0 0 1-2.8 0l-7-7A2 2 0 0 1 3 11.5z" /><circle cx="7.5" cy="7.5" r="1.3" /></>,
  edit: <><path d="M4 20h4L19 9l-4-4L4 16z" /><path d="M14 5l4 4" /></>,
  refresh: <><path d="M21 12a9 9 0 1 1-2.6-6.4" /><path d="M21 4v4h-4" /></>,
  building: <><rect x="4" y="3" width="16" height="18" rx="1.5" /><path d="M8 7h2" /><path d="M14 7h2" /><path d="M8 11h2" /><path d="M14 11h2" /><path d="M8 15h2" /><path d="M14 15h2" /><path d="M10 21v-3h4v3" /></>,
  chat: <><path d="M4 5h16a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H9l-4 3.5V17H4a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1z" /></>,
  card: <><rect x="3" y="5" width="18" height="14" rx="2.5" /><path d="M3 10h18" /><path d="M6.5 15h4" /></>,
  history: <><path d="M3 12a9 9 0 1 0 3-6.7L3 8" /><path d="M3 4v4h4" /><path d="M12 8v4l3 2" /></>,
  sync: <><path d="M4 11a8 8 0 0 1 13.5-4.5L20 9" /><path d="M20 4v5h-5" /><path d="M20 13a8 8 0 0 1-13.5 4.5L4 15" /><path d="M4 20v-5h5" /></>,
  shield: <><path d="M12 3 5 6v5c0 4.4 3 7.7 7 9 4-1.3 7-4.6 7-9V6z" /><path d="m9 12 2 2 4-4" /></>,
  bell2: <><path d="M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9" /><path d="M13.7 21a2 2 0 0 1-3.4 0" /></>,
  sliders: <><path d="M4 7h10" /><path d="M18 7h2" /><circle cx="16" cy="7" r="2" /><path d="M4 17h2" /><path d="M10 17h10" /><circle cx="8" cy="17" r="2" /></>,
  message: <><path d="M21 11.5a8.4 8.4 0 0 1-9 8.3 9 9 0 0 1-3.8-.7L3 21l1.3-3.9A8.3 8.3 0 0 1 3.5 11 8.4 8.4 0 0 1 12 3a8.4 8.4 0 0 1 9 8.5z" /></>,
  lock: <><rect x="4.5" y="10.5" width="15" height="10" rx="2.2" /><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3" /><circle cx="12" cy="15.2" r="1.3" /></>,
  eye: <><path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z" /><circle cx="12" cy="12" r="3" /></>,
  eyeoff: <><path d="M9.9 5.2A9.6 9.6 0 0 1 12 5c6 0 9.5 7 9.5 7a16 16 0 0 1-3.2 3.9" /><path d="M6.3 6.4A16 16 0 0 0 2.5 12S6 19 12 19a9.3 9.3 0 0 0 4-.9" /><path d="m4 4 16 16" /></>,
};

Object.assign(window, { Icon });
