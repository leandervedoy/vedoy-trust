import {build} from 'esbuild';
import {mkdir,copyFile,rm} from 'node:fs/promises';
await rm('dist',{recursive:true,force:true});await mkdir('dist/assets',{recursive:true});
await build({entryPoints:['src/workspace.js'],outfile:'dist/assets/app.js',bundle:true,minify:true,format:'esm',target:['es2022'],sourcemap:false});
await copyFile('index.html','dist/index.html');await copyFile('src/style.css','dist/assets/style.css');
console.log('Built dist/');
