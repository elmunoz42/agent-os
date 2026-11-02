// Minimal todo app for the Agent OS sample. No dependencies.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { createStore } = require('./src/tasks');

const PORT = Number(process.env.PORT) || 4173;
const store = createStore();

function json(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve) => {
    let data = '';
    req.on('data', (c) => (data += c));
    req.on('end', () => {
      try { resolve(JSON.parse(data || '{}')); } catch { resolve({}); }
    });
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  if (url.pathname === '/api/tasks' && req.method === 'GET') return json(res, 200, store.list());
  if (url.pathname === '/api/tasks' && req.method === 'POST') {
    const r = store.add((await readBody(req)).title);
    return r.ok ? json(res, 201, r.value) : json(res, 400, { error: r.error });
  }
  const toggle = url.pathname.match(/^\/api\/tasks\/(\d+)\/toggle$/);
  if (toggle && req.method === 'POST') {
    const r = store.toggle(Number(toggle[1]));
    return r.ok ? json(res, 200, r.value) : json(res, 404, { error: r.error });
  }
  if (url.pathname === '/api/reset' && req.method === 'POST') {
    store.reset();
    return json(res, 200, { ok: true });
  }
  if (url.pathname === '/' || url.pathname === '/index.html') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    return fs.createReadStream(path.join(__dirname, 'public', 'index.html')).pipe(res);
  }
  res.writeHead(404);
  res.end('Not found');
});

server.listen(PORT, () => console.log(`Sample app on http://localhost:${PORT}`));
