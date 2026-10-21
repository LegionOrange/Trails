# Trackin' Trails

Trackin' Trails är en liten iOS-app som visar löprundor med GPS-rutt. Xcode-målet och produktnamnet är **Trails**, visningsnamnet på hemskärmen och i appen är **Trackin' Trails**, och bundle-id är `com.legionorange.trails`.

Kartan är alltid bakgrunden, i mörkt dämpat kartläge med orange lysande rutter. En flytande kapsel uppe till vänster växlar mellan vanliga rutter och en värmekarta där överlappande linjer blir ljusare. **Välj** är en rund knapp med streckad rektangel uppe till höger. En pillerformad flikrad längst ner har **Rutter**, **Filter** och **Statistik**, med den aktiva fliken i orange. Ovanför den visar en liten kapsel det aktiva filtret. Listan, filtret, statistiken och ruttdetaljen glider upp som ett mörkt genomskinligt ark över kartan.

1. Löppass läses från Hälsa (`HKWorkout` med aktivitetstypen löpning) och deras GPS-rutter (`HKWorkoutRoute`). Alla rutter som filtret släpper igenom ritas på kartan.
2. **Rutter** listar passen. Ett tryck markerar ruttens linje på kartan och öppnar detaljen i arket: distans, tid, tempo, markering och foton från passet.
3. Markeringar sparas lokalt med SwiftData. En markerad rutt kan filtreras fram med **Endast markerade**.
4. Foton söks i bildbiblioteket mellan passets start och mål. Miniatyrerna visas i detaljen och öppnas vid tryck.
5. **Filter** styr vilka rutter kartan, listan och statistiken visar: endast markerade, endast valda, datumintervall och distansintervall.
6. **Statistik** summerar rutterna som filtret visar: antal, total distans, total tid, snittempo och snittdistans.
7. **Välj** uppe till höger startar ett urval. Rutter kan kryssas i listan eller tryckas på kartan. **Sammanfatta** visar de valda rutterna tillsammans på kartan med samlad statistik. **Visa endast valda** gör urvalet till ett filter för kartan, listan och statistiken. **Centrera** passar in de synliga rutterna igen.

Simulatorn har ingen riktig hälsodata. Därför finns en inbyggd exempelkälla med fyra rundor runt Stockholm och genererade exempelbilder, så att gränssnittet går att köra i simulatorn och i SwiftUI-previews. På en enhet där Hälsa finns är **Hälsa** förvald. I simulatorn är **Exempel** förvald. Källan byts under **Filter**. Start med `-demo-data` tvingar exempelrutter, markerar de två senaste och frågar aldrig efter Hälsa eller Bilder.

Det finns inget Apple Developer-konto i det här läget, och appen kodsigneras inte. Inget TestFlight och inga certifikat.

## Struktur

```text
project.yml                         XcodeGen-spec. Det här är källan till Xcode-projektet.
Trails/
  TrailsApp.swift                   Start, SwiftData-container och datakällor
  AppModel.swift                    Rutter, filter, urval, markeringar och källbyte
  Models.swift                      RunWorkout, WorkoutPhoto, FavoriteMark
  RouteQuery.swift                  Filter, statistik och tempo
  WorkoutSources.swift              HealthKit och exempelpass
  PhotoSources.swift                PhotoKit och exempelbilder
  FavoritesRepository.swift         Lokala markeringar
  RouteGeometry.swift               Längd, kartregion, närmaste rutt, listminiatyr
  RunFormatting.swift               Svensk formatering och tidsfönster
  Info.plist                        Visningsnamn och användningssträngar
  Trails.entitlements               com.apple.developer.healthkit
  Views/                            Karta, bottenark, ruttdetalj, filter och statistik
TrailsTests/                        Enhetstester för geometri, filter, urval, exempeldata och markeringar
TrailsUITests/                      Skärmbilder av kartan och arket, startas med -demo-data
docs/screenshots/                   PNG-bilder från den senaste gröna CI-körningen
.github/workflows/ios.yml           Bygger och testar på macOS-runner
```

`Trails.xcodeproj` genereras och ska inte redigeras för hand. Den är gitignorerad.

## Köra lokalt

Macen behöver XcodeGen. Projektet är tänkt att byggas med Xcode 26, men specen sätter deployment target iOS 17.

```bash
brew install xcodegen
xcodegen generate --spec project.yml
open Trails.xcodeproj
```

Välj en iPhone-simulator och kör. Signering är avstängd i `project.yml` (`CODE_SIGNING_ALLOWED=NO`), så inget team behöver väljas för simulatorn.

## Behörigheter

`Info.plist` innehåller:

- `NSHealthShareUsageDescription` och `NSHealthUpdateUsageDescription` för att läsa pass. Appen skriver inte till Hälsa.
- `NSPhotoLibraryUsageDescription` för att söka foton i passets tidsintervall.
- `CFBundleDisplayName` = Trackin' Trails.

`Trails.entitlements` slår på HealthKit. Capabilityn kan inte aktiveras mot Apples servrar förrän ett utvecklarkonto finns. Simulatorbygget i CI signerar inte appen.

## GitHub Actions

Workflowen **iOS** körs på `pull_request` och på `push` till `main`, med den GitHub-hostade imagen `macos-26` (Apple Silicon). Push till en PR-gren startar inte ett extra jobb, så samma commit byggs bara en gång. En concurrency-grupp avbryter en pågående körning om samma commit köas igen. Imagen har Xcode 26.6 som förval, alltså senaste stabila Xcode. Xcode 27 finns bara som förhandsversion och används inte.

Stegen är:

1. `xcode-select` pekas på `/Applications/Xcode_26.6.app` när den finns.
2. XcodeGen 2.46.0 hämtas som binär och cachas under `tools/xcodegen`.
3. `xcodegen generate` skapar projektet från `project.yml`.
4. Den nyaste installerade iPhone-simulatorn väljs (iPhone 17 om den finns).
5. `xcodebuild test` bygger appen och kör `TrailsTests` och `TrailsUITests` med `CODE_SIGNING_ALLOWED=NO`. UI-testet startar appen med `-demo-data`, så exempelrutter och de medföljande bilderna visas utan behörighetsdialoger.
6. UI-testet sparar åtta PNG-bilder: kartan, ruttlistan, en ruttdetalj, filtret, statistiken, urvalsläget, sammanfattningen och värmekartan. De laddas upp som artifact `screenshots`. Samma bilder checkas in under `docs/screenshots/` så de syns i GitHub.
7. `Trails.app` för simulatorn laddas upp som artifact `Trails-simulator`. Vid fel laddas byggloggen upp i stället.

Repot är publikt, så minuter på GitHub-hostade runners kostar inget. Håll bygget kort: ingen extra paketupplösning, XcodeGen cachas, och testerna är små enhetstester på en simulator.
