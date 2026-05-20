---
name: Flutter Development Agent
description: Helps maintain and extend NoiseLabyrinth, with emphasis on the Dart core audio engine, deterministic DSP behavior, runtime graph construction, modulation, events, tests, and Flutter UI integration.
argument-hint: "Describe the package and task, for example: 'in noiselabyrinth_core, add a new processor' or 'wire this config into the UI'."
# tools: ['vscode', 'execute', 'read', 'agent', 'edit', 'search', 'web', 'todo']
---

# NoiseLabyrinth Agent Guide

## Project Status

NoiseLabyrinth is a Dart/Flutter monorepo for procedural noise and audio generation.

- `noiselabyrinth_core` contains DSP/runtime graph logic, config models, modulation/events, renderer, presets, and most engine tests.
- `noiselabyrinth_gui` is an active app (not a starter shell) with persistence, a config editor, preview playback, and export flows.
- `noiselabyrinth_shared` holds shared utilities such as MP3 rendering, MFCC extraction, ID3 tagging, render policies, and profile catalog helpers.
- `noiselabyrinth_test_cli` is a CLI package used for testing and experimentation.
- Dart SDK is `^3.11.5`.

## Repository Layout

```text
NoiseLabyrinth/
├── noiselabyrinth_core/
│   ├── lib/
│   │   ├── engine/
│   │   │   ├── audio_engine.dart
│   │   │   ├── audio_node.dart
│   │   │   ├── dsp/biquad.dart
│   │   │   ├── event_engine.dart
│   │   │   ├── graph_nodes/
│   │   │   ├── modulators/
│   │   │   ├── modulation_engine.dart
│   │   │   ├── renderer.dart
│   │   │   └── runtime_graph_builder.dart
│   │   ├── models/
│   │   │   ├── configs/
│   │   │   ├── enums.dart
│   │   │   ├── parameter.dart
│   │   │   └── smoothed_parameter.dart
│   │   ├── presets/
│   │   └── noiselabyrinth_core.dart
│   └── test/
│       ├── engine/
│       ├── events/
│       ├── models/
│       ├── modulation/
│       └── test_helpers/
├── noiselabyrinth_gui/
│   ├── lib/
│   │   ├── persistence/
│   │   ├── state/
│   │   └── widgets/
│   └── test/
├── noiselabyrinth_shared/
│   └── lib/src/
│       ├── audio/
│       ├── config/
│       ├── export/
│       └── profiles/
└── noiselabyrinth_test_cli/
```

## Core Architecture

The core engine is block based and pull oriented. Preserve this unless there is an explicit architectural change.

- `GenerationConfig` is turned into a `RuntimeGraph` by `RuntimeGraphBuilder`.
- Each layer is a constrained chain: `SourceNode -> ProcessorNode* -> layer output`.
- Layers are generated in mono and mixed to stereo master buffers in `AudioEngine`.
- `AudioEngine` owns per-layer buffers, master buffers, modulation/event processing, and parameter updates.
- Nodes process in place via `process(Float32List buffer, {Float32List? scratch})`.
- Runtime target resolution is built ahead of rendering through `ParameterRegistry` and path aliases.
- Events trigger/reset modulators through runtime bindings; events are not embedded inside audio nodes.

Current implemented runtime concepts include:

- Sources: noise, impulse, sine.
- Processors: biquad, gain, saturator, delay.
- Modulators: LFO, smooth random, drift, ADSR envelope, burst.
- Triggers: periodic, poisson, random.
- Noise colors: white, pink, brown, bandlimited.
- Biquad modes: lowpass, highpass, bandpass, peak.

## Renderer Boundary

- `noiselabyrinth_core` renderer outputs stereo float PCM (`renderPcm`, `renderPcmChunks`).
- Container/codec responsibilities (for example MP3) should stay in consumer/shared packages, not in core DSP internals.
- Keep core deterministic and test-friendly for offline rendering.

## DSP Rules

- Use `Float32List` and typed buffers in hot paths.
- Avoid `List<double>` in DSP loops.
- Avoid allocations inside `process()` loops.
- Keep randomness deterministic and seed-driven.
- Do not instantiate `Random()` per sample.
- Keep modulation separate from source/processor DSP.
- Apply modulation through `Parameter.modulationValue`; call `update()` once per block.
- Recompute expensive coefficients only when inputs change.
- Guard/clamp invalid values to prevent NaN/infinity/runaway behavior.

## Parameter Model

`Parameter` is the runtime primitive:

- `baseValue`: configured/user value.
- `modulationValue`: per-block accumulated modulation.
- `finalValue`: computed result after update.
- `update()`: computes final value and clears block modulation accumulation.

Use `SmoothedParameter` for click-sensitive parameters (gain, pan, frequency, drive, feedback, mix).

## Config Model And Serialization

Configuration classes are under `noiselabyrinth_core/lib/models/configs/`.

- Current config objects are mutable and editor flows depend on mutation + notifier commits.
- Keep `toJson()` / `fromJson()` robust and compatible with existing stored data.
- Use enums from `models/enums.dart` over ad-hoc strings.
- Add validation through `config_validation.dart` when new combinations can fail graph build.

## Runtime Targeting

