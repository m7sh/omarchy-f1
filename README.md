# 🏎️ Formula 1 Hub for Omarchy

[![Omarchy](https://img.shields.io/badge/Omarchy-Quickshell-blue.svg)](https://omarchy.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![F1 Data](https://img.shields.io/badge/Data-Jolpica%20Ergast%20API-red.svg)](https://api.jolpi.ca/)

A macOS-inspired Formula 1 status bar widget and popout dashboard for [Omarchy](https://omarchy.org/) Linux (Quickshell & Hyprland).

Live session countdowns, full race weekend schedules in your local timezone, driver & constructor championship standings, and desktop alerts directly on your top bar.

---

## 📸 Screenshots

### Top Bar Widget
![Status Bar Pill](assets/bar.png)

### Popout F1 Hub Dashboard
![F1 Hub Panel](assets/panel.png)

### 🎨 Fully Adaptive Theming
Built directly with Omarchy's design system tokens (`qs.Commons` `Color`, `Style` and `qs.Ui`). Adapts reactively whenever you switch themes (`Waffle Cat`, `Catppuccin`, `Tokyo Night`, etc.):
![Adaptive Theme](assets/theme_adaptive.png)

---

## ✨ Features

- ⏱️ **Real-Time Bar Countdown:**
  - Displays country code, session name, and relative countdown (e.g. `🏎️ ITA · Race in 7h 14m`).
  - Automatically turns into a pulsing `🔴 LIVE · Race` indicator during live track sessions.
- 📅 **Grand Prix Weekend Schedule:**
  - Chronological weekend timetable (FP1, FP2, FP3, Qualifying, Sprint, Race).
  - All times converted automatically to your local system timezone.
  - Real-time status tags (`Done`, `LIVE NOW`, countdown).
- 🏆 **Championship Standings:**
  - **Drivers:** Ranks, podium medals (🥇🥈🥉), official team accent colors, driver code, driver name, team, points, and race wins.
  - **Constructors:** Ranks, team livery stripes, team name, points, and race wins.
- 🔔 **Smart Desktop Notifications:**
  - Pre-race countdown reminders dispatched **15 minutes before session start**.
  - Instant **"Lights out!"** alert when a session goes live.
  - Smart deduplication ledger prevents duplicate spam.
  - Built-in notification test and instant race summary buttons.
- 🖱️ **Quick Mouse Interactions:**
  - **Left-Click:** Open / close the F1 Hub dashboard.
  - **Middle-Click:** Force an immediate background data refresh.
  - **Right-Click:** Dispatch an instant desktop notification summary for the upcoming session.

---

## 🚀 Installation

### Recommended: Using Omarchy CLI
Run this single command in your terminal:
```bash
omarchy plugin add https://github.com/m7sh/omarchy-f1.git --enable
```
*(Replace `m7sh` with your GitHub username if forked).*

### Manual Installation
```bash
git clone https://github.com/m7sh/omarchy-f1.git ~/.config/omarchy/plugins/mush.f1
omarchy-shell shell rescanPlugins
omarchy plugin enable mush.f1
```

---

## ⌨️ Hyprland Shortcut (Optional)

To toggle the F1 Hub with a keyboard shortcut (e.g. <kbd>SUPER</kbd> + <kbd>F1</kbd>), add the following line to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + F1", "F1 Hub", "omarchy-shell shell toggle mush.f1")
```

Then reload Hyprland:
```bash
hyprctl reload
```

---

## 📁 File Structure

```
~/.config/omarchy/plugins/mush.f1/
├── manifest.json       # Plugin manifest (mush.f1, kind: bar-widget)
├── BarWidget.qml       # Quickshell top bar status pill
├── Panel.qml           # Quickshell popup hub (Schedule, Standings, Alerts)
├── fetch_f1.py         # Python backend: Jolpica API client & notification daemon
├── assets/             # Screenshots and preview images
├── LICENSE             # MIT License
└── README.md           # Documentation

~/.cache/omarchy-f1/
├── data.json           # Cached weekend schedule, standings & countdown
└── notified.json       # Notification deduplication ledger

~/.config/omarchy/settings/
└── f1.json             # User preferences (notification toggle)
```

---

## 🌐 Data Sources & API

This plugin fetches Formula 1 data from the community-maintained, free [Jolpica Ergast API](https://api.jolpi.ca/):
- `https://api.jolpi.ca/ergast/f1/current/next.json` (Next Grand Prix schedule & sessions)
- `https://api.jolpi.ca/ergast/f1/current/driverStandings.json` (Driver Championship)
- `https://api.jolpi.ca/ergast/f1/current/constructorStandings.json` (Constructor Championship)

No API key or external credentials required. Data is cached locally in `~/.cache/omarchy-f1/data.json` to prevent unnecessary network requests.

---

## 📜 License

Distributed under the [MIT License](LICENSE).
