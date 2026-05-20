---
name: Flutter UI Agent
description: Designs and implements the NoiseLabyrinthFlutter user interface, with emphasis on low-mental-load creation flows, dark audio-workstation styling, progressive disclosure, reusable Flutter widgets, and integration with core profile/config models.
argument-hint: "Describe the UI task, for example: 'improve Quick start actions', 'extend the Create editor inspector', or 'add Library duplicate flow'."
# tools: ['vscode', 'execute', 'read', 'agent', 'edit', 'search', 'web', 'todo']
---

# NoiseLabyrinthFlutter UI Agent Guide

## Mission

Build and refine the Flutter UX/UI for NoiseLabyrinth as a fast, calm, audio-focused tool for creating, validating, previewing, storing, and exporting generation configs.

Current product focus is editor-first:

- Open or create a config.
- Edit config structure and parameters deeply.
- Validate and preview changes quickly.
- Save to local library and export render output.

Favor progressive disclosure: simple summary surfaces first, advanced controls when the user drills into editor nodes.

## Project Status Snapshot

The UI is no longer a starter shell. Current implemented baseline in `noiselabyrinth_gui` includes:

- Main shell with three bottom sections: Quick start, Presets/Library, Create/Advanced.
- First-run welcome panel with persisted dismissal.
- Advanced config editor with structure tree, node inspectors, toolbar, and validation panel.
- Live preview playback pipeline with per-node preview inclusion toggles.
- MP3 export from current config.
- Local persistence for stored generation configs (Sembast) and lightweight app prefs (shared preferences).

Do not assume a 5-tab architecture (Home/Library/Create/Player/Settings) unless explicitly requested.

## Product Principles

- Keep mental load low and workflows fast.
- Keep browsing and editing clearly separated while preserving fast transitions.
- Make preview and export obvious from global chrome.
- Default to simple, usable output with complexity on demand.
- Prefer real, wired controls over static placeholders.
- Keep DSP, validation, serialization, and graph logic in `noiselabyrinth_core`; UI consumes core models/APIs.

## Navigation Model

Use the existing shell model in `MainShell`:

- Header: app identity, current section label, preview play/stop, export.
- Bottom navigation:
  - Quick start
  - Presets / Library
  - Create / Advanced
- End drawer for app options (currently preview settings and welcome reset).

Persist shell behavior with existing app state:

- Selected footer index and welcome dismissal via shared preferences-backed state.

## Screen Responsibilities

### Welcome / First Run

- Show a lightweight welcome card until user enters any main panel.
- Keep copy actionable and short.
- Provide a clear single action to continue.

### Quick Start Panel

- Treat as a guided launchpad for common workflows.
- Prioritize direct actions:
  - New config
  - Open library
  - Import JSON
- Avoid leaving this panel as static placeholder content in production-facing iterations.

### Presets / Library Panel

- Use repository-backed stored configs.
- Preserve and improve current management affordances:
  - Refresh
  - Tag filtering
  - Load into Create panel
  - Delete with explicit confirmation affordance
- Keep metadata visibility high: name, description, version, tags, updated timestamp.

### Create / Advanced Panel

This is the primary work surface.

- Empty state must support:
  - New config
  - Import JSON
- Open state keeps split editor layout:
  - Structure tree (left)
  - Inspector panel (right)
  - Validation panel (bottom)
  - Editor toolbar (top)

## Advanced Editor Requirements

Model editing around existing editor nodes and Riverpod notifiers.

### Structure Tree

- Root nodes:
  - Metadata
  - Render
  - Mix
- Per-layer subtree:
  - Layer
  - Source
  - Processors (+ add/remove)
  - Modulations (+ add/remove)
  - Events (+ add/remove)
- Keep per-item preview toggles for processors, modulations, and events.

### Inspector Coverage

Keep inspector factory aligned with selected node types.

- Source types:
  - noise
  - impulse
  - sine
- Processor types:
  - biquad
  - gain
  - saturator
  - delay
- Modulation types:
  - lfo
  - random
  - drift
  - envelope
  - burst
- Event editing:
  - trigger type + rate
  - action list mapping to modulation IDs and action mode

### Burst Modulation UX

Current Burst controls are functional and must remain first-class:

- duration
- intensity
- randomness
- attack
- release
- cluster min/max
- cluster spread

If visual previews are added, keep them additive and do not replace functional controls.

### Validation UX

- Keep always-visible validation summary in toolbar and panel.
- Validation list rows should continue to navigate to related nodes when available.
- Keep panel collapsible and compact.

### Toolbar UX

Keep toolbar actions focused and high-frequency:

- New config
- Import JSON
- Save to library

Keep dirty-state and active-config identity clear.

## Preview And Export Requirements

Header-level preview/export remains canonical until a dedicated player workflow is explicitly introduced.

Preview behavior:

- Start/stop from header control.
- Rebuild/restart preview when editor revision changes while active.
- Respect per-node preview toggles (processors/modulations/events).
- Keep preview settings configurable from drawer panel.

Export behavior:

- Use shared MP3 rendering pipeline and policy flow.
- Keep platform differences encapsulated in export destination adapters.

## State And Persistence

Use Riverpod as default state architecture.

- Editor state owns:
  - open config
  - selection
  - dirty flag
  - validation issues
  - preview-disabled maps
  - config revision
- Library state owns:
  - presets list
  - tags
  - selected tag
- App persisted state owns:
  - selected footer
  - welcome dismissal
- Preview state owns:
  - preparing/playing/error status
  - bound revision

Persistence:

- Stored configs: Sembast repository abstraction.
- App prefs: shared preferences.

## UI Design Direction

- Maintain strong dark-mode quality, while supporting both light and dark themes.
- Continue card-based surfaces and dense, readable control groups.
- Prefer the existing reusable inspector input primitives:
  - labeled slider
  - labeled dropdown
  - labeled switch
  - labeled text field
- Keep destructive actions secondary and confirm when persistence is affected.

## Package Structure Guidance

Follow current `lib/` boundaries:

- `widgets/`: visual components and editor UI
- `state/`: Riverpod state and controllers
- `persistence/`: storage adapters and repositories

Avoid large mixed-responsibility files; split by feature/inspector concern.

Keep UI logic in GUI package and audio/render/model logic in core/shared packages.

## Near-Term Roadmap Targets

Forward-looking tasks should extend current architecture, not replace it.

1. Upgrade Quick start from placeholder to actionable launchpad.
2. Add richer library search/sort/filter while preserving performance.
3. Add duplicate and rename flows for stored configs.
4. Improve tree ergonomics (including optional drag-reorder UI backed by existing reorder methods).
5. Add targeted visual previews (modulation/event timing, processor response) where they improve comprehension.
6. Expand drawer settings coherently without breaking current preview settings flow.

## Testing And Quality Bar

Before considering UI work complete:

- The screen/flow is reachable from current shell navigation.
- Interactions are wired to notifier/state, not dead-end local state.
- Validation and preview behavior remain correct.
- Existing tests are updated when behavior changes.
- New critical behavior includes tests, especially for:
  - navigation and entry flow
  - preview toggle semantics
  - editor state transitions

Run and report:

- `dart format`
- `flutter analyze`
- relevant `flutter test`

## Explicitly Outdated Guidance

The following should not be treated as baseline requirements unless reintroduced intentionally:

- Mandatory 5-tab top-level app with dedicated Player and Settings pages.
- Wizard-first creation flow as core UX requirement.
- "GUI is just starter app" assumption.
