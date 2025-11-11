import Foundation

class PortScanner: ObservableObject {
    @Published var ports: [PortInfo] = []
    @Published var isScanning = false
    @Published var errorMessage: String?

    func scanPorts() {
        isScanning = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = self?.executeCommand()

            DispatchQueue.main.async {
                self?.isScanning = false
                if let ports = result {
                    self?.ports = ports
                }
            }
        }
    }

    private func executeCommand() -> [PortInfo] {
        var portList: [PortInfo] = []

        // Use lsof to get all listening TCP ports
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-iTCP", "-sTCP:LISTEN", "-n", "-P", "-F", "pcn"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            if let errorOutput = String(data: errorData, encoding: .utf8), !errorOutput.isEmpty {
                print("TCP lsof stderr: \(errorOutput)")
            }

            if let output = String(data: outputData, encoding: .utf8) {
                print("TCP lsof output length: \(output.count)")
                print("First 500 chars: \(String(output.prefix(500)))")
                portList = parseFieldOutput(output, protocolType: "TCP")
                print("Parsed \(portList.count) TCP ports")
            }

            if task.terminationStatus != 0 {
                print("TCP lsof exited with status: \(task.terminationStatus)")
            }
        } catch {
            print("Error running TCP lsof: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Error scanning ports: \(error.localizedDescription)"
            }
        }

        // Also get UDP ports
        let udpTask = Process()
        udpTask.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        udpTask.arguments = ["-iUDP", "-n", "-P", "-F", "pcn"]

        let udpOutputPipe = Pipe()
        let udpErrorPipe = Pipe()
        udpTask.standardOutput = udpOutputPipe
        udpTask.standardError = udpErrorPipe

        do {
            try udpTask.run()
            udpTask.waitUntilExit()

            let outputData = udpOutputPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: outputData, encoding: .utf8) {
                print("UDP lsof output length: \(output.count)")
                portList.append(contentsOf: parseFieldOutput(output, protocolType: "UDP"))
                print("Total ports after UDP: \(portList.count)")
            }
        } catch {
            print("Error running UDP lsof: \(error)")
            // UDP scan is optional, don't show error
        }

        let sorted = portList.sorted { $0.port < $1.port }
        print("Returning \(sorted.count) total ports")
        return sorted
    }

    private func parseFieldOutput(_ output: String, protocolType: String) -> [PortInfo] {
        var ports: [PortInfo] = []
        let lines = output.components(separatedBy: .newlines)

        print("Parsing \(lines.count) lines for \(protocolType)")

        var currentPid: Int?
        var currentCommand: String?

        for line in lines {
            guard !line.isEmpty else { continue }

            let prefix = line.prefix(1)
            let value = String(line.dropFirst())

            switch prefix {
            case "p":
                // Process ID
                currentPid = Int(value)
                print("Found PID: \(value)")
            case "c":
                // Command name
                currentCommand = value
                print("Found command: \(value)")
            case "n":
                // Network address (address:port)
                print("Found network: \(value), pid=\(String(describing: currentPid)), cmd=\(String(describing: currentCommand))")
                guard let pid = currentPid,
                      let command = currentCommand else {
                    print("  Skipping - missing pid or command")
                    continue
                }

                // Parse the network address
                var addressString = value
                var portString = ""

                // Handle different formats: *:PORT, IP:PORT, [IPv6]:PORT
                if let lastColon = addressString.range(of: ":", options: .backwards) {
                    portString = String(addressString[lastColon.upperBound...])
                    addressString = String(addressString[..<lastColon.lowerBound])
                }

                // Extract port number
                guard let port = Int(portString) else {
                    print("  Failed to parse port from: \(portString)")
                    continue
                }

                print("  Successfully parsed port: \(port)")

                let state = protocolType == "TCP" ? "LISTEN" : "UDP"
                let address = addressString.isEmpty || addressString == "*" ? "*" : addressString

                let portInfo = PortInfo(
                    port: port,
                    protocolType: protocolType,
                    state: state,
                    processName: command,
                    pid: pid,
                    address: address
                )

                ports.append(portInfo)
            default:
                break
            }
        }

        print("Total ports parsed: \(ports.count)")

        return ports
    }

    func killProcess(pid: Int) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/kill")
        task.arguments = ["-9", "\(pid)"]

        do {
            try task.run()
            task.waitUntilExit()

            // Rescan after killing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.scanPorts()
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to kill process: \(error.localizedDescription)"
            }
        }
    }
}
