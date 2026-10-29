export const owners = ['Anna Strand (demo)', 'Jonas Berg (demo)', 'Lise Vik (demo)'];
export const checklistItems = ['Rømningsveier er frie', 'Utstyr er kontrollert', 'Arbeidsområdet er ryddig', 'Avvik er registrert og fulgt opp'];
export const today = () => new Intl.DateTimeFormat('sv-SE',{timeZone:'Europe/Oslo'}).format(new Date());
function required(value,max=2000){return typeof value==='string'&&value.trim().length>0&&value.trim().length<=max;}
export function validDate(value){return /^\d{4}-\d{2}-\d{2}$/.test(value||'')&&!isNaN(Date.parse(value))&&new Date(value).toISOString().slice(0,10)===value;}
export function validateIncident(d){
 if(!required(d.title,120)||!required(d.description,5000)||!required(d.place,150))return 'Fyll ut tittel, sted og beskrivelse innenfor tegngrensene.';
 if(!['Avvik','Nestenulykke'].includes(d.kind)||!['Lav','Middels','Høy','Kritisk'].includes(d.severity))return 'Velg type og alvorlighetsgrad.';
 if(!validDate(d.date)||d.date>today())return 'Velg en gyldig hendelsesdato som ikke er i fremtiden.';
 return null;
}
export function validateAction(d){
 if(!required(d.text,500)||!owners.includes(d.owner)||!validDate(d.due))return 'Tiltaket må ha beskrivelse, ansvarlig og gyldig frist.';
 return null;
}
export function closureError(incident,summary){
 if(incident.status==='Lukket')return 'Saken er allerede lukket.';
 if(!incident.actions.length||incident.actions.some(a=>!a.done))return 'Fullfør minst ett tiltak og alle åpne tiltak før saken lukkes.';
 if(!required(summary,2000))return 'Beskriv resultatet og hvordan tiltakene er kontrollert.';
 return null;
}
export function riskScore(probability,consequence){
 const p=Number(probability),c=Number(consequence);
 if(!Number.isInteger(p)||!Number.isInteger(c)||p<1||p>5||c<1||c>5)throw new Error('Velg sannsynlighet og konsekvens fra 1 til 5.');
 return p*c;
}
export function riskLevel(score){return score>=15?'Høy':score>=6?'Middels':'Lav';}
export function validateRisk(d){
 if(!required(d.hazard,200)||!required(d.measure,2000)||!owners.includes(d.owner)||!validDate(d.review))return 'Fyll ut fare, tiltak, ansvarlig og dato for ny vurdering.';
 try{riskScore(d.probability,d.consequence);}catch(e){return e.message;}
 return null;
}
export function checklistError(answers,notes){
 if(checklistItems.some((_,i)=>!['ok','avvik','na'].includes(answers[i])))return 'Vurder alle punktene før du fullfører.';
 if(answers.includes('avvik')&&!required(notes,2000))return 'Beskriv avvikene og hvordan de skal følges opp.';
 return null;
}
export function isOverdue(action,date=today()){return !action.done&&action.due<date;}
