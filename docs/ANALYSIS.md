# Trackin' Trails — läge och nästa steg

Analys av appen som den ser ut på grenen `cursor/ci-screenshots-051b` (PR #2). Kartan är hela ytan: mörk, dämpad MapKit-karta, orange rutter, flytande kontroller och ett mörkt ark för lista, filter, statistik och detalj. Visningsnamn **Trackin' Trails**, mål **Trails**, bundle-id `com.legionorange.trails`. Bygget i CI är osignerat för simulatorn. Ingen TestFlight och inget utvecklarkonto.

## Vad som finns

- **Karta.** MapKit i mörkt `.standard` med `.muted` (iOS 18+). Alla synliga rutter ritas med orange kärna och en bredare glöd. Värmekarta använder bredare, halvgenomskinliga streck så att korsningar blir ljusare. Tryck nära en linje (inom 500 m) fokuserar den, eller växlar den i urvalsläge.
- **Krom.** Kapsel uppe till vänster (rutter / värmekarta), streckad **Välj** uppe till höger, piller med **Rutter / Filter / Statistik**, filterpiller ("Alla rutter" med mera) och en centreringsknapp. När arket är öppet ligger pillret och centreringen ovanför arkets kant.
- **Ark.** Lista, ruttdetalj (distans, tid, tempo, markera/avmarkera, foton), filter, statistik och sammanfattning av ett urval. **Visa endast valda** gör urvalet till ett filter för karta, lista och statistik.
- **Filter.** Endast markerade, endast valda, datumintervall (hela dygn i lokal kalender), distans 0–40 km, källa Exempel/Hälsa.
- **Markeringar.** SwiftData lokalt på enheten, nyckel = tränings-id. `-demo-data` markerar de två senaste exempelpassen och ber aldrig om Hälsa eller Bilder.
- **Exempeldata.** Fyra rundor runt Stockholm (Nackareservatet, Djurgården, Södermalm, Hagaparken) plus tre medföljande bilder per pass. Samma data driver skärmbilderna i `docs/screenshots/`.
- **Hälsa.** `HealthKitWorkoutSource` läser upp till 40 `HKWorkout` av typen löpning och deras `HKWorkoutRoute`. Skrivning till Hälsa finns inte. Varje pass får titeln "Löpning".
- **Bilder.** `PhotoLibrarySource` söker bilder vars `creationDate` ligger mellan start och mål (högst 12 per pass) och ber om läs-och-skriv. I demoläge används bara de medföljande bilderna.
- **CI.** `macos-26`, Xcode 26.6, osignerad simulator, enhetstester och UI-test som sparar åtta PNG-bilder.

## Fungerar respektive inte kört på riktig enhet

| Del | Läge |
| --- | --- |
| Exempeldata, karta, filter, statistik, urval, markering, foton i demoläge | Körs i CI och syns i `docs/screenshots/` |
| HealthKit-fråga, ruttläsning, PhotoKit-fråga | Kod finns och är inte en tom stubbe, men CI kör aldrig behörighetsdialogerna |
| Centrera | Passar in synliga rutter. Ingen GPS och ingen platsbehörighet |
| Värmekarta | Halvgenomskinliga streck, inte en riktig densitetsraster. Exempelrutterna korsar knappt varandra |
| Hälsa i simulatorn | Avslaget. Väljer man Hälsa visas ett meddelande och exempeldatan ligger kvar |

## Glapp mot MoveMap-riktningen

MoveMap-bilderna är riktmärke för utseendet, inte en funktionslista att kopiera.

- Utseendet (mörk karta, orange linjer, kapslar, flikpiller, mörkt ark) finns. Kartstilen är Apples, inte en egen stil.
- Ingen tidslinje att skrubba, inga länder, gator, höjd, personbästa eller träningsvarianter. Statistiken är summa och snitt för det aktiva filtret.
- Arkets höjd är två lägen, inte ett fingerdrag mellan detents.
- Pass från Hälsa heter alla "Löpning". Ingen GPX-import eller export i iOS-appen.
- Tomma lägen är en textrad, inte en egen vy.

## Risker inför TestFlight, Hälsa och Bilder

- CI-bygget har `CODE_SIGNING_ALLOWED=NO`. Det kan inte installeras via TestFlight. Det krävs ett betalt utvecklarkonto, ett team, och att HealthKit-capabilityn aktiveras i portalen. Entitlement-filen slår bara på `com.apple.developer.healthkit`.
- Första starten på en telefon visar systemdialoger för Hälsa och Bilder. Demoläget `-demo-data` gör inte det, så granskaren måste prova riktig data separat.
- Appen ber om `PHAccessLevel.readWrite` trots att den bara läser. `NSHealthUpdateUsageDescription` finns trots att appen inte skriver till Hälsa. Båda kan ge frågor i granskning. Läsbehörighet räcker för bilderna.
- Högst 40 löppass. Rutter utan minst två giltiga punkter hoppas över. Aktivitetstypen är bara `.running` (SDK:t har ingen trail running).
- Bildhämtningen är synkron och högupplöst, ett pass i taget. Många pass med många bilder kan haka upp gränssnittet.
- Markeringarna ligger i en lokal SwiftData-butik. De följer inte med iCloud och försvinner om appen raderas.
- Webbkopian i `web/` är en förhandsvisning. Den är inte publicerad. Ingen GitHub Pages.

## Prioriterat härnäst

1. Utvecklarkonto, signering och en intern TestFlight-build. Utan det går inte Hälsa eller Bilder att verifiera på riktigt.
2. En genomgång på telefon: behörighetsdialoger, ett riktigt löppass med GPS-rutt, bilder tagna under passet, och att markeringen finns kvar efter omstart.
3. Snäva in behörigheterna till läsning (Bilder `.readOnly` eller `.readWrite` bara om skrivning blir ett krav; ta bort update-texten för Hälsa om appen fortfarande inte skriver).
4. Bättre namn på pass från Hälsa än "Löpning", och en tydlig tom vy när Hälsa inte har några rutter.
5. Värmekarta som faktiskt blir ljusare i korsningar när det finns många riktiga rundor, plus ett dragbart ark.
6. Publicera inte `web/` förrän det är godkänt. Den statiska kopian kan öppnas lokalt under tiden.
