# Port Manager

A native macOS application built with Swift and SwiftUI to manage and monitor all running ports on your system.

## Features

- **View All Running Ports**: Displays all TCP and UDP ports currently in use
- **Process Information**: Shows process name, PID, protocol, state, and address for each port
- **Search & Filter**: Quickly search ports by port number, process name, or PID
- **Kill Processes**: Terminate processes directly from the app
- **Auto-refresh**: Automatically scan ports on launch with manual refresh option
- **Native macOS UI**: Built with SwiftUI for a true native macOS experience

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later (for building)

## Installation

### Option 1: Build from Source

1. Open the project in Xcode:
   ```bash
   open PortManager.xcodeproj
   ```

2. Select your development team in the project settings (Signing & Capabilities)

3. Build and run the app (⌘+R)

### Option 2: Build from Command Line

```bash
xcodebuild -project PortManager.xcodeproj -scheme PortManager -configuration Release build
```

The built app will be in `build/Release/PortManager.app`

## Usage

1. Launch the app - it will automatically scan for all running ports
2. Use the search bar to filter by port number, process name, or PID
3. Click the refresh button to rescan ports
4. Click the red X icon next to any port to kill that process (requires confirmation)

## How It Works

The app uses the `lsof` command to scan for:
- TCP ports in LISTEN state
- UDP ports

For each port, it extracts:
- Port number
- Protocol (TCP/UDP)
- State (LISTEN, UDP, etc.)
- Process name
- Process ID (PID)
- Bound address

## Permissions

The app requires permission to:
- Execute system commands (`lsof`, `kill`)
- Read process information

Note: Some processes may require elevated privileges to terminate. If you need to kill system processes, you may need to run the app with appropriate permissions.

## Screenshots

The app displays:
- Port number (blue, bold)
- Protocol (TCP/UDP)
- State (green for LISTEN, orange for others)
- Address (IP or *)
- Process name (bold)
- PID (gray)
- Kill button (red X icon)

## Troubleshooting

**"No ports found"**: Click the "Scan Ports" button to refresh

**"Error scanning ports"**: Make sure the app has permission to execute system commands

**Can't kill a process**: Some system processes require administrator privileges

## License

This is a demonstration project for learning purposes.

## Contributing

Feel free to submit issues and enhancement requests!
