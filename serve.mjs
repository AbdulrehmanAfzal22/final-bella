// Local preview of dist/, with SPA fallback. No npm dependencies required.
import http from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { dirname, extname, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), 'dist');
const port = Number(process.env.PORT || 4173);
const types = {'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.svg':'image/svg+xml','.png':'image/png','.jpg':'image/jpeg','.jpeg':'image/jpeg','.webp':'image/webp','.woff2':'font/woff2','.ico':'image/x-icon','.json':'application/json'};
const server = http.createServer(async (req, res) => {
  if (!['GET','HEAD'].includes(req.method)) { res.writeHead(405); res.end(); return; }
  try {
    const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    let file = resolve(root, '.' + pathname);
    if (file !== root && !file.startsWith(root + sep)) { res.writeHead(403); res.end(); return; }
    try { if (!(await stat(file)).isFile()) file = resolve(root,'index.html'); }
    catch { if (extname(pathname)) { res.writeHead(404); res.end('Not found'); return; } file = resolve(root,'index.html'); }
    const data = await readFile(file);
    res.writeHead(200, {'Content-Type':types[extname(file)] || 'application/octet-stream','X-Content-Type-Options':'nosniff','Cache-Control':'no-cache'});
    res.end(req.method === 'HEAD' ? undefined : data);
  } catch { res.writeHead(400); res.end('Unable to serve this request. Build the app first.'); }
});
server.on('error', error => { console.error(error.code === 'EADDRINUSE' ? 'Port 4173 is in use. Stop the other local server first.' : error.message); process.exitCode=1; });
server.listen(port,'127.0.0.1',()=>console.log('Maison Elan: http://localhost:'+port+' — admin: /admin'));
