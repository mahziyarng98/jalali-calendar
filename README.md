# Jalali Calendar

An [Omarchy](https://omarchy.org/) shell plugin: the Jalali (Solar Hijri /
Shamsi) date in your bar, and a month calendar in the panel behind it. Month
and weekday names are romanized — `Ordibehesht`, not `اردیبهشت` — and the
numerals are Latin throughout.

```
                      13 Shahrivar          ← the bar

        ┌─────────────────────────────────┐
        │     Jome, 13 Shahrivar 1405     │
        │  ‹        Shahrivar 1405      › │
        │            [ Today ]            │
        │   Sh  Ye  Do  Se  Ch  Pa  Jo    │
        │   31   1   2   3   4   5   6    │
        │    7   8   9  10  11  12 (13)   │  ← today: a thin accent ring
        │   14  15  16  17  18  19  20    │
        │   21  22  23  24  25  26  27    │
        │   28  29  30  31   1   2   3    │
        │    4   5   6   7   8   9  10    │
        │ 13 Shahrivar 1405 = 4 Sep 2026  │
        └─────────────────────────────────┘
```

## Features

- **Bar label** — day number and Finglish month, e.g. `13 Shahrivar`. Rolls
  over at local midnight on its own.
- **Month grid** on the Iranian week, Shanbe (Saturday) first, always six rows
  so the panel never changes height as you step through months.
- **Official Iranian holidays** in red with a dot under the number, so they
  still read as holidays on a theme whose palette has no real red.
- **Gregorian equivalent** of whatever day you point at, on a steady line
  under the grid — `18 Shahrivar 1405 = 9 September 2026`.
- **Correct leap years.** Esfand is 30 days in a leap year and 29 otherwise,
  and stepping across a Nowruz boundary lands where it should.
- **Theme-aware.** Every colour comes from the active Omarchy theme, so the
  panel re-skins on `omarchy theme set` with nothing to configure.

## Requirements

- Omarchy 4 ("Quattro") or newer — the Quickshell-based `omarchy-shell`.

Nothing else. No network access, no external fonts, no dependencies.

## Install

```bash
omarchy plugin add https://github.com/<user>/omarchy-jalali-calendar.git --enable
```

Plugins land disabled by default so you can read the code first; `--enable`
skips that and puts the widget straight into the bar's centre section. Move it
with `omarchy bar move local.jalali-calendar --section right`.

To install from a local checkout instead:

```bash
omarchy plugin add ~/src/jalali-calendar --enable --yes
```

## Update

```bash
omarchy plugin update local.jalali-calendar   # fast-forwards, showing a diff first
omarchy plugin update                         # every git-managed plugin
```

## Remove

```bash
omarchy plugin remove local.jalali-calendar
```

`omarchy plugin disable local.jalali-calendar` takes it off the bar without
uninstalling it.

## Using it

| Where | Action | Result |
|---|---|---|
| Bar | left click | open/close the panel |
| Panel | `‹` `›` or scroll wheel | previous / next month |
| Panel | click a day | pin it to the line under the grid |
| Panel | hover a holiday | its name, in Finglish |
| Panel | `Today`, or click the header date | back to the current month |
| Panel | arrow keys / `hjkl` | move the day cursor, turning the page at month edges |
| Panel | `[` `]` | previous / next month |
| Panel | `{` `}` | previous / next year |
| Panel | `t` | back to today |
| Panel | `Esc` | close |

It also answers over IPC, which is what you would bind a hotkey to:

```bash
omarchy-shell jalali-calendar toggle
omarchy-shell jalali-calendar open
omarchy-shell jalali-calendar close
```

## Configuration

Settings are inline on the widget's entry in `~/.config/omarchy/shell.json`,
which hot-reloads on save:

```json
{ "id": "local.jalali-calendar", "showYear": true, "showWeekday": false }
```

| Key | Default | Effect |
|---|---|---|
| `showYear` | `false` | append the year — `13 Shahrivar 1405` |
| `showWeekday` | `false` | prefix the weekday — `Jome, 13 Shahrivar` |

## Holidays

The **solar** holidays — Nowruz, Sizdah Be-dar, Islamic Republic Day, the
13 Khordad pair, 22 Bahman, 29 Esfand — are fixed dates on this calendar and
ship complete in `holidays-fixed.js`. They never need maintenance.

The **lunar** ones — Eyd-e Fetr, Eyd-e Ghorban, Tasua, Ashura, Arbaeen,
Eyd-e Ghadir and the rest — follow the Hijri Qamari calendar. They move about
eleven days earlier each Jalali year and their exact dates depend on the
official crescent sighting, so they cannot be computed: they have to be
transcribed per year from an authoritative calendar.

**`holidays-lunar.json` ships empty on purpose.** A wrong Ashura is worse than
a visibly missing one, so rather than guessing, the panel says so: while a
year has no data it prints `Lunar holidays for 1405 not in holidays-lunar.json`
under the grid, so an empty Moharram reads as missing data rather than as a
month with nothing in it.

To fill it in, read the official dates off an Iranian calendar for that year —
the [Institute of Geophysics, University of Tehran](https://calendar.ut.ac.ir/)
sets the approved one — and add them:

```json
"years": {
  "1405": [
    { "month": 3, "day": 6,  "name": "Eyd-e Ghorban" },
    { "month": 3, "day": 14, "name": "Eyd-e Ghadir" }
  ]
}
```

The file is watched, so saving it updates the open panel — no restart. The
file's own header carries the full instructions and the checks worth running
against a transcription; `node test/jalali-date-test.js 1405 3 6` converts a
Jalali date to Gregorian so you can confirm one landed where you expect.

## Development

```bash
node test/jalali-date-test.js   # verifies the conversion against known dates
omarchy plugin validate .       # checks the manifest the way the shell does
```

The date math in `JalaliDate.js` is deliberately Qt-free so the same file runs
under node and inside QML. The tests round-trip every day of Jalali years
1300–1500 — 73,414 of them — and check the Nowruz anchors, the 33-year leap
cycle, and the weekday alignment against dates that can be verified
independently.

Editing a plugin's **entry point** (`BarWidget.qml`) hot-reloads on save.
Editing a file it loads behind a `Loader` — `Panel.qml` here — does not always
take, so apply those with:

```bash
omarchy restart shell
```

### Files

| File | What it is |
|---|---|
| `manifest.json` | plugin declaration and the bar-widget settings schema |
| `BarWidget.qml` | the bar label, and the host for the panel |
| `Panel.qml` | the calendar panel |
| `JalaliDate.js` | Gregorian ↔ Jalali conversion, name tables, grid builder |
| `holidays-fixed.js` | the ten fixed solar holidays |
| `holidays-lunar.json` | per-year lunar holidays — hand-maintained, see above |
| `test/jalali-date-test.js` | conversion checks, and a date-conversion CLI |

## How the dates are computed

Gregorian ↔ Julian Day Number uses Fliegel and Van Flandern's closed form.
The Jalali leap rule is Borkowski's: the year is astronomical rather than
cyclic, so its leap years are described by a table of breaks — years at which
the spacing changes — with leap years every 4 years inside a break interval
and an 8-per-33 correction. Both are implemented from their published
mathematical descriptions rather than ported from an existing library.
