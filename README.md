# Flights (Flutter — Android, iOS/iPadOS & macOS)

Cross-platform Flutter version of **Flights**, the airport-code shortest-route puzzle game from [`jotto-cli`](https://github.com/guslipkin/jotto-cli) created by [Gus Lipkin](https://guslipkin.me), targeting:
- **Android** (`me.guslipkin.flights`)
- **iOS & iPadOS** (Universal iPhone + iPad target, `TARGETED_DEVICE_FAMILY = "1,2"`)
- **macOS** (Apple Silicon `arm64`)

## Features

- **100% Offline Vector Flight-Deck Radar Map**:
  - Renders Natural Earth's coastlines at three detail scales (`1:110m`, `1:50m`, `1:10m`) from `assets/coastlines.bin`.
  - Smooth multi-touch pinch-to-zoom, pan/drag, macOS trackpad/mouse-wheel zoom, double-tap zoom, full-screen toggle (`Full` / `Exit Full`), and `Fit` auto-framing across the antimeridian (`±180°`).
  - Great-circle curved flight arcs (or straight lines) in the colorblind-safe Okabe-Ito palette, with collision-avoiding monospace IATA labels.
- **Touch & Click Interaction**:
  - Touch, by default: tap an option row (or an orange airport on the radar map) once to highlight it and preview its hop arc, then tap it again or press `Fly →` to fly. Settings → **Tap to fly** → *One tap* flies on the first tap instead.
  - Mouse/trackpad: a click flies straight away, as in `jotto-cli`; preview with `↑`/`↓` instead.
  - Dedicated `← Go Back` button to undo hops back to the origin.
- **Keyboard & Mouse Controls** (when a keyboard is attached, matching the `jotto-cli` TUI): `↑`/`↓` select an option (or a hop once the game is over), `→`/`Enter` fly, `←`/`Backspace` go back, `PgUp`/`PgDn` scroll the route, `+`/`-` zoom, `W`/`A`/`S`/`D` pan, `0` re-fits the map, `Esc` leaves the full-screen map, `?` opens help, and `Ctrl` (or `⌘`) + `N` new game, `T` daily, `D` next difficulty, `G` give up, `U` units, `S` settings. Mouse wheel zooms and dragging pans the map. Help lists the keys on macOS, or once a key has been pressed.
- **Full `jotto-cli` Feature & Daily Challenge Parity**:
  - All 5 difficulty levels: **Easy** (up to 4 hops; map, distances & connections), **Medium** (up to 6 hops; map & connections), **Hard** (up to 8 hops; connections only), **Pilot** (any length; codes only), and **Custom**.
  - **Exact UTC Daily Challenge Parity**: Ports `fastrand 2.5.0` (64-bit WyRand v4.2 + Lemire's divisionless range reduction) so Flutter and `flights --daily` on the CLI deal the exact same daily puzzle every UTC day.
  - **Post-Game Route Comparison & Hop Stepper**: When a game ends (win or give up), expands the route panel, marks where your route diverged from the shortest route (`↑ you left here`, `↑ went here`), and lets you step through each hop on the map.
  - **Adaptive Layout & Orientation**: Portrait-locked on phones (`shortestSide < 600`), full rotation support on iPad and a resizable macOS window (down to 380pt wide). Whenever the window is wider than tall (and at least 760pt wide) the layout is side-by-side: the right-hand column takes a third of the width (300–440pt) and all the remaining width goes to the map. Taller than wide, including a portrait iPad or a narrowed Mac window, the map stacks on top of the options; the options box keeps a fixed height for the window size (at most 380pt, so it doesn't jump between hops) and all the remaining height goes to the map. Dialogs widen in landscape.
  - **Tactile Haptics & Real Commercial Jet Audio**: Subtle haptic pulses and short real commercial jet flyby sounds on hops, backtracking, longer arrivals, and victory (toggleable in Settings).
  - **Themes**: Light, Dark, or System (follows the device, live), chosen in Settings. Dark comes in two styles: the original Navy, or pure Black for OLED screens. The light theme uses darker Okabe-Ito accents so colored text stays readable on white.
  - **Autosave**: Automatically saves your in-progress game, units (`nm` / `mi` / `km`), map line mode, theme, and custom game rules after every move.

## Syncing Data from `../jotto-cli`

To refresh `assets/flights.tsv` and `assets/coastlines.bin` from `../jotto-cli/data`:

```bash
./scripts/sync-data.sh
```

## App Icon

The icon (a gull drawn as two flight arcs between three airports) has one source, `assets/icon/flights_icon.svg`. After editing it, regenerate every platform's icons on a Mac and commit the results:

```bash
./scripts/render-icons.sh
```

It renders the SVG with AppKit (`scripts/svg2png.swift`, which keeps transparency) into three PNGs in `assets/icon/`: the full square for iOS and older Android, a transparent foreground shrunk into the safe zone of Android's adaptive-icon masks, and a rounded tile on Apple's icon grid for macOS. It then runs [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons) (configured in `pubspec.yaml`) to write the Android, iOS and macOS icon sets.

## Building & Testing

```bash
# Run unit tests (verifies Fastrand, daily puzzle parity, coastline geometry, game engine, and keyboard controls)
flutter test

# Build Android release APK
flutter build apk --release

# Build iOS & iPadOS universal app bundle
flutter build ios --release --no-codesign

# Build macOS (Apple Silicon arm64) release app bundle
flutter build macos --release
```

## CI & Releases (GitHub Actions)

- **CI** (`.github/workflows/ci.yml`): `flutter analyze` and `flutter test` on every push to `main` and every PR, on a Linux runner.
- **Release** (`.github/workflows/release.yml`): pushing a version tag such as `v1.2.3` runs the tests, then builds and attaches to that tag's GitHub release:
  - `Flights-android.apk` (signed with Flutter's debug key, fine for sideloading but not for the Play Store)
  - `Flights-macos-arm64.zip` (unsigned: on first open, right-click → Open, or allow it in System Settings → Privacy & Security)
  - `Flights-ios-unsigned.ipa` (must be re-signed before it installs on a device)

  If the release doesn't exist yet it is created with generated notes; one written by hand first is kept. The app version comes from the tag (`1.2.3`) and the build number from the run number (`scripts/ci-build-args.sh`). Run the workflow by hand from the Actions tab to get the same builds as downloadable artifacts without a release.
- The iOS/macOS job runs on a macOS runner, which bills at 10× minutes on a private repo, so it only runs on tags or by hand. Signed builds (Play Store, notarized macOS, TestFlight) need signing keys added as repository secrets.

## Credits & License

- **Flights** is an original game conceived and created by [Gus Lipkin](https://guslipkin.me).
- Routes from the "Airlines and destinations" sections of [English Wikipedia](https://en.wikipedia.org/)'s airport articles, under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
- Airport codes and coordinates from [OurAirports](https://ourairports.com/data/) (public domain).
- Map coastlines from [Natural Earth](https://www.naturalearthdata.com/) (public domain).
- Jet audio recordings from [Wikimedia Commons](https://commons.wikimedia.org/) (*Jet airliner overhead* and *Airplane Boeing Flyby* by InspectorJ, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)).
