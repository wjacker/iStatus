## Language / 语言

[English](README.md) | [简体中文](README.zh-CN.md)

# iStatus

iStatus is a native macOS menu bar system monitor built with SwiftUI and AppKit. It is designed for people who want fast, glanceable system telemetry in the menu bar, plus a richer dashboard for deeper inspection when needed.

## Overview

iStatus continuously samples key macOS system metrics and surfaces them in three layers:

- Compact menu bar items for always-on monitoring
- Focused popover cards for each metric
- A full dashboard window with historical charts and detailed breakdowns

The current app covers:

- CPU usage
- Memory usage and memory composition
- Disk usage, purgeable space, and disk throughput
- Network throughput, IP information, and top network-active processes
- Battery level, health, power, and significant energy usage

## Why iStatus

- Native macOS experience with SwiftUI and AppKit
- Fast 2-second rolling sampling loop
- Historical data persisted across launches
- Designed for quick scanning, not just raw numbers
- Menu bar first, dashboard when you need more detail

## Features

### Menu Bar Monitoring

- Enable or disable individual metric items
- Keep key system stats visible at a glance
- Compact menu bar strip with configurable metric order and visibility
- Open focused popovers directly from the menu bar
- Dedicated menu bar settings window for previewing and reordering visible items

### Dashboard

- Overview screen with a waterfall-style summary layout
- Dedicated sections for CPU, Memory, Disk, Network, CPU Temp, and Battery
- Dedicated sections for CPU, Memory, Disk, Network, and Battery
- Time-range switching for historical inspection
- Collapsible sidebar for faster navigation
- Small, dense charts optimized for dark UI
- Empty states and no-data states that stay visually consistent
- Compact layout behavior for narrower window sizes

### Process-Level Insights

- Top network-active processes
- Top disk-active processes
- Top memory-heavy processes
- Significant energy usage in the battery section

### Battery Details

- Charge percentage
- Battery health
- Power adapter state
- Voltage, amperage, temperature, and cycle count when available

### Detail Popovers

- Unified popover header and visual language across CPU, Memory, Disk, Network, Temperature, and Battery
- Unified popover header and visual language across CPU, Memory, Disk, Network, and Battery
- Compact metric layouts optimized for menu bar usage
- Shared ring, chart, and process-list styling between dashboard and popovers
- Per-metric popup widths tuned for menu bar readability

## Screenshots

The current screenshots should be refreshed to match the latest UI.

### Menu Bar

Compact always-on metrics in the macOS menu bar, including the updated larger status-strip typography.

![Menu Bar](docs/screenshots/menu-bar.png)

### Metric Popover

Use one refreshed popover screenshot that shows the current single-layer popup style, updated header controls, and process list layout.

![Network Popover](docs/screenshots/network-popover.png)

### Dashboard Overview

The main dashboard combines historical charts with dense system summaries and the updated overview waterfall layout.

![Dashboard Overview](docs/screenshots/dashboard-overview.png)

### Memory Or Disk Detail

Use one refreshed detail screenshot that highlights the latest ring + breakdown presentation.

![Battery Panel](docs/screenshots/battery-panel.png)

Recommended screenshot updates:

- `docs/screenshots/menu-bar.png`
  Refresh with the current menu bar strip typography and spacing.
- `docs/screenshots/network-popover.png`
  Replace with any one current popover that shows the unified popup header and single-layer card structure.
- `docs/screenshots/dashboard-overview.png`
  Refresh with the current overview waterfall layout and updated sidebar/header styling.
- `docs/screenshots/battery-panel.png`
  Replace with either the latest battery detail panel or a new memory/disk detail screenshot, depending on which panel you want to feature.

Additional screenshots worth adding:

- `docs/screenshots/menu-bar-settings.png`
  Show the dedicated menu bar settings window with the live strip preview and visibility toggles.
- `docs/screenshots/memory-popover.png`
  Capture the compact dual-ring memory popup with the updated breakdown panel.
- `docs/screenshots/disk-popover.png`
  Capture the disk popup with the single-ring layout and Memory-style capacity breakdown.
- `docs/screenshots/cpu-temp-popover.png`
  Optional, but useful if you want to highlight temperature, thermal, and fan telemetry.

## App Behavior

- The app launches as a menu bar app via `LSUIElement`
- Opening Dashboard or Menu Bar Settings temporarily shows the app in the Dock
- Closing those windows returns the app to menu bar mode

## Tech Stack

- Swift
- SwiftUI
- AppKit
- Xcode project-based macOS app
- No third-party dependencies

## Requirements

- macOS 14.0+
- Xcode 15+ recommended

## Getting Started

1. Open `iStatus.xcodeproj` in Xcode.
2. Select the `iStatus` target.
3. Build and run the app on macOS.

If icons or assets do not refresh immediately:

1. Quit the running app.
2. Use `Product > Clean Build Folder`.
3. Run the app again.

## Project Structure

- `iStatus/iStatusApp.swift`
  App entry point, status bar setup, window presentation, and Dock visibility behavior.

- `iStatus/StatusBarController.swift`
  AppKit bridge that hosts the menu bar home panel and coordinates menu presentation.

- `iStatus/DashboardView.swift`
  Main dashboard UI, overview waterfall layout, detail popovers, process tables, metric cards, and shared formatting helpers.

- `iStatus/MenuBarView.swift`
  Menu bar home, menu bar settings UI, item definitions, and compact status strip rendering.

- `iStatus/MiniChartView.swift`
  Reusable compact chart primitives.

- `iStatus/MemoryStackChartView.swift`
  Specialized stacked memory visualization.

- `iStatus/RingGaugeView.swift`
  Ring-based gauge components used across summary views.

- `iStatus/Metrics/MetricsStore.swift`
  Central sampling loop, published metric state, persistence, and worker coordination.

- `iStatus/Metrics/MetricModels.swift`
  Shared data models for metrics, process stats, and battery details.

- `iStatus/Metrics/RingBuffer.swift`
  In-memory history storage for time-series samples.

- `iStatus/Metrics/Samplers/`
  System samplers for CPU, memory, disk, network, and battery.

- `iStatus/Helper/`
  Privileged helper setup used for telemetry that needs elevated access on supported machines.

- `iStatus/Shared/`
  Shared helper communication models and XPC contracts.

- `iStatus/iStatusHelper/`
  Helper executable used for privileged sampling work.

- `iStatus/Resources/Assets.xcassets`
  App icon, in-app icon assets, and shared color assets.

- `docs/branding/`
  Logo concepts and icon source files used during design iteration.

## Sampling Model

`MetricsStore` drives a repeating background sampling loop.

- Default sample interval: 2 seconds
- Historical samples are retained in ring buffers
- Recent history is persisted across launches
- Views subscribe to published state and update live

## Notes On Data Availability

- Battery-specific details only appear on machines that expose that data
- Some elevated telemetry paths rely on the bundled helper and may differ by Mac model or permissions state
- Process tables intentionally show top items rather than exhaustive system process dumps
- Disk purgeable / available capacity values follow macOS volume resource APIs and may vary by filesystem layout

## Design Direction

The current product direction emphasizes:

- Dark, low-distraction surfaces
- Dense but readable system information
- Color accents that map to metric categories
- A menu bar first experience with an optional full dashboard

## Roadmap

Potential next steps:

- Custom alert thresholds
- Configurable sampling intervals
- Search and filtering for process tables
- Snapshot export
- Additional dashboard customization
- CPU temperature, thermal pressure, and fan telemetry once reliable collection is available

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
