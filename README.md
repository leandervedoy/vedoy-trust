# Vedoy Trust 0.3

Norsk B2B-pilot for ansatte, HMS og fortrolig kommunikasjon.

## Implementert

- Supabase-innlogging, e-postbekreftelse, passordgjenoppretting og valgfritt TOTP-oppsett.
- Flere organisasjoner, e-postbundne invitasjoner, roller og deaktivering av medlemskap.
- Avvik, tiltak, risikovurderinger, sjekklister og forbedringsforslag.
- Fortrolige varsler og samtaler med valgt mottaker. Eier får ikke automatisk lesetilgang.
- Private vedlegg, hendelseslogg, søk, statusfilter og varsler inne i appen.
- Personalhåndbok med utkast, publisering, versjoner og lesebekreftelser.
- Tilgangsavgrenset JSON-eksport, sletting av avsluttede saker og personvernhenvendelser.

## Kjør

Node 22 eller nyere: `npm ci`, `npm run build`, `npm start`.
Åpne http://127.0.0.1:3000. `npm test` og `npm run check` verifiserer lokal kode.
Offentlig Supabase-prosjektadresse og publishable key ligger i src/config.js. Ingen tjenestenøkkel skal inn i nettleseren.

## Status og begrensninger

Databaseendringen er installert i valgt Vedoy-prosjekt, isolert i trust_private. Eksisterende applikasjonstabeller ble ikke endret. SQL-testen i supabase/tests/workspace.sql bruker syntetiske data og rollback; kjør i staging først. Kjøringen i denne leveransen ble avbrutt og er ikke bekreftet bestått.

12 lokale tester, syntakskontroll og produksjonsbygg består. Dette erstatter ikke ende-til-ende-testing eller uavhengig sikkerhetsgjennomgang.

Invitasjoner vises ved innlogging; invitasjons-e-post og e-post/SMS-varsler sendes ikke. Varsler oppdateres mens appen er åpen. Automatisk backup med testet gjenoppretting er ikke aktivert. TOTP-oppsett er tilgjengelig, men obligatorisk MFA er ikke håndhevet i API-et. Ingen anonym varsling, ende-til-ende-kryptering, SSO eller offline-synkronisering.

Vercel-konfigurasjon finnes, men opprettelse av prosjekt ble avvist med manglende rettigheter. Produksjonsdomene, Auth redirect-adresser, e-postleverandør, driftsrutiner og avtaler må ferdigstilles før sensitive data tas i bruk.

Se [sammenligning](docs/comparison.md) og [produksjonskrav](docs/production.md).
