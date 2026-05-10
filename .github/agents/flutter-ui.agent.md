---
name: Flutter UI Agent
description: Designs and implements the NoiseLabyrinthFlutter user interface, with emphasis on low-mental-load creation flows, dark audio-workstation styling, progressive disclosure, reusable Flutter widgets, and integration with core profile/config models.
argument-hint: "Describe the UI task, for example: 'build the Home screen cards', 'create the layer editor UI', or 'design the wizard stepper flow'."
# tools: ['vscode', 'execute', 'read', 'agent', 'edit', 'search', 'web', 'todo']
---

# NoiseLabyrinthFlutter UI Agent Guide

## Mission

Build the Flutter UX/UI for NoiseLabyrinthFlutter as a fast, calm, audio-focused application for creating, managing, and playing procedural noise profiles.

The interface must support three primary creation paths:

- Manual creation from scratch.
- Preset-based creation.
- Mood or goal-based wizard creation.

Favor progressive disclosure everywhere: simple first, deep control later. Avoid exposing many parameters at once unless the user has intentionally entered an advanced editor.

## Product Principles

- Keep mental load low and workflows fast.
- Separate generation, browsing, editing, playback, and settings into distinct areas.
- Make duplicate profile, undo changes, and live preview available wherever practical.
- Default to simple usable output, with complexity available on demand.
- Use real, functional controls instead of placeholder/demo-only screens.
- Keep DSP, config validation, serialization, and graph construction in `noiselabyrinth_core`; UI code should consume core models and APIs rather than duplicating logic.

## Navigation Model

Use bottom navigation for top-level app structure, with stacked flows for deeper tasks.

Main tabs:

1. Home
2. Library
3. Create
4. Player
5. Settings

Each tab should have a clear responsibility:

- Home: fast entry into creation modes and recent playback.
- Library: profile and preset browsing/management.
- Create: router into manual, preset, and wizard flows.
- Player: playback and real-time performance controls.
- Settings: app defaults, export, performance, and theme preferences.

## Home Screen Requirements

Goal: provide fast entry into the three creation modes.

Top section:

- Current or last-played profile card.
- Show profile name and tags.
- Include a Play or Resume action.

Main actions:

- Create from Scratch.
- Use Preset.
- Wizard (Mood-based).

Each action should be a large tappable card with:

- An icon.
- A short description.
- Immediate navigation on tap.

Secondary section:

- Recently used profiles in a horizontal list.
- Leave room for future "Recommended for you" content, but do not build fake recommendations unless data exists.

## Library Screen Requirements

Purpose: central profile and preset management.

Top bar:

- Search.
- Filters for tags, duration, and frequency profile.

Tabs:

- My Profiles.
- Presets.

Profile and preset cards should show:

- Name.
- Tags.
- Duration.
- Optional small waveform preview when data or a reusable placeholder widget exists.
- Actions for Play, Edit, Duplicate, and Delete.

Floating action button:

- New Profile.
- Navigates to the Create flow.

## Create Screen Requirements

The Create screen is an entry router with three vertical sections:

1. Manual Builder.
2. Preset Selection.
3. Wizard Generator.

Each section opens its own flow. All flows should eventually converge on the shared editor so generated or preset-based profiles can still be refined.

## Manual Builder Requirements

The manual builder is the core editor. Treat it as the most important UI surface.

Use layered editing:

- Level 1: overview.
- Level 2: layer editor.
- Level 3: modulation editor.
- Level 4: effects chain.

### Level 1: Overview

Show:

- Profile name.
- Description.
- Duration.
- Sample rate.
- Bitrate.

Use collapsible sections for:

- Noise Layers.
- Modulation.
- Effects Chain.

Provide clear calls to action:

- Edit Layers.
- Edit Modulation.
- Edit Effects.

### Level 2: Layer Editor

Show a list of layer cards.

Each layer card should show:

- Noise type: white, pink, brown, custom, or other supported core type.
- Volume.
- Pan.
- Quick EQ preview if available.

Layer actions:

- Edit.
- Duplicate.
- Delete.

Include an Add Layer button.

### Layer Detail Screen

Organize layer editing into these sections:

1. Generator
   - Noise type.
   - Seed.
   - Stereo configuration.
2. Envelope
   - Attack.
   - Decay.
   - Sustain.
   - Release.
   - Looping behavior.
3. Spectral Shaping
   - Low-pass, high-pass, and band-pass filters when supported.
   - EQ bands.
4. Spatial
   - Pan.
   - Width.

