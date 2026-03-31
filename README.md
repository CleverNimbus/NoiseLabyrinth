# Focus Noise Generator

**An offline soundscape generator for focus, rest, masking, and regulation.**

[![License](https://img.shields.io/github/license/CleverNimbus/focus-noise-generator)](https://github.com/CleverNimbus/focus-noise-generator/blob/main/LICENSE)
[![dotnet](https://img.shields.io/badge/dotnet-%2010.0-blue?logo=.net)](https://dotnet.microsoft.com/)
[![Status](https://img.shields.io/badge/status-active-brightgreen)](https://github.com/CleverNimbus/focus-noise-generator)

Focus Noise Generator helps you create long-form audio files built for real situations: deep work, speech masking, decompression, sleep, and calmer background sound for everyday life.

Instead of relying on streaming loops or one-size-fits-all presets, the project lets you browse curated sound profiles, tailor them to your device, export them locally, and keep the results as reusable files.

<img src=".github/assets/demo.gif" alt="Focus Noise Generator demo" width="480" style="max-width:100%;height:auto" />

## What This Project Is

This repository is centered around a simple idea: background audio should be useful, repeatable, and personal.

The app gives you a console-based interface where you can:

- Browse bundled sound profile collections
- Read short descriptions before generating anything
- Adjust duration, bitrate, intensity, and target device
- Queue multiple profiles in one session
- Export offline audio files to your own library

It is designed for people who want practical sound tools, not endless tweaking.

## What It Is Good For

### Focus and sustained work

Profiles like **Fractal Focus Field**, **Remote Work ADHD Focus Deep**, and **Flow Stabilizer** aim for steady, non-intrusive backgrounds that stay useful over longer sessions.

### Environmental masking

Profiles like **Office Speech Mask**, **Urban Noise Shield**, and **Airplane Cabin Field** are built to soften the impact of chatter, travel noise, and busy shared spaces.

### Rest, decompression, and sleep

Profiles like **Deep Sleep Brown**, **Warm Natural Sleep Field**, **Stress Relief Night**, and **Decompression Nap Field** are geared toward gentler, slower, more enveloping listening.

### Specialized profile packs

The repository now includes multiple curated profile libraries, including:

- A `start_pack` with general-purpose everyday profiles
- A `sleep` collection focused on bedtime and overnight use
- An `ADHD` collection aimed at work, regulation, transitions, and recovery

At the moment, the repo ships with **33 bundled profiles** across these collections.

## Why People May Prefer This Over Typical Noise Apps

- **Offline by default**: once you generate a file, it is yours to keep and replay anywhere
- **Long-form output**: create audio for minutes or hours instead of relying on short loops
- **More intentional presets**: profiles are grouped by scenario, not just by color-noise label
- **Device-aware playback**: generation can be tuned for supported headphones or speakers
- **Batch-friendly workflow**: queue multiple profiles and build a small personal library in one pass

## Current Experience

The current app experience is more guided than the original version of this README suggested.

You start by choosing a profile collection, then select a sound profile, review its description, adjust a few practical settings, and add it to a generation queue. From there, you can export one file or a whole batch to your chosen destination folder.

That makes the project feel less like a raw audio tool and more like a small, local soundscape workshop.

## Listen to Sample Previews

These short previews come from the repository and give a quick sense of the project’s range:

- [Creative tonal sample](.github/assets/samples/CreativeTonalSpace_Fractal_Genericstandardadjustments_1min_196kbps.mp3)
- [Deep brown sample](.github/assets/samples/DeepSleepBrown_Brown_Genericstandardadjustments_1min_196kbps.mp3)
- [Airplane-style masking sample](.github/assets/samples/AirplaneCabinField_Brown_Genericstandardadjustments_1min_196kbps.mp3)
- [Living field / urban masking sample](.github/assets/samples/MultiBandLivingFieldVivid_MultiBand_Vivid_Genericstandardadjustments_1min_196kbps.mp3)

They are only short examples. The main point of the project is generating your own longer-form versions locally.

## Quick Start

If you want to try it quickly:

1. Install the .NET 10 SDK
2. Clone this repository
3. Run `dotnet run --project src/CnNoiseGen.UI.Console`
4. Pick a profile, adjust the basics, and generate your files

For setup details and implementation-oriented notes, see [docs/TECHNICAL.md](docs/TECHNICAL.md).

## Project Snapshot

- Console-based UI for browsing and exporting sound profiles
- 33 bundled profiles across `start_pack`, `sleep`, and `ADHD`
- 4 bundled device profiles for more tailored output
- Queue-based generation for multiple exports in one run
- Local profile validation tooling for contributors and profile authors

## Contributing

Contributions are welcome, especially if you want to:

- Add new sound profiles
- Improve device coverage
- Refine the user experience
- Help shape clearer docs and examples

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

## Technical Notes

This README is intentionally focused on the user-facing side of the project.

If you want the implementation details, project structure, and developer-oriented notes, head to [docs/TECHNICAL.md](docs/TECHNICAL.md).

## License

This project is open source under the [LICENSE](LICENSE).
