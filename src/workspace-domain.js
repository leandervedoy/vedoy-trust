export const roles={owner:'Eier',manager:'Leder / varslingsmottaker',employee:'Ansatt',trustee:'Tillitsvalgt',safety_rep:'Verneombud'};
export const statuses={open:'Åpen',in_progress:'Under arbeid',closed:'Lukket',draft:'Utkast',published:'Publisert'};
export const kinds={incident:'Avvik',report:'Fortrolig varsel',conversation:'Samtale',handbook:'Personalhåndbok',improvement:'Forbedringsforslag',risk:'Risikovurdering',checklist:'Sjekkliste',privacy:'Personvernhenvendelse'};
export const routes=[['oversikt','◈','Min arbeidsdag'],['incident','△','Avvik og oppfølging'],['hms','▦','HMS'],['report','◇','Si fra'],['conversation','◌','Samtaler'],['handbook','▤','Personalhåndbok'],['improvement','✧','Forbedringer'],['people','◎','Folk og roller'],['notifications','◉','Varsler'],['settings','⚙','Innstillinger']];
export function canManage(record,userId,role){
 if(record.kind==='report')return record.participants.includes(userId);
 if(record.kind==='conversation')return record.creator===userId||record.participants.includes(userId);
 if(record.kind==='handbook')return ['owner','manager'].includes(role);
 if(record.kind==='privacy')return role==='owner';
 return record.creator===userId||['owner','manager','safety_rep'].includes(role)||record.participants.includes(userId);
}
export function filterRecords(records,query,status='all'){const q=query.trim().toLocaleLowerCase('nb');return records.filter(r=>(status==='all'||r.status===status)&&`${r.title} ${r.body}`.toLocaleLowerCase('nb').includes(q));}
export function validateAttachment(file){if(!['image/jpeg','image/png','application/pdf','text/plain'].includes(file.type))return 'Velg JPG, PNG, PDF eller tekstfil.';if(file.size>10*1024*1024||file.size===0)return 'Filen må være mellom 1 byte og 10 MB.';return null;}
export function safeFilename(name){return name.replace(/[^\p{L}\p{N}._ -]/gu,'_').slice(-100)||'vedlegg';}
