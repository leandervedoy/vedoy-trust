# Fra prototype til betalt pilot

## Produktvalg

Én app og ett repo, med avgrensede moduler. Småbedrifter og organisasjoner får én inngang. Tilgang til varslingssaker skal være separat fra vanlig personaladministrasjon. Appen skal ikke brukes til overvåking, ansattrangering eller automatiske avgjørelser om arbeidsrettigheter.

## Neste implementering

1. Innlogging, organisasjoner og invitasjoner. Verifisert medlemskap på serveren. MFA for saksbehandlere. Ingen roller fra klienten.
2. Database i valgt EU-region, organisasjonsisolasjon og tester på tvers av organisasjoner. Serverhåndhevet, saksbasert tilgang; administrator skal ikke automatisk få lese varsler eller samtaler med tillitsvalgte.
3. Eget mottakeroppsett per virksomhet, alternativ mottaker ved habilitetskonflikt, bekreftelse, ansvarlig og hendelseslogg. Tillitsvalgte og verneombud skal ikke automatisk bli saksbehandlere.
4. Tilgangskontrollerte samtaler og filer. Dokumenter kryptering og nøkkelforvaltning; ikke påstå ende-til-ende-kryptering uten ferdig implementasjon og uavhengig gjennomgang. Eventuell anonym varsling krever separat trusselmodell inkludert metadata og logger.
5. Varsler via e-post uten saksinnhold. Samtykke til valgfri produktinformasjon holdes separat fra nødvendige tjenestemeldinger.
6. Avklar behandlingsansvar, databehandleravtale, underleverandører, lagringsfrister, innsyn, sletting og behov for personvernkonsekvensvurdering før behandling av reelle opplysninger.
7. Backup med testet gjenoppretting, tilgangslogg uten saksinnhold, sikkerhetstesting, rategrenser og hendelseshåndtering.

## Ferdig for pilot når

- Tester beviser at organisasjon A ikke kan lese B, og at vanlig admin ikke kan lese beskyttede saker.
- Reelle mottakere og rutiner er bekreftet av virksomheten.
- Tilgangsrevokering, kontogjenoppretting, sletting og gjenoppretting fra backup er testet.
- Tilgjengelighet, mobilvisning og alle hovedflyter er manuelt testet.
- Avtaler og behandlingsoppsett er gjennomgått. Sikkerhets- og personvernpåstander samsvarer med faktisk implementasjon.

## B2B-pilot

Begynn med én liten virksomhet, én bekreftet kontaktstruktur og én tydelig varslingsrutine. Avklar hvem som betaler, hvem som behandler saker, og hvem som gir uavhengig støtte. Test først med fiktive saker. Mål om ansatte finner riktig kontakt og forstår neste steg; pris først når driftskostnad og tjenestenivå er kjent.