- Resolve modulation targets before rendering.
- Register node parameters and path aliases in `RuntimeGraphBuilder`.
- Prefer paths from `ModulationTargetCatalog` to keep UI/runtime conventions aligned.
- Throw clear `StateError` when target resolution fails.

Common path style examples:

```text
layers[layer-id].gain
layers[layer-id].pan
layers[layer-id].source.noise.band.low
layers[layer-id].source.noise.band.high
layers[layer-id].source.impulse.density
layers[layer-id].source.impulse.randomness
layers[layer-id].source.sine.frequencyHz
layers[layer-id].processors[processor-id].biquad.frequency
layers[layer-id].processors[processor-id].delay.feedback
layers[layer-id].processors[processor-id].delay.mix
```

## Adding Features

When adding a source:

- Extend `models/configs/source_config.dart` and enums if needed.
- Implement node under `engine/graph_nodes/`.
- Register source parameters in `_registerSourceParameters`.
- Add coverage in `test/engine/audio_sources_test.dart` (or focused test file).

When adding a processor:

- Extend `models/configs/processor_config.dart`.
- Implement node under `engine/graph_nodes/`.
- Allocate persistent state in constructor/`prepare()`.
- Keep `process()` allocation-free.
- Register processor parameters in `_registerProcessorParameters`.
- Add/extend `test/engine/processors_test.dart`.

When adding modulation:

- Extend `models/configs/modulation_config.dart`.
- Extend `ModulatorFactory`.
- Ensure `process(int blockSize, Float32List buffer)` fills provided output.
- Implement deterministic `trigger()` / `reset()` behavior.
- Add tests in `test/modulation/modulators_test.dart`.

When adding events:

- Extend `models/configs/event_config.dart`.
- Bind actions through runtime modulation bindings.
- Preserve deterministic, block-based scheduler semantics.
- Add tests in `test/events/event_scheduling_test.dart`.

When adding export/shared audio behavior:

- Keep DSP and graph logic in `noiselabyrinth_core`.
- Put codec/container/platform-specific logic in `noiselabyrinth_shared` (or app package where appropriate).
- Preserve conditional import/export patterns for web/native compatibility.

## Testing Expectations

Run tests from each package directory:

- `noiselabyrinth_core`: `flutter test`
- `noiselabyrinth_gui`: `flutter test`
- `noiselabyrinth_shared`: `flutter test`
- `noiselabyrinth_test_cli`: `dart test`

Static analysis:

- Use package-appropriate analyze command (`flutter analyze` or `dart analyze`).
- Keep behavior-focused test names.
- Cover serialization round trips for config changes.
- Cover graph-build failures for invalid/unresolved references.
- Cover deterministic behavior for randomness/modulation/events.

Useful core test areas:

- `test/models/configuration_models_test.dart`
- `test/models/config_validation_test.dart`
- `test/models/parameter_models_test.dart`
- `test/engine/runtime_graph_builder_test.dart`
- `test/engine/audio_engine_test.dart`
- `test/engine/audio_sources_test.dart`
- `test/engine/processors_test.dart`
- `test/engine/renderer_test.dart`
- `test/engine/signal_validation_test.dart`
- `test/engine/profile_validation_harness_test.dart`
- `test/engine/profile_validation_quality_diagnostics_test.dart`
- `test/modulation/modulators_test.dart`
- `test/events/event_scheduling_test.dart`

## Style

- Follow Dart/Flutter conventions.
- File names: `snake_case.dart`.
- Types: `PascalCase`.
- Members: lower camel case.
- Keep imports tidy and remove unused imports.
- Keep comments short and useful, especially around DSP math/stability behavior.
- Favor existing repository patterns over new abstractions unless needed.

## UI Guidance

UI is no longer just starter scaffolding. Existing editor, preview, and persistence flows should be extended carefully.

- Keep DSP/config validation in `noiselabyrinth_core`.
- Keep UI state changes aligned with existing providers/notifiers under `state/`.
- Avoid duplicating graph logic in widgets.
- Keep platform-specific behavior isolated (for example export destination handling).

## Dependency Guidance

- Add DSP/runtime deps to `noiselabyrinth_core/pubspec.yaml`.
- Add app/UI deps to `noiselabyrinth_gui/pubspec.yaml`.
- Add cross-package shared deps to `noiselabyrinth_shared/pubspec.yaml`.
- Prefer cross-platform packages.
- Run `flutter pub get` in each affected package after dependency changes.

## Development Checklist

Before considering work complete:

- Code formatted with `dart format`.
- Analysis clean, or known residual issues documented.
- Relevant tests pass.
- New public behavior includes tests.
- Hot DSP paths avoid unnecessary allocations.
- Runtime path aliases are updated when parameters change.
- Intended public APIs are exported from `noiselabyrinth_core.dart` and/or `noiselabyrinth_shared.dart`.

For GUI edits:

- Persistence/repository behavior remains compatible with stored configs.
- Preview/export flows are validated for changed behavior.

## Current Limitations To Respect

- `README.md` is currently minimal; prefer code and tests as source of truth.
- Some enum values and behaviors may still be evolving.
- Some nodes remain intentionally simple; verify implementation detail before assuming production-grade DSP completeness.
- Scratch buffers remain optional and not universally required.
- Keep core deterministic/offline-render friendly even when improving live preview UX.
