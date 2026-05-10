---
name: Flutter Development Agent
description: Helps maintain and extend NoiseLabyrinthFlutter, with emphasis on the Dart core audio engine, deterministic DSP behavior, runtime graph construction, modulation, events, tests, and eventual Flutter UI integration.
argument-hint: "Describe the package and task, for example: 'in noiselabyrinth_core, add a new processor' or 'wire this config into the UI'."
# tools: ['vscode', 'execute', 'read', 'agent', 'edit', 'search', 'web', 'todo']
---

# NoiseLabyrinthFlutter Agent Guide

## Project Status

NoiseLabyrinthFlutter is a Dart/Flutter monorepo for procedural noise and audio generation.

- `noiselabyrinth_core` is the active package. It contains the runtime graph, audio engine, config models, modulation, event scheduling, DSP node stubs/implementations, WAV rendering, and tests.
- `noiselabyrinth_gui` currently remains close to the default Flutter starter app. Treat UI work as early-stage integration work.
- Dart SDK is `^3.11.5`.
- Core dependencies currently include Flutter, `flutter_lame`, and `scidart`.
- Linting uses `flutter_lints` through each package's `analysis_options.yaml`.

## Repository Layout

```text
NoiseLabyrinthFlutter/
├── noiselabyrinth_core/
│   ├── lib/
│   │   ├── engine/
│   │   │   ├── audio_engine.dart
│   │   │   ├── audio_node.dart
│   │   │   ├── event_engine.dart
│   │   │   ├── modulation_engine.dart
│   │   │   └── runtime_graph_builder.dart
│   │   ├── models/
│   │   │   ├── configs/
│   │   │   ├── enums.dart
│   │   │   ├── parameter.dart
│   │   │   └── smoothed_parameter.dart
│   │   └── noiselabyrinth_core.dart
│   └── test/
│       ├── engine/
│       ├── events/
│       ├── models/
│       └── modulation/
└── noiselabyrinth_gui/
    └── lib/main.dart
```

## Core Architecture

The core engine is block based and pull oriented. Preserve this model unless the project deliberately changes direction.

- `GenerationConfig` is turned into a `RuntimeGraph` by `RuntimeGraphBuilder`.
- Each layer is a constrained chain: `SourceNode -> ProcessorNode* -> layer output`.
- Layers are mixed into a mono master buffer in `AudioEngine`.
- `AudioEngine` owns per-layer buffers, the master buffer, modulation processing, event scheduling, parameter updates, and WAV rendering.
- Nodes use `Float32List` buffers and process blocks in place through `process(Float32List buffer, {Float32List? scratch})`.
- Runtime parameter lookup is resolved at graph-build time through `ParameterRegistry`, `ResolvedParameterReference`, and path aliases.
- Events trigger or reset modulators through resolved runtime bindings. Events do not live inside audio nodes.

Current implemented runtime concepts include:

- Sources: noise, impulse, sine.
- Processors: biquad, gain, saturator, delay.
- Modulators: sine LFO, smooth random, ADSR envelope, burst. `drift` is declared but not implemented.
- Events: periodic and poisson are active; random is declared but currently reserved for future behavior.
- Noise colors: white, pink, brown, bandlimited. Bandlimited currently falls back to white noise behavior.
- Biquad processor currently implements lowpass behavior; other modes are declared but not yet processed.

## DSP Rules

- Use `Float32List` for audio buffers and typed lists for hot paths.
- Avoid `List<double>` in DSP paths.
- Avoid allocations inside `process()` loops. Allocate in constructors, `prepare()`, or engine setup.
- Use deterministic randomness. Seed PRNG state explicitly or derive it deterministically from stable IDs.
- Do not call `Random()` per sample.
- Keep modulation separate from sources and processors.
- Apply modulation by accumulating into `Parameter.modulationValue`; parameters are updated once per block.
- Cache expensive DSP state such as filter coefficients and recompute only when inputs change.
- Clamp or guard invalid values in processors to avoid NaN, infinity, runaway feedback, or unstable filters.
- Prefer measured bottlenecks over speculative parallelism. Dart isolates may be considered later for layer rendering if profiling justifies it.

## Parameter Model

`Parameter` is the runtime parameter primitive:

- `baseValue` is the configured or user-set value.
- `modulationValue` accumulates modulation for the current block.
- `finalValue` is computed by `update()`.
- `update()` resets `modulationValue` for the next block.

Use `SmoothedParameter` when abrupt changes would click or destabilize DSP, such as gain, filter frequency, drive, feedback, or mix.

## Config And Serialization

Configuration classes live in `noiselabyrinth_core/lib/models/configs/`.

- Keep config classes immutable with `final` fields.
- Use named constructor parameters with sensible defaults.
- Implement `toJson()` and `fromJson()` for persisted configs.
- Use enums from `models/enums.dart` instead of stringly typed concepts.
- Add validation in config or dedicated validation helpers when invalid combinations would fail later at graph-build time.
- Keep JSON parsing defensive but do not silently accept impossible DSP settings if they would produce undefined behavior.

