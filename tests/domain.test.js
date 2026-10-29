import test from 'node:test';import assert from 'node:assert/strict';import {validateReport,escapeHTML} from '../src/domain.js';
const valid={title:'Eksempel',body:'Fiktiv hendelse',recipient:'Uavhengig mottaker (demo)'};
test('validates required content and rejects forged recipient',()=>{assert.equal(validateReport(valid),null);for(const patch of [{title:' '},{body:''},{recipient:'CEO'},{title:'a'.repeat(121)},{body:'a'.repeat(5001)}])assert.ok(validateReport({...valid,...patch}));});
test('treats user-controlled markup as text',()=>{assert.equal(escapeHTML('<img src=x onerror="alert(1)">'), '&lt;img src=x onerror=&quot;alert(1)&quot;&gt;');assert.equal(escapeHTML("'&"),'&#39;&amp;');});
