# Vedoy Trust

Én arbeidsflate for ansatte, rettigheter, varsling, tillitsvalgte og intern kommunikasjon. Utviklet av Vedøy, med omtanke, tydelig språk og respekt for menneskene på jobb.

## Status: interaktiv prototype, v0.2.0

Dette er en kjørbar demonstrasjon, ikke en produksjonsklar tjeneste. Ingen innlogging, database, e-post, SMS eller ekstern sending. Demovarsler og samtaler finnes bare i fanens minne og forsvinner ved omlasting. Ingen analyseverktøy, informasjonskapsler eller nettverkskall for brukerinnhold. Bruk kun oppdiktede opplysninger. Ingen løfter om anonymitet eller ende-til-ende-kryptering.

## Start

Node.js 22 eller nyere. Ingen installasjon eller eksterne avhengigheter.

```sh
npm start
# Åpne http://127.0.0.1:3000
npm run check
npm test
```

## Samlet app

- Min arbeidsdag: snarveier, introduksjon og lesebekreftelse i demo.
- Folk og roller: tydelig skille mellom tillitsvalgt, verneombud og varslingsansvarlig.
- Rettigheter: lenker til Arbeidstilsynets kilder, uten automatisk juridisk rådgivning.
- Si fra: validert demoskjema, valg av mottaker og oversikt over demovarsler.
- Tillitsvalgte: egen inngang for støtte og avtalespørsmål.
- Samtaler: velg demokontakt og prøv en samtaleflyt.

Mobiltilpasset, tastaturnavigasjon, redusert bevegelse og behandling av brukerinnhold som tekst.

## GitHub

Kildekode: https://github.com/leandervedoy/vedoy-trust

Se docs/production.md for veien til pilot med ekte ansatte.

## Nytt i v0.2.0

Avvik og nestenulykker med type, alvorlighet, sted og dato. Oppfølging med ansvarlig, frist, forsinkelsesmarkering, tiltak, lukking og gjenåpning samt hendelseshistorikk. Lukking krever fullførte tiltak og dokumentert resultat. HMS med enkel 5×5-risikomodell, tiltak, ansvarlig, ny vurderingsdato og arbeidsmiljøsjekklister med OK/avvik/ikke relevant. Alt er demodata i fanens minne; ingen tilgangskontroll eller varig lagring. Risikoskala og sjekkliste er generelle eksempler som må tilpasses virksomheten.