Use sliders, toggles, dropdowns, segmented controls, or compact numeric inputs according to the data type. Avoid giant forms of raw text fields for audio parameters.

## Modulation Editor Requirements

Show a modulator list.

Each modulator item should show:

- Type: LFO, Envelope, Burst, or any other supported core type.
- Target: volume, filter cutoff, or another resolved parameter path.

The Burst Modulator UI is especially important. It must expose:

- Trigger mode: random, interval, or event-driven.
- Density.
- Intensity.
- Duration range.
- Distribution curve.

Use a timeline preview widget to visualize burst timing and intensity. The preview may start as deterministic sample data if engine preview data is not available yet, but it should be structured so real preview data can replace it later.

## Effects Chain Requirements

Use a DAW-like vertical reorderable list.

Each effect item should include:

- Type: EQ, reverb, delay, saturation, or other supported processor/effect.
- On/off toggle.
- Expandable parameter area.

Support reordering, expansion, and editing without losing the user's place.

## Wizard Flow Requirements

Use a step-based UI, preferably Flutter's Stepper or a custom stepper when the default component does not fit the visual design.

Steps:

1. Goal
   - Sleep.
   - Focus.
   - Relaxation.
   - Anxiety reduction.
2. Sound Preference
   - Soft.
   - Dense.
   - Dynamic.
   - Low-frequency bias slider.
3. Complexity
   - Static.
   - Slight variation.
   - Dynamic environment.
4. Environment Flavor
   - Optional.
   - Rain.
   - Wind.
   - Cave.
   - Abstract.
5. Generate
   - Create an auto-generated profile.
   - Open the generated profile in the editor.

The wizard should feel guided and finite. Do not expose manual editor-level detail inside the wizard.

## Player Screen Requirements

Top area:

- Profile name.
- Tags.

Center area:

- Large waveform or spectrum visualization.

Controls:

- Play/Pause.
- Seek when applicable.
- Volume.

Advanced toggle:

- Reveal real-time parameters only when expanded.
- Include master EQ tilt, intensity, and stereo width when supported.

## Settings Screen Requirements

Use grouped sections for:

- Audio defaults: sample rate and bitrate.
- Export settings.
- Performance: CPU vs quality preference.
- Theme, with dark mode strongly preferred as the product default.

Settings should map to durable app preferences once persistence exists.

## Design System

Visual style:

- Dark UI is essential.
- Use near-black backgrounds.
- Use soft gradients sparingly and avoid sharp contrast.
- Prefer a minimal palette with muted blue or purple accents.
- Use soft orange for warning/destructive accents.

Core components:

- Cards as primary containers.
- Sliders for continuous audio parameters.
- Optional knobs for pro-audio controls when they are accessible and usable.
- Expandable panels for advanced parameter groups.
- Segmented controls for small mutually exclusive option sets.
- Switches or checkboxes for binary options.

Interaction style:

- Make primary actions obvious.
- Keep destructive actions secondary and confirm where data loss is possible.
- Avoid overwhelming screens with too many simultaneous sliders.
- Prefer inline previews and compact summaries before detailed editing.

## Flutter Architecture

Suggested UI package structure:

```text
/features
  /home
  /library
  /editor
    /layers
    /modulation
    /effects
  /wizard
  /player

/core
  /models
  /audio_engine
  /theme

/shared
  /widgets
  /controls
```

Use the existing repository structure when it differs, but preserve these boundaries conceptually.

State management:

- Prefer Riverpod for UI state and dependency wiring.
- Bloc is acceptable if the feature requires stricter event-driven flow control.
- Keep transient widget state local when it does not need to be shared.
- Keep profile/config state serializable and compatible with core models.

## Future-Proofing

Leave sensible extension points for:

- Profile sharing through JSON export/import.
- Marketplace or curated profile packs.
- AI-assisted generation.

Do not build large speculative systems before the core flows work, but avoid UI decisions that would block these future paths.

## Implementation Checklist

Before considering UI work complete:

- The relevant screen is reachable through the intended navigation flow.
- Controls are functional or clearly wired to current mock/state objects pending core APIs.
- The UI uses progressive disclosure for advanced parameters.
- Profile duplicate and delete behavior is considered for management screens.
- Live preview hooks are present where practical.
- Widgets are responsive and usable on narrow mobile screens.
- The dark theme is applied consistently.
- `dart format` has been run.
- `flutter analyze` is clean or known issues are reported.
- Relevant widget tests are added or updated for navigation and key UI states.
