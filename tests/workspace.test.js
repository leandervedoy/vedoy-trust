import {test} from 'node:test';
import assert from 'node:assert/strict';
import {canManage,filterRecords,validateAttachment,safeFilename} from '../src/workspace-domain.js';
test('owner is not a confidential report handler unless designated',()=>{
 const r={kind:'report',creator:'employee',participants:['trustee']};
 assert.equal(canManage(r,'owner','owner'),false);
 assert.equal(canManage(r,'employee','employee'),false);
 assert.equal(canManage(r,'trustee','trustee'),true);
});
test('handbook editing is restricted and conversations belong to participants',()=>{
 assert.equal(canManage({kind:'handbook'},'a','employee'),false);
 assert.equal(canManage({kind:'handbook'},'a','manager'),true);
 assert.equal(canManage({kind:'conversation',creator:'a',participants:['b']},'c','owner'),false);
});
test('search combines Norwegian text with status',()=>{
 const rows=[{title:'HÅNDBOK',body:'Ferier',status:'published'},{title:'Håndbok',body:'utkast',status:'draft'}];
 assert.equal(filterRecords(rows,'håndbok','published').length,1);
 assert.equal(filterRecords(rows,'ferier').length,1);
});
test('attachments reject executable content, empty files and excess size',()=>{
 assert.ok(validateAttachment({type:'text/html',size:100}));
 assert.ok(validateAttachment({type:'application/pdf',size:0}));
 assert.ok(validateAttachment({type:'application/pdf',size:10485761}));
 assert.equal(validateAttachment({type:'application/pdf',size:10485760}),null);
 assert.equal(safeFilename('../../<script>.pdf').includes('/'),false);
});
