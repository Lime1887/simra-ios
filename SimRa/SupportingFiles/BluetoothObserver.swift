import SwiftUI
import Combine

final class BluetoothObserver: ObservableObject {
    @Published var showDisconnectAlert = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: NSNotification.Name("disconnectNotif"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("Peripheral Disconnected")
                self?.showDisconnectAlert = true
            }
            .store(in: &cancellables)
    }
}