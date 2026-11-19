# Flights for Android

Native Android (Kotlin + Jetpack Compose) version of **Flights**, the airport-code shortest-route puzzle game from [`jotto-cli`](https://github.com/guslipkin/jotto-cli) created by [Gus Lipkin](https://guslipkin.me).

## Features

- **100% Offline Vector Flight-Deck Radar Map**:
  - Renders Natural Earth's coastlines at three detail scales (`1:110m`, `1:50m`, `1:10m`) from `coastlines.bin`.
  - Smooth multi-touch pinch-to-zoom, pan/drag, double-tap zoom, and `[Fit]` auto-framing across the antimeridian (`±180°`).
  - Great-circle curved flight arcs (or straight lines) in the colorblind-safe Okabe-Ito palette, with collision-avoiding monospace IATA labels.
- **Two-Step Touch Interaction**:
  - Tap any option row (or tap an orange airport node on the radar map) once to highlight it and preview its hop arc on the map.
  - Tap the selected option again or press `[Fly →]` to commit the flight.
  - Dedicated `[← Go Back]` button to undo hops back to the origin.
- **Full `jotto-cli` Feature & Daily Challenge Parity**:
  - All 5 difficulty levels: **Easy** (up to 4 hops; map, distances & connections), **Medium** (up to 6 hops; map & connections), **Hard** (up to 8 hops; connections only), **Pilot** (any length; codes only), and **Custom**.
  - **Exact UTC Daily Challenge Parity**: Ports `fastrand 2.5.0` (64-bit WyRand v4.2 + Lemire's divisionless range reduction) so Android and `flights --daily` on the CLI deal the exact same daily puzzle every UTC day.
  - **Post-Game Route Comparison & Hop Stepper**: When a game ends (win or give up), auto-expands the route panel, marks where your route diverged from the shortest route (`↑ you left here`, `↑ went here`), and lets you step through each hop on the map.
  - **Shareable Results**: Share your route summary and emoji flight chain via the Android share sheet.
  - **Tactile Haptics & Flight-Deck Audio Chimes**: Subtle haptic pulses and synthesized cabin chimes on hops, backtracking, longer arrivals, and victory (toggleable in Settings).
  - **Autosave**: Automatically saves your in-progress game, units (`nm` / `mi` / `km`), map line mode, and custom game rules after every move.

## Syncing Data from `../jotto-cli`

To refresh `app/src/main/assets/flights.tsv` and `app/src/main/assets/coastlines.bin` from `../jotto-cli/data`:

```bash
./scripts/sync-data.sh
```

## Building & Testing

```bash
# Run unit tests (verifies Fastrand, daily puzzle parity, coastline geometry, and game engine)
./gradlew testDebugUnitTest

# Build debug APK
./gradlew assembleDebug
```

## Credits & License

- **Flights** is an original game conceived and created by [Gus Lipkin](https://guslipkin.me).
- Routes from the "Airlines and destinations" sections of [English Wikipedia](https://en.wikipedia.org/)'s airport articles, under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
- Airport codes and coordinates from [OurAirports](https://ourairports.com/data/) (public domain).
- Map coastlines from [Natural Earth](https://www.naturalearthdata.com/) (public domain).
- Jet audio recordings from [Wikimedia Commons](https://commons.wikimedia.org/) (*Jet airliner overhead* and *Airplane Boeing Flyby* by InspectorJ, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)).
