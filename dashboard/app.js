const { createElement: h, useEffect, useState, useMemo } = React;
const { createRoot } = ReactDOM;
const R = Recharts;

const fmt = (n, p=2) => (typeof n === 'number' ? n.toLocaleString(undefined, {maximumFractionDigits:p}) : n);
const asSignClass = (n) => (n >= 0 ? 'pos' : 'neg');

function useMetrics() {
  const [m, setM] = useState(null);
  const [err, setErr] = useState(null);
  const load = async () => {
    try {
      const res = await fetch('./metrics.json?_=' + Date.now());
      const data = await res.json();
      setM(data); setErr(null);
    } catch(e) { setErr(String(e)); }
  };
  useEffect(() => { load(); }, []);
  useEffect(() => {
    const btn = document.getElementById('refreshBtn');
    if (btn) btn.onclick = load;
  }, []);
  return { m, err, reload: load };
}

function KPICard({label, value, hint, signColor=true}){
  const cls = signColor && typeof value === 'number' ? asSignClass(value) : '';
  return h('div', { className:'card rounded-2xl p-4'}, [
    h('div', { className:'text-xs text-slate-400 mb-1'}, label),
    h('div', { className:`text-2xl num ${cls}`}, typeof value==='number'?fmt(value):value),
    hint ? h('div', { className:'text-xs text-slate-500 mt-1'}, hint) : null
  ]);
}

function ChartSpread({series}){
  return h(R.ResponsiveContainer, {width:'100%', height:320},
    h(R.ComposedChart, {data:series}, [
      h(R.CartesianGrid, {stroke:'rgba(255,255,255,0.08)'}),
      h(R.XAxis, {dataKey:'t', tickFormatter:(t)=>luxon.DateTime.fromISO(t).toFormat('HH:mm') , stroke:'#94a3b8'}),
      h(R.YAxis, {stroke:'#94a3b8'}),
      h(R.Tooltip, {contentStyle:{background:'#0b1220', border:'1px solid rgba(255,255,255,0.1)'}}),
      h(R.Line, {type:'monotone', dataKey:'spread_bps', stroke:'var(--green)', dot:false, name:'Spread (bps)'}),
      h(R.Area, {type:'monotone', dataKey:'net_pnl', stroke:'var(--green)', fill:'rgba(16,185,129,0.15)', name:'Net P&L'})
    ])
  );
}

function ChartFees({trades}){
  return h(R.ResponsiveContainer, {width:'100%', height:320},
    h(R.BarChart, {data:trades.slice(-50)}, [
      h(R.CartesianGrid, {stroke:'rgba(255,255,255,0.08)'}),
      h(R.XAxis, {dataKey:'id', hide:true}),
      h(R.YAxis, {stroke:'#94a3b8'}),
      h(R.Tooltip, {contentStyle:{background:'#0b1220', border:'1px solid rgba(255,255,255,0.1)'}}),
      h(R.Bar, {dataKey:'fees_total', fill:'var(--blue)', name:'Fees'}),
      h(R.Bar, {dataKey:'slippage', fill:'rgba(59,130,246,0.6)', name:'Slippage'})
    ])
  );
}

function ChartCumPnL({series}){
  return h(R.ResponsiveContainer, {width:'100%', height:280},
    h(R.AreaChart, {data:series}, [
      h(R.CartesianGrid, {stroke:'rgba(255,255,255,0.08)'}),
      h(R.XAxis, {dataKey:'t', tickFormatter:(t)=>luxon.DateTime.fromISO(t).toFormat('HH:mm') , stroke:'#94a3b8'}),
      h(R.YAxis, {stroke:'#94a3b8'}),
      h(R.Tooltip, {contentStyle:{background:'#0b1220', border:'1px solid rgba(255,255,255,0.1)'}}),
      h(R.Area, {type:'monotone', dataKey:'cum_pnl', stroke:'var(--green)', fill:'rgba(16,185,129,0.2)', name:'Cumulative P&L'})
    ])
  );
}

