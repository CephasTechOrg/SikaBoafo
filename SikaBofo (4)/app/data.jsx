/* data.jsx — shared business data for SikaBofo */
const IMG = 'assets/products/';

const PRODUCTS = [
  { id: 'indomie', name: 'Indomie',      price: 7,  cat: 'Grocery',   stock: 156, sku: 'GRC-IND-01', img: IMG + 'indomie.png',    sold: 31, low: false, size: 'M-S'   },
  { id: 'malt',    name: 'Malt',         price: 20, cat: 'Drinks',    stock: 18,  sku: 'DRK-MLT-02', img: IMG + 'malt.png',       sold: 11, low: true,  size: '330ml' },
  { id: 'geisha',  name: 'Geisha Soap',  price: 11, cat: 'Household',  stock: 22,  sku: 'HHD-GSH-03', img: IMG + 'geisha_soap.png',sold: 9,  low: false, size: 'Bar'   },
  { id: 'gari',    name: 'Kivo Gari',    price: 5,  cat: 'Grocery',   stock: 50,  sku: 'GRC-GAR-04', img: IMG + 'kivo_gari.png',  sold: 14, low: false, size: '1kg'   },
  { id: 'milk',    name: 'Ideal Milk',   price: 8,  cat: 'Milk',      stock: 6,   sku: 'MLK-IDL-05', img: IMG + 'idealmilk.png',  sold: 7,  low: true,  size: 'XXL'   },
  { id: 'milo',    name: 'Milo',         price: 25, cat: 'Drinks',    stock: 34,  sku: 'DRK-MLO-06', img: IMG + 'milo.png',       sold: 6,  low: false, size: '400g'  },
];

const byId = (id) => PRODUCTS.find(p => p.id === id);

const TOP_SELLING = [
  { p: byId('indomie'), units: 31, revenue: 217 },
  { p: byId('malt'),    units: 11, revenue: 220 },
  { p: byId('gari'),    units: 14, revenue: 70  },
];

const ACTIVITY = [
  { id: 'a1', title: 'Sale · 2 items', sub: 'Indomie, Malt', amt: 40,  time: '5:42 PM', dir: 'in',  pay: 'Cash'   },
  { id: 'a2', title: 'Repayment',      sub: 'Cephas · INV-0026', amt: 50,  time: '3:10 PM', dir: 'in',  pay: 'MoMo'   },
  { id: 'a3', title: 'Restock',        sub: 'Ideal Milk · +24', amt: 96,  time: '1:25 PM', dir: 'out', pay: 'Stock'  },
  { id: 'a4', title: 'Sale · 1 item',  sub: 'Geisha Soap',      amt: 11,  time: '11:08 AM',dir: 'in',  pay: 'Cash'   },
];

const CUSTOMERS = [
  { id: 'c1', name: 'Cephas Owusu',   phone: '024 411 0026', debt: 300, purchases: 1240, last: 'Today',     tag: 'Owing',   init: 'CO' },
  { id: 'c2', name: 'Ama Serwaa',     phone: '020 778 5510', debt: 0,   purchases: 860,  last: '2 days ago',tag: 'Regular', init: 'AS' },
  { id: 'c3', name: 'Kwame Mensah',   phone: '055 320 9981', debt: 145, purchases: 540,  last: 'Yesterday', tag: 'Owing',   init: 'KM' },
  { id: 'c4', name: 'Akosua Boateng', phone: '027 654 2210', debt: 0,   purchases: 1980, last: 'Today',     tag: 'Regular', init: 'AB' },
  { id: 'c5', name: 'Yaw Asante',     phone: '050 119 7732', debt: 0,   purchases: 210,  last: '1 week ago',tag: 'Active',  init: 'YA' },
  { id: 'c6', name: 'Efua Nyarko',    phone: '024 880 3345', debt: 60,  purchases: 430,  last: '3 days ago',tag: 'Owing',   init: 'EN' },
];

