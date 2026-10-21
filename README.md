# Trackin' Trails

Trackin' Trails är en liten iOS-app som visar löprundor med GPS-rutt. Xcode-målet och produktnamnet är **Trails**, visningsnamnet på hemskärmen och i appen är **Trackin' Trails**, och bundle-id är `com.legionorange.trails`.

Appen gör fyra saker:

1. Läser löppass från Hälsa (`HKWorkout` med aktivitetstypen löpning) och deras GPS-rutter (`HKWorkoutRoute`).
2. Visar passen i en lista och ritar varje rutt som en linje på en SwiftUI-karta.
3. Låter dig markera rutter. Markeringarna sparas lokalt med SwiftData och visas tillsammans: en karta med alla markerade rutter och en lista med datum, distans och tid.
4. Söker i bildbiblioteket efter foton tagna mellan passets start och mål, visar miniatyrer och öppnar bilden vid tryck.

Simulatorn har ingen riktig hälsodata. Därför finns en inbyggd exempelkälla med fyra rundor runt Stockholm och genererade exempelbilder, så att gränssnittet går att köra i simulatorn och i SwiftUI-previews. På en enhet där Hälsa finns är **Hälsa** förvald. I simulatorn är **Exempel** förvald. Källan byts i menyn uppe till höger.

Det finns inget Apple Developer-konto i det här läget, och appen kodsigneras inte. Inget TestFlight och inga certifikat.

## Struktur

```text
project.yml                         XcodeGen-spec. Det här är källan till Xcode-projektet.
Trails/
  TrailsApp.swift                   Start, SwiftData-container och datakällor
  AppModel.swift                    Lista, markeringar, källbyte
  Models.swift                      RunWorkout, WorkoutPhoto, FavoriteMark
  WorkoutSources.swift              HealthKit och exempelpass
  PhotoSources.swift                PhotoKit och exempelbilder
  FavoritesRepository.swift         Lokala markeringar
  RouteGeometry.swift               Längd, kartregion, listminiatyr
  RunFormatting.swift               Svensk formatering och tidsfönster
  Info.plist                        Visningsnamn och användningssträngar
  Trails.entitlements               com.apple.developer.healthkit
  Views/                            Lista, detalj, karta, markerade rutter
TrailsTests/                        Enhetstester för geometri, exempeldata och markeringar
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
5. `xcodebuild test` bygger appen och kör `TrailsTests` med `CODE_SIGNING_ALLOWED=NO`.
6. `Trails.app` för simulatorn laddas upp som artifact `Trails-simulator`. Vid fel laddas byggloggen upp i stället.

Repot är publikt, så minuter på GitHub-hostade runners kostar inget. Håll bygget kort: ingen extra paketupplösning, XcodeGen cachas, och testerna är små enhetstester på en simulator.
