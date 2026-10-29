import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {resolve,extname} from 'node:path';
const root=resolve(import.meta.dirname);
const allowed=new Set(['/','/index.html','/src/app.js','/src/domain.js','/src/style.css']);
createServer(async(req,res)=>{
 const path=new URL(req.url,'http://localhost').pathname;
 res.setHeader('Content-Security-Policy',"default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'none'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'");
 res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('Referrer-Policy','no-referrer');res.setHeader('Cache-Control','no-store');
 if(!['GET','HEAD'].includes(req.method)){res.writeHead(405);return res.end();}
 if(!allowed.has(path)){res.writeHead(404);return res.end('Not found');}
 try{const file=path==='/'?'/index.html':path;const body=await readFile(root+file);res.setHeader('Content-Type',({'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8'})[extname(file)]);res.writeHead(200);res.end(req.method==='HEAD'?undefined:body);}catch{res.writeHead(500);res.end('Unable to load demo');}
}).listen(Number(process.env.PORT)||3000,'127.0.0.1',()=>console.log('Vedoy Trust demo: http://127.0.0.1:3000'));