const DEBTS = [
  { id: 'd1', name: 'Cephas Owusu',   init: 'CO', inv: 'INV-2026-0026', amt: 300, due: '20 Jun 2026', status: 'Overdue', phone: '024 411 0026' },
  { id: 'd2', name: 'Kwame Mensah',   init: 'KM', inv: 'INV-2026-0031', amt: 145, due: '02 Jun 2026', status: 'Unpaid',  phone: '055 320 9981' },
  { id: 'd3', name: 'Efua Nyarko',    init: 'EN', inv: 'INV-2026-0029', amt: 60,  due: '08 Jun 2026', status: 'Unpaid',  phone: '024 880 3345' },
  { id: 'd4', name: 'Ama Serwaa',     init: 'AS', inv: 'INV-2026-0025', amt: 0,   due: '24 May 2026', status: 'Paid',    phone: '020 778 5510' },
  { id: 'd5', name: 'Akosua Boateng', init: 'AB', inv: 'INV-2026-0022', amt: 0,   due: '18 May 2026', status: 'Paid',    phone: '027 654 2210' },
];

const REPAYMENTS = [
  { id: 'r1', name: 'Cephas Owusu', init: 'CO', amt: 50,  when: 'Today · 3:10 PM' },
  { id: 'r2', name: 'Akosua Boateng', init: 'AB', amt: 220, when: 'Yesterday' },
];

/* ---------- notifications ---------- */
const NOTIFICATIONS = [
  { id: 'n1', type: 'debt',    icon: 'debt',     title: 'Debt overdue',       body: "Cephas Owusu's balance of ₵300.00 is past due (20 Jun).", time: '2:42 PM',  group: 'Today', unread: true, go: 'debts' },
  { id: 'n2', type: 'payment', icon: 'wallet',   title: 'Repayment received', body: 'Cephas Owusu paid ₵50.00 via Mobile Money.',               time: '3:10 PM',  group: 'Today', unread: true, go: 'debts' },
  { id: 'n3', type: 'stock',   icon: 'lowstock', title: 'Low stock alert',    body: 'Ideal Milk is down to 6 units. Consider restocking.',     time: '1:25 PM',  group: 'Today', unread: true, go: 'inventory' },
  { id: 'n4', type: 'sale',    icon: 'sales',    title: 'Sale completed',     body: 'New sale of ₵40.00 — Indomie ×3, Malt ×1.',               time: '11:08 AM', group: 'Today', unread: true, go: 'sales' },
  { id: 'n5', type: 'stock',   icon: 'lowstock', title: 'Low stock alert',    body: 'Malt is down to 18 units.',                               time: '9:30 AM',  group: 'Today', unread: true, go: 'inventory' },
  { id: 'n6', type: 'report',  icon: 'report',   title: 'Weekly report ready',body: 'Your sales summary for last week is available.',           time: '8:00 AM',  group: 'Today', unread: true, go: 'reports' },
  { id: 'n7', type: 'payment', icon: 'coins',    title: 'Repayment received', body: 'Akosua Boateng paid ₵220.00 in full. Debt settled.',      time: 'Yesterday', group: 'Yesterday', unread: false, go: 'debts' },
  { id: 'n8', type: 'sale',    icon: 'sales',    title: 'Big sale recorded',  body: 'Sale of ₵82.00 — your largest this week.',                time: 'Yesterday', group: 'Yesterday', unread: false, go: 'sales' },
  { id: 'n9', type: 'debt',    icon: 'debt',     title: 'Debt due soon',      body: 'Kwame Mensah owes ₵145.00, due 02 Jun.',                  time: '2 days ago', group: 'Earlier', unread: false, go: 'debts' },
  { id: 'n10', type: 'system', icon: 'userplus', title: 'New customer added', body: 'Yaw Asante was added to your customer list.',              time: '3 days ago', group: 'Earlier', unread: false, go: 'customers' },
];
const NOTIF_TONE = {
  debt:    { fg: 'var(--danger)',    bg: 'var(--danger-tint)' },
  payment: { fg: 'var(--green-700)', bg: 'var(--green-tint)' },
  stock:   { fg: 'var(--warn)',      bg: 'var(--warn-tint)' },
  sale:    { fg: 'var(--green-700)', bg: 'var(--green-tint)' },
  report:  { fg: 'var(--info)',      bg: 'var(--info-tint)' },
  system:  { fg: 'var(--ink-2)',     bg: '#F1F3F5' },
};

