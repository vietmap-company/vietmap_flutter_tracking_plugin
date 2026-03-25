# City Run GPS Simulator - iOS Simulator Setup

This guide explains how to use the City Run GPX simulation feature in the example app.

## Overview

The **City Run Test** feature allows you to simulate GPS movement in the iOS Simulator without needing a real device. It loads the `city_run_hcmc.gpx` file and automatically emits location updates at realistic intervals.

## Features

- **46 Waypoints**: City run route through HCMC (Nhà thờ Đức Bà → Lê Duẩn → Nam Kỳ Khởi Nghĩa → Dinh Độc Lập → Lê Lợi → Nguyễn Huệ → Đồng Khởi)
- **Duration**: ~4 minutes 15 seconds
- **Distance**: ~4 km  
- **Speed**: ~10 km/h running pace
- **Interval**: 5-second waypoint intervals

## How to Use

### Step 1: Load GPX File
1. Run the example app in iOS Simulator
2. Scroll down to the "🏃 City Run Test (iOS Simulator)" card
3. Tap **📥 Load GPX** button
4. You should see "✅ Loaded (46 waypoints)" when successful

### Step 2: Start Simulation
1. Tap **Start** button
2. Status badge will change to "▶️ Running"
3. Location updates will begin emitting from the GPX waypoints

### Step 3: Monitor Tracking
1. Locations appear in real-time in the "📝 Location History" section
2. Watch the distance and speed metrics update as you "run"
3. Each waypoint is emitted with realistic timing (5-second intervals)

### Step 4: Stop Simulation
1. Tap **Stop** button at any time
2. Status badge changes to "⏸️ Stopped"
3. Location updates cease

## Technical Details

### GPX Parser (`gpx_simulator.dart`)
- **parseGPX()**: Parses XML to extract waypoints with coordinates and timestamps
- **LocationSimulator**: Manages waypoint emission with configurable speed factor
- **Speed control**: Adjustable via `speed` parameter (default: 5.0)

### Example Code
```dart
// Load GPX
final gpxContent = await rootBundle.loadString('assets/city_run_hcmc.gpx');
final waypoints = GPXSimulator.parseGPX(gpxContent);

// Create simulator
_simulator = GPXSimulator(
  waypoints: waypoints,
  onLocation: (location) {
    // Handle location update
  },
);

// Start with speed factor (5.0 = 1x real-time)
_simulator.start(speed: 5.0);
```

## Simulator-Only Feature

⚠️ **Important**: This City Run feature is designed for **iOS Simulator testing only**. 

- Works with Xcode iOS Simulator (iPhone 15, etc.)
- Automatically moves location without device movement
- Perfect for testing tracking logic without real GPS hardware
- For real device testing, use actual GPS movement or Xcode's location simulation tools

## Route Details

The city run route (stored in `assets/city_run_hcmc.gpx`):

```
Starting Point: Nhà thờ Đức Bà (10.7877°N, 106.6956°E)
↓
Lê Duẩn Street (heading northeast)
↓
Nam Kỳ Khởi Nghĩa Street (heading southeast)  
↓
Dinh Độc Lập area
↓
Lê Lợi Boulevard (heading west)
↓
Nguyễn Huệ Walking Street
↓
Đồng Khởi area (endpoint)

Total: ~4 km, 46 waypoints, ~4m 15s duration
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Load GPX" button disabled | Make sure app has been initialized first |
| Locations not updating | Check that Start button was clicked (status should show "▶️ Running") |
| Slow updates | Verify iOS Simulator performance; increase `speed` factor if needed |
| GPX not found | Ensure `city_run_hcmc.gpx` is in `assets/` folder and registered in `pubspec.yaml` |

## Advanced Usage

### Adjust Speed
To make the simulation faster/slower, modify the `speed` parameter in `_startCityRun()`:

```dart
// 10.0 = 2x speed (faster)
// 2.5 = 0.5x speed (slower)
_simulator!.start(speed: 10.0);
```

### Custom Routes
To use your own GPX file:
1. Replace `assets/city_run_hcmc.gpx` with your GPX file
2. Or create a new button to load a different GPX asset
3. GPX format: Standard XML with `<trkpt>` elements containing `lat`, `lon`, `ele`, `time`

## Files Changed

- `example/lib/main.dart` - Added City Run UI and methods
- `example/lib/gpx_simulator.dart` - New GPX parsing and simulation utility
- `example/assets/city_run_hcmc.gpx` - City run route data (46 waypoints)
- `example/pubspec.yaml` - Asset registration

## See Also

- [SLC Background Tracking](SLC_SETUP_GUIDE.md) - Implementing Significant Location Changes for background GPS
- Location History - Real-time tracking data in the example app
