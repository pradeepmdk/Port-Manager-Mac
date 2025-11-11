import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = PortScanner()
    @State private var searchText = ""
    @State private var selectedPort: PortInfo?
    @State private var showKillConfirmation = false

    var filteredPorts: [PortInfo] {
        if searchText.isEmpty {
            return scanner.ports
        }
        return scanner.ports.filter {
            "\($0.port)".contains(searchText) ||
            $0.processName.localizedCaseInsensitiveContains(searchText) ||
            "\($0.pid)".contains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Port Manager")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                if scanner.isScanning {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 8)
                }

                Button(action: {
                    scanner.scanPorts()
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search ports, process name, or PID...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding()

            // Port count
            HStack {
                Text("\(filteredPorts.count) port(s) in use")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Port list
            if scanner.errorMessage != nil {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text(scanner.errorMessage ?? "Unknown error")
                        .foregroundColor(.secondary)
                    Button("Try Again") {
                        scanner.scanPorts()
                    }
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if scanner.ports.isEmpty && !scanner.isScanning {
                VStack(spacing: 16) {
                    Image(systemName: "network")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No ports found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Button("Scan Ports") {
                        scanner.scanPorts()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(filteredPorts, selection: $selectedPort) {
                    TableColumn("Port") { port in
                        Text(port.displayPort)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    .width(min: 80, max: 100)

                    TableColumn("Protocol") { port in
                        Text(port.protocol)
                    }
                    .width(min: 80, max: 100)

                    TableColumn("State") { port in
                        Text(port.state)
                            .foregroundColor(port.state == "LISTEN" ? .green : .orange)
                    }
                    .width(min: 100, max: 120)

                    TableColumn("Address") { port in
                        Text(port.address)
                            .foregroundColor(.secondary)
                    }
                    .width(min: 120)

                    TableColumn("Process") { port in
                        Text(port.processName)
                            .fontWeight(.medium)
                    }
                    .width(min: 150)

                    TableColumn("PID") { port in
                        Text("\(port.pid)")
                            .foregroundColor(.secondary)
                    }
                    .width(min: 80, max: 100)

                    TableColumn("Actions") { port in
                        Button(action: {
                            selectedPort = port
                            showKillConfirmation = true
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Kill process")
                    }
                    .width(min: 60, max: 80)
                }
                .alternatingRowBackgrounds()
            }
        }
        .frame(minWidth: 900, minHeight: 500)
        .onAppear {
            scanner.scanPorts()
        }
        .alert("Kill Process?", isPresented: $showKillConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Kill", role: .destructive) {
                if let port = selectedPort {
                    scanner.killProcess(pid: port.pid)
                }
            }
        } message: {
            if let port = selectedPort {
                Text("Are you sure you want to kill \(port.processName) (PID: \(port.pid)) on port \(port.port)?")
            }
        }
    }
}

#Preview {
    ContentView()
}
