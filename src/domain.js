export const sections = [['oversikt','◈','Min arbeidsdag'],['avvik','△','Avvik'],['oppfolging','✓','Oppfølging'],['hms','▦','HMS'],['ansatte','◎','Folk og roller'],['rettigheter','▤','Rettigheter'],['varsling','◇','Si fra'],['tillitsvalgte','♧','Tillitsvalgte'],['meldinger','◌','Samtaler']];
export function validateReport({title, body, recipient}) {
  if (!title?.trim() || title.trim().length > 120) return 'Skriv en tittel på 1–120 tegn.';
  if (!body?.trim() || body.trim().length > 5000) return 'Skriv en beskrivelse på 1–5000 tegn.';
  if (!['Uavhengig mottaker (demo)','Varslingsansvarlig (demo)'].includes(recipient)) return 'Velg mottaker.';
  return null;
}
export function escapeHTML(value) { return String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
