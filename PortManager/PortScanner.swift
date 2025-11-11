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

        // Use lsof to get all listening ports
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-iTCP", "-sTCP:LISTEN", "-n", "-P"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                portList = parseOutput(output)
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Error scanning ports: \(error.localizedDescription)"
            }
        }

        // Also get UDP ports
        let udpTask = Process()
        udpTask.launchPath = "/usr/sbin/lsof"
        udpTask.arguments = ["-iUDP", "-n", "-P"]

        let udpPipe = Pipe()
        udpTask.standardOutput = udpPipe
        udpTask.standardError = Pipe()

        do {
            try udpTask.run()
            udpTask.waitUntilExit()

            let data = udpPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                portList.append(contentsOf: parseOutput(output, isUDP: true))
            }
        } catch {
            // UDP scan is optional, don't show error
        }

        return portList.sorted { $0.port < $1.port }
    }

    private func parseOutput(_ output: String, isUDP: Bool = false) -> [PortInfo] {
        var ports: [PortInfo] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }

            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 9 else { continue }

            let processName = String(components[0])
            guard let pid = Int(components[1]) else { continue }

            let addressInfo = String(components[8])
            let parts = addressInfo.components(separatedBy: ":")

            guard let portString = parts.last,
                  let port = Int(portString.replacingOccurrences(of: "*", with: "")) else {
                continue
            }

            let address = parts.dropLast().joined(separator: ":")
            let state = isUDP ? "UDP" : (components.count >= 10 ? String(components[9]) : "LISTEN")
            let protocol = isUDP ? "UDP" : "TCP"

            let portInfo = PortInfo(
                port: port,
                protocol: protocol,
                state: state,
                processName: processName,
                pid: pid,
                address: address.isEmpty ? "*" : address
            )

            ports.append(portInfo)
        }

        return ports
    }

    func killProcess(pid: Int) {
        let task = Process()
        task.launchPath = "/bin/kill"
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
