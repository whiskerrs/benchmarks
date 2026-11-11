// A stand-in for the benchmark's replay server, for checking the endpoint
// override and the error state by hand: forwards POST /api to mock.shop.
//   bun scripts/dev-proxy.ts [port]      (default 8787)
const port = Number(process.argv[2] ?? 8787);
const UPSTREAM = 'https://apparel-large-catalog.mock.shop/api';
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
Bun.serve({
  port,
  hostname: '0.0.0.0',
  async fetch(req) {
    if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
    const body = await req.text();
    const op = (() => { try { return JSON.parse(body).operationName; } catch { return '?'; } })();
    console.log(`${new Date().toISOString()} ${op}`);
    const r = await fetch(UPSTREAM, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body });
    return new Response(await r.text(), { status: r.status, headers: { 'Content-Type': 'application/json', ...cors } });
  },
});
console.log(`proxy on http://0.0.0.0:${port}/api`);