## Runtime Graph And Targeting

Modulation targets should resolve before rendering starts.

- Prefer explicit target paths registered in `ParameterRegistry`.
- Avoid string lookup inside the audio loop.
- When adding a source or processor parameter, register both direct node/parameter references and any path aliases expected by configs or tests.
- If a target path cannot be resolved, throw a clear `StateError` during graph build.

Current target path style examples:

```text
layers[layer-id].gain
layers[layer-id].source.noise.band.low
layers[layer-id].source.impulse.density
layers[layer-id].processors[processor-id].config.frequency
layers[layer-id].processors[processor-id].delay.feedback
```

## Adding Features

When adding a source:

- Add or extend config in `models/configs/source_config.dart`.
- Add enum values in `models/enums.dart` only when needed.
- Implement a `SourceNode` in `runtime_graph_builder.dart` or split nodes into dedicated files if the file grows too large.
- Register parameters in `_registerSourceParameters`.
- Add tests in `test/engine/audio_sources_test.dart` or a focused new test file.

When adding a processor:

- Add config in `models/configs/processor_config.dart`.
- Implement a `ProcessorNode`.
- Allocate state in constructor or `prepare()`.
- Keep `process()` allocation-free.
- Register parameters in `_registerProcessorParameters`.
- Add tests in `test/engine/processors_test.dart`.

When adding modulation:

- Add config fields in `models/configs/modulation_config.dart`.
- Extend `ModulatorFactory`.
- Ensure `process(int blockSize, Float32List buffer)` fills the provided buffer.
- Implement deterministic `trigger()` and `reset()` behavior when relevant.
- Add tests in `test/modulation/modulators_test.dart`.

When adding events:

- Add or extend config in `models/configs/event_config.dart`.
- Bind actions to existing runtime modulation bindings.
- Keep scheduler behavior deterministic and block based.
- Add tests in `test/events/event_scheduling_test.dart`.

## Testing Expectations

Tests are part of the implementation, especially in `noiselabyrinth_core`.

- Run package tests from the package directory: `flutter test`.
- Run static analysis from the package directory: `flutter analyze`.
- Prefer behavior-focused test names.
- Cover serialization round trips for config changes.
- Cover graph-build failures for invalid or unresolved references.
- Cover deterministic output when randomness, events, or modulation are involved.
- Do not update tests to preserve incorrect DSP behavior. Fix the implementation or adjust the expectation only when the spec changed.

Useful existing test areas:

- `test/models/configuration_models_test.dart`
- `test/models/parameter_models_test.dart`
- `test/engine/runtime_graph_builder_test.dart`
- `test/engine/audio_engine_test.dart`
- `test/engine/audio_sources_test.dart`
- `test/engine/processors_test.dart`
- `test/modulation/modulators_test.dart`
- `test/events/event_scheduling_test.dart`

## Style

- Follow Dart and Flutter conventions.
- File names use `snake_case.dart`.
- Types use `PascalCase`.
- Variables, fields, methods, and constants use lower camel case.
- Keep imports organized and remove unused imports.
- Keep comments short and useful. DSP formulas, stability decisions, and non-obvious runtime behavior deserve comments; ordinary Dart syntax does not.
- Favor existing project patterns over introducing new abstractions.
- Keep edits scoped to the package and feature being changed.

## UI Guidance

The UI package is not yet representative of the product. For UI work:

- Keep core logic in `noiselabyrinth_core`; the UI should consume configs and engine APIs.
- Avoid duplicating DSP, config validation, or graph logic in Flutter widgets.
- Build real controls and workflows rather than demo-only screens.
- Keep platform concerns isolated from core models and rendering logic.

## Dependency Guidance

- Add core logic dependencies to `noiselabyrinth_core/pubspec.yaml`.
- Add application/UI dependencies to `noiselabyrinth_gui/pubspec.yaml`.
- Prefer cross-platform packages.
- Avoid adding dependencies for small utilities that can be implemented clearly in Dart.
- After changing dependencies, run `flutter pub get` in the affected package.

## Development Checklist

Before considering work done:

- Code is formatted with `dart format`.
- Static analysis is clean or known issues are reported.
- Relevant tests pass.
- New public behavior has tests.
- Hot DSP paths avoid new per-sample or per-block allocations unless intentionally justified.
- Runtime graph paths and parameter aliases are updated when new parameters are introduced.
- The project exports any new public API from `noiselabyrinth_core.dart` when it is intended for package consumers.

## Current Limitations To Respect

- The UI is still a starter app.
- Some declared enum values are forward-looking and not fully implemented.
- Some audio nodes are intentionally minimal; check the current implementation before assuming complete DSP coverage.
- The engine currently mixes mono buffers.
- Scratch buffers are optional and not universally required by nodes.
- Platform audio playback is not yet the center of the codebase; offline rendering and testable core behavior are the current priority.
