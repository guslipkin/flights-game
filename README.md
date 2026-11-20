<p align="center">
  <img src="assets/icon/flights_icon_macos.png" alt="Flights icon: a bird drawn as two flight arcs between three airports" width="160">
</p>

<h1 align="center">Flights</h1>

<p align="center">Find the shortest route between two airports, one hop at a time.</p>

Flights is the airport-code route puzzle from [`jotto-cli`](https://github.com/guslipkin/jotto-cli), created by [Gus Lipkin](https://guslipkin.me), rebuilt in Flutter for:

- **Android** (`me.guslipkin.flights`)
- **iPhone and iPad** (one universal app)
- **macOS** (Apple Silicon)

## Playing

Each game deals a start and a destination airport. Pick a flight from the list of connections, keep hopping, and try to arrive in as few hops as the shortest route. `← Go Back` undoes hops, and when the game ends (by arriving or giving up) the route panel shows where your route left the shortest one and lets you step through each hop on the map.

**Touch:** tap an option (or an orange airport on the map) to preview its hop, then tap it again or press `Fly →`. Settings → **Tap to fly** → *One tap* flies on the first tap instead.

**Mouse and trackpad:** a click flies straight away, as in `jotto-cli`. The scroll wheel zooms and dragging pans the map.

**Keyboard** (matching the `jotto-cli` TUI; Help lists the keys on macOS, or once a key has been pressed):

| Key | Action |
|---|---|
| `↑` / `↓` | Select an option (or a hop once the game is over) |
| `→` / `Enter` | Fly |
| `←` / `Backspace` | Go back |
| `PgUp` / `PgDn` | Scroll the route |
| `+` / `-` | Zoom the map |
| `W` `A` `S` `D` | Pan the map |
| `0` | Fit the map |
| `Esc` | Leave the full-screen map |
| `?` | Help |
| `Ctrl`/`⌘` + `N` / `T` / `D` / `G` / `U` / `S` | New game / daily / next difficulty / give up / units / settings |

### Difficulty

| Level | Hop limit | Shown |
|---|---|---|
| Easy | 4 | Map, distances and connections |
| Medium | 6 | Map and connections |
| Hard | 8 | Connections only |
| Pilot | None | Codes only |
| Custom | Your choice | Your choice |

### Daily challenge

The daily puzzle is the same for everyone each UTC day, and the same one `flights --daily` deals on the CLI: the app ports `fastrand` 2.5.0's random number generator so both pick identical puzzles.

## Features

- **Offline map:** Natural Earth coastlines at three levels of detail, with pinch, scroll and double-tap zoom, panning, full screen, and `Fit` framing that works across the antimeridian. Hops are drawn as great-circle arcs or straight lines in the colorblind-safe Okabe-Ito palette, with labels that avoid overlapping.
- **Layout:** whenever the window is wider than tall (and at least 760pt wide), the map sits beside a side column that takes a third of the width, between 300 and 440pt. Otherwise the map stacks above the options, whose box has a fixed height (at most 380pt) so it doesn't jump between hops. Either way, the map gets all the remaining space and keeps its zoom when the window is resized. Phones are locked to portrait; iPads rotate and Mac windows resize down to 380pt wide.
- **Themes:** Light, Dark or System (follows the device). Dark comes in Navy or Black (for OLED screens). The light theme uses darker accents so colored text stays readable on white.
- **Sound and haptics:** short jet flyby sounds and haptic pulses for hops, going back, long flights and winning. Either can be turned off in Settings.
- **Autosave:** the game in progress, units (`nm`, `mi` or `km`), map line style, theme and custom rules are saved after every move.

## Development

```bash
flutter test                                # engine, daily parity, coastlines, keyboard, layout, themes
flutter build apk --release                 # Android
flutter build ios --release --no-codesign   # iPhone and iPad
flutter build macos --release               # macOS
```

The builds land in `build/app/outputs/flutter-apk/app-release.apk`, `build/ios/iphoneos/Runner.app` and `build/macos/Build/Products/Release/Flights.app`. To install on an iPhone or iPad, open `ios/Runner.xcworkspace` in Xcode and run it from there with your team selected.

### Data

`assets/flights.tsv` and `assets/coastlines.bin` come from `jotto-cli`. To refresh them from `../jotto-cli/data`:

```bash
./scripts/sync-data.sh
```

### App icon

The icon has one source, `assets/icon/flights_icon.svg`. After editing it, regenerate every platform's icons on a Mac and commit the results:

```bash
./scripts/render-icons.sh
```

The script renders the SVG with AppKit (`scripts/svg2png.swift`, which keeps transparency) into three PNGs in `assets/icon/`: a full square for iOS and older Android, a transparent foreground that fits inside Android's adaptive-icon masks, and a rounded tile on Apple's icon grid for macOS. It then runs [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons) (configured in `pubspec.yaml`) to write each platform's icon set.

### CI and releases

- **CI** (`.github/workflows/ci.yml`) runs `flutter analyze` and `flutter test` on every push to `main` and every pull request.
- **Release** (`.github/workflows/release.yml`) runs when a version tag such as `v1.2.3` is pushed. It runs the tests, then builds and attaches these to the tag's GitHub release:
  - `Flights-android.apk`, signed with Flutter's debug key: fine for sideloading, not for the Play Store.
  - `Flights-macos-arm64.zip`, unsigned: on first open, right-click → Open, or allow it in System Settings → Privacy & Security.
  - `Flights-ios-unsigned.ipa`, which must be re-signed before it will install.

If the release doesn't exist yet it's created with generated notes; one written by hand beforehand is kept. The app version comes from the tag and the build number from the workflow run number (`scripts/ci-build-args.sh`). Running the workflow by hand from the Actions tab produces the same builds as downloadable artifacts, without a release.

The Apple builds use a macOS runner, which bills at 10× the minutes on a private repo, so they only run on tags or by hand. Signed builds (Play Store, notarized macOS, TestFlight) need signing keys added as repository secrets.

## Credits and license

- **Flights** is an original game created by [Gus Lipkin](https://guslipkin.me).
- Routes from the "Airlines and destinations" sections of [English Wikipedia](https://en.wikipedia.org/) airport articles, under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
- Airport codes and coordinates from [OurAirports](https://ourairports.com/data/) (public domain).
- Map coastlines from [Natural Earth](https://www.naturalearthdata.com/) (public domain).
- Jet sounds from [Wikimedia Commons](https://commons.wikimedia.org/): *Jet airliner overhead* and *Airplane Boeing Flyby* by InspectorJ, under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
