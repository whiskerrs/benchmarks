# Shop app benchmark

The same Shopify storefront app, built by an AI from one identical prompt with each of React Native, Flutter, Whisker, Native Shell, NativeScript, and Exact, then measured on a physical iPhone. UIKit, SwiftUI, NativePHP, and DartNative were added two days later, some with a prompt variant (`prompt/frameworks.md`); DartNative was built but not measured (`results/2026-11-13/README.md`).

| Directory | Contents |
|---|---|
| `prompt/` | The prompt given to the AI, its GraphQL operations, per-framework values, and the run protocol |
| `design/` | The visual design the prompt references |
| `apps/` | The app each run produced |
| `measurement/` | What is measured and how |
| `tools/` | Replay server, XCUITest runner, and measurement driver |
| `results/` | Raw traces and summaries |

Order of work:

1. Build each app with the AI (`prompt/README.md`).
2. Record replay data: `tools/replay/replay.py crawl`, then each app's journey once against `record`.
3. Measure each app against `serve` with `tools/bench.py` (`tools/README.md`, `measurement/README.md`).

## License

MIT, see `LICENSE`. Not covered:

- `design/img/` and `tools/replay/data/`: product images and API responses from Shopify's [mock.shop](https://mock.shop), kept as reference and replay data.
- Files the framework templates and toolchains generated under `apps/` keep the license stated in them.