const money = (n) => '₵' + Number(n).toLocaleString('en-GH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const CAT_COLOR = {
  Drinks:    { bg: '#EAF1FB', fg: '#2563A8' },
  Grocery:   { bg: '#EAF6EF', fg: '#0F7A4A' },
  Household:  { bg: '#F3EEFB', fg: '#7C4DBE' },
  Milk:      { bg: '#FBF4E8', fg: '#B07A1E' },
};

/* ---------- reports / analytics ---------- */
const REPORTS = {
  'Today':      { sales: 80,   expenses: 26,   profit: 54,   recv: 505, dS: '+12%', dE: '+4%',  up: true },
  'This Week':  { sales: 1240, expenses: 430,  profit: 810,  recv: 505, dS: '+8%',  dE: '-3%',  up: true },
  'This Month': { sales: 5820, expenses: 2140, profit: 3680, recv: 505, dS: '+15%', dE: '+6%',  up: true },
};
const TREND = {
  'Today':      { labels: ['9a', '11a', '1p', '3p', '5p', '7p'], sales: [10, 18, 12, 22, 9, 9], expenses: [4, 6, 3, 8, 2, 3] },
  'This Week':  { labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'], sales: [160, 210, 140, 260, 300, 180, 0], expenses: [60, 80, 50, 90, 70, 80, 0] },
  'This Month': { labels: ['W1', 'W2', 'W3', 'W4'], sales: [1200, 1450, 1380, 1790], expenses: [520, 480, 560, 580] },
};
const EXPENSE_CATS = [
  { name: 'Inventory', amount: 980, color: '#0F7A4A' },
  { name: 'Transport', amount: 420, color: '#2F9E6A' },
  { name: 'Utilities', amount: 330, color: '#BE8A2C' },
  { name: 'Rent',      amount: 260, color: '#1F6B47' },
  { name: 'Salary',    amount: 150, color: '#9AA3AF' },
];
const PAYMENT_METHODS = [
  { name: 'Cash',         amount: 1240, count: 17, icon: 'wallet' },
  { name: 'Mobile Money', amount: 384,  count: 15, icon: 'card' },
];
const DEBT_AGING = [
  { label: 'Overdue',          count: 1, amount: 300, tone: 'danger' },
  { label: 'Due within 7 days', count: 1, amount: 145, tone: 'warn' },
  { label: 'Current',          count: 1, amount: 60,  tone: 'ok' },
  { label: 'No due date',      count: 0, amount: 0,   tone: 'neutral' },
];
const EXPENSE_LOG = [
  { id: 'e1', cat: 'Inventory', icon: 'box',      amount: 120, date: 'Today · 2:14 PM',  note: 'Restock — Ideal Milk ×24' },
  { id: 'e2', cat: 'Transport', icon: 'sales',    amount: 35,  date: 'Today · 9:40 AM',  note: 'Trotro to wholesale market' },
  { id: 'e3', cat: 'Utilities', icon: 'expense',  amount: 60,  date: 'Yesterday',        note: 'ECG prepaid top-up' },
  { id: 'e4', cat: 'Rent',      icon: 'store',     amount: 400, date: '24 May 2026',      note: 'Shop rent — June' },
];
const EXPENSE_CHIPS = ['Inventory', 'Transport', 'Utilities', 'Rent', 'Salary', 'Tax', 'Other'];
const topReceivables = () => CUSTOMERS.filter(c => c.debt > 0).sort((a, b) => b.debt - a.debt);

Object.assign(window, { PRODUCTS, byId, TOP_SELLING, ACTIVITY, CUSTOMERS, DEBTS, REPAYMENTS, NOTIFICATIONS, NOTIF_TONE, money, CAT_COLOR, REPORTS, TREND, EXPENSE_CATS, PAYMENT_METHODS, DEBT_AGING, EXPENSE_LOG, EXPENSE_CHIPS, topReceivables });
