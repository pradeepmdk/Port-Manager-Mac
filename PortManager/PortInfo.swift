import Foundation

struct PortInfo: Identifiable, Hashable {
    let id = UUID()
    let port: Int
    let protocol: String
    let state: String
    let processName: String
    let pid: Int
    let address: String

    var displayPort: String {
        "\(port)"
    }

    var displayProcess: String {
        "\(processName) (PID: \(pid))"
    }
}