function ChartRisk({series}){
  return h(R.ResponsiveContainer, {width:'100%', height:280},
    h(R.ComposedChart, {data:series}, [
      h(R.CartesianGrid, {stroke:'rgba(255,255,255,0.08)'}),
      h(R.XAxis, {dataKey:'t', tickFormatter:(t)=>luxon.DateTime.fromISO(t).toFormat('HH:mm') , stroke:'#94a3b8'}),
      h(R.YAxis, {yAxisId:'vol', orientation:'left', stroke:'#94a3b8'}),
      h(R.YAxis, {yAxisId:'dd', orientation:'right', stroke:'#94a3b8'}),
      h(R.Tooltip, {contentStyle:{background:'#0b1220', border:'1px solid rgba(255,255,255,0.1)'}}),
      h(R.Line, {yAxisId:'vol', type:'monotone', dataKey:'roll_vol', stroke:'var(--green)', dot:false, name:'Rolling Vol'}),
      h(R.Area, {yAxisId:'dd', type:'monotone', dataKey:'drawdown', stroke:'var(--blue)', fill:'rgba(59,130,246,0.2)', name:'Drawdown'})
    ])
  );
}

function TradesTable({trades}){
  const headers = ['t','pair','side','qty','gross_pnl','fees_total','slippage','net_pnl','hold_ms']
  const head = h('tr', {className:'text-slate-300 text-xs'}, headers.map(k=>h('th',{className:'text-left py-2 pr-4'},k)))
  const rows = trades.slice(-200).reverse().map((tr)=>
    h('tr', {className:'text-sm'}, [
      h('td', {className:'py-1 pr-4 text-slate-400'}, luxon.DateTime.fromISO(tr.t).toFormat('HH:mm:ss')),
      h('td', {className:'py-1 pr-4'}, tr.pair),
      h('td', {className:'py-1 pr-4'}, tr.side),
      h('td', {className:'py-1 pr-4 num'}, fmt(tr.qty,6)),
      h('td', {className:`py-1 pr-4 num ${asSignClass(tr.gross_pnl)}`}, fmt(tr.gross_pnl,4)),
      h('td', {className:'py-1 pr-4 num fee'}, fmt(tr.fees_total,4)),
      h('td', {className:'py-1 pr-4 num neg'}, fmt(tr.slippage,4)),
      h('td', {className:`py-1 pr-4 num ${asSignClass(tr.net_pnl)}`}, fmt(tr.net_pnl,4)),
      h('td', {className:'py-1 pr-4 num'}, tr.hold_ms)
    ])
  );
  return h('table', {className:'min-w-full'}, [head, ...rows]);
}

function App(){
  const { m, err } = useMetrics();
  useEffect(()=>{
    if (m) document.getElementById('updatedAt').textContent = 'Updated ' + luxon.DateTime.fromISO(m.updated_at).toFormat('HH:mm:ss');
  }, [m]);
  if (err) return h('div', {className:'text-red-400'}, err);
  if (!m) return h('div', null, 'Loading…');

  const kpis = [
    ['Net P&L (after fees)', m.kpi.net_pnl, `fees: ${fmt(m.kpi.fees_total,4)} | win%: ${fmt(m.kpi.win_rate*100,2)}%`],
    ['Avg Spread (bps)', m.kpi.avg_spread_bps, `trades: ${m.kpi.trades}`],
    ['Sharpe (naive)', m.kpi.sharpe, `vol: ${fmt(m.kpi.realized_vol,4)}`],
    ['Max Drawdown', m.kpi.max_drawdown, `duration: ${m.kpi.max_dd_duration}s`],
  ];

  return h(React.Fragment, null, [
    h('section', {className:'grid grid-fit gap-4 mb-6'}, kpis.map(([l,v,hint],i)=>h(KPICard,{key:i,label:l,value:v,hint}))),
    h('section', {className:'grid md:grid-cols-12 gap-4'}, [
      h('div',{className:'md:col-span-8 card rounded-2xl p-4'}, [h('div',{className:'mb-2 text-sm text-slate-300'},'Spread & Net P&L over time'), h(ChartSpread,{series:m.series})]),
      h('div',{className:'md:col-span-4 card rounded-2xl p-4'}, [h('div',{className:'mb-2 text-sm text-slate-300'},'Fees & Slippage (per trade)'), h(ChartFees,{trades:m.trades})]),
      h('div',{className:'md:col-span-6 card rounded-2xl p-4'}, [h('div',{className:'mb-2 text-sm text-slate-300'},'Cumulative P&L after fees'), h(ChartCumPnL,{series:m.series})]),
      h('div',{className:'md:col-span-6 card rounded-2xl p-4'}, [h('div',{className:'mb-2 text-sm text-slate-300'},'Rolling Volatility & Drawdown'), h(ChartRisk,{series:m.series})]),
      h('div',{className:'md:col-span-12 card rounded-2xl p-4'}, [h('div',{className:'mb-3 text-sm text-slate-300'},'Recent Trades'), h(TradesTable,{trades:m.trades})])
    ])
  ]);
}

createRoot(document.getElementById('root')).render(h(App));
