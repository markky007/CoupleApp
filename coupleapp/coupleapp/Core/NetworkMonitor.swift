import Combine
import Foundation
import Network

/// Monitors network connectivity status
/// Provides real-time updates on connection availability
@MainActor
class NetworkMonitor: ObservableObject {

    // MARK: - Singleton

    static let shared = NetworkMonitor()

    // MARK: - Published Properties

    /// Current network connection status
    @Published private(set) var isConnected = true

    /// Type of connection (wifi, cellular, etc.)
    @Published private(set) var connectionType: ConnectionType = .unknown

    /// Whether the connection is expensive (cellular data)
    @Published private(set) var isExpensive = false

    // MARK: - Private Properties

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    // MARK: - Types

    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case unknown
    }

    // MARK: - Initialization

    private init() {
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Monitoring

    /// Starts monitoring network connectivity
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.updateConnectionStatus(path: path)
            }
        }
        monitor.start(queue: queue)
        print("🌐 Network monitoring started")
    }

    /// Stops monitoring network connectivity
    private func stopMonitoring() {
        monitor.cancel()
        print("🌐 Network monitoring stopped")
    }

    /// Updates connection status based on network path
    private func updateConnectionStatus(path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive

        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wired
        } else {
            connectionType = .unknown
        }

        print("🌐 Network status: \(isConnected ? "Connected" : "Disconnected") (\(connectionType))")
    }

    // MARK: - Public Methods

    /// Returns a user-friendly connection status message
    var statusMessage: String {
        if isConnected {
            switch connectionType {
            case .wifi:
                return "Connected via Wi-Fi"
            case .cellular:
                return "Connected via Cellular"
            case .wired:
                return "Connected"
            case .unknown:
                return "Connected"
            }
        } else {
            return "No Internet Connection"
        }
    }

    /// Whether the app should operate in offline mode
    var isOfflineMode: Bool {
        !isConnected
    }
}
