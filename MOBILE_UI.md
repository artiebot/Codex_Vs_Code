# SkyFeeder Mobile UI Documentation

## Overview
The SkyFeeder mobile app features a 3-tab layout designed for monitoring and managing the SkyFeeder device.

### Architecture
The app follows an MVVM (Model-View-ViewModel) architecture using SwiftUI.

- **Models**: Data structures representing domain objects (e.g., `BirdVisit`, `DeviceStatus`).
- **ViewModels**: Manage state and business logic, interacting with services (e.g., `DashboardViewModel`).
- **Views**: SwiftUI views that observe ViewModels and render the UI.
- **Services**: Protocol-based data access layer (e.g., `VisitServiceProtocol`).

### Tabs

#### 1. Dashboard
The main landing page showing:
- **Top Status Bar**: Device selection and status (Battery, WiFi, Temp).
- **Video Gallery**: Hero card featuring the latest video visit.
- **Visits This Week**: A 7-day line chart of visit activity.
- **Recent Activity**: A scrollable list of recent bird visits with details.

#### 2. Developer
Tools for debugging and diagnostics:
- **Power Diagnostics**: Battery voltage, current, and remaining time.
- **Network Diagnostics**: SSID, RSSI, ping time, and connection status.
- **System Logs**: View recent device logs.
- **Actions**: Trigger telemetry, snapshots, reboots, etc.

#### 3. Settings
User configuration:
- **Device**: Select default device.
- **Detection**: Adjust sensitivity and quiet hours.
- **Appearance**: Toggle theme (Light/Dark/System).
- **About**: Version information.

## Data Flow
1. **Services** fetch data (currently mocks, ready for API integration).
2. **ViewModels** call services and publish data to `@Published` properties.
3. **Views** observe ViewModels and update automatically.

## Extending the UI
To add a new metric to the Dashboard:
1. Update `DeviceStatus` or `DailyVisitStats` model.
2. Update `DeviceService` or `StatsService` to fetch the new data.
3. Expose the data in `DashboardViewModel`.
4. Add a new UI component in `DashboardView` to display it.

## Testing
- **Unit Tests**: Located in `SkyFeederUITests`, verify ViewModel logic.
- **UI Tests**: Verify navigation and element presence.
