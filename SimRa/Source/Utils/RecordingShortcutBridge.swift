import Foundation

@objcMembers
public class RecordingShortcutBridge: NSObject {
    
    /// Triggert den Aufnahmestart (z. B. via DeepLink simra://recording/start)
    public static func startRecording() -> Bool {
        NotificationCenter.default.post(name: .startRecordingFromShortcut, object: nil)
        return true
    }
    
    /// Triggert den Aufnahmestopp (z. B. via DeepLink simra://recording/stop)
    public static func stopRecording() -> Bool {
        NotificationCenter.default.post(name: .stopRecordingFromShortcut, object: nil)
        return true
    }
}

public extension Notification.Name {
    static let startRecordingFromShortcut = Notification.Name("startRecordingFromShortcutNotification")
    static let stopRecordingFromShortcut = Notification.Name("stopRecordingFromShortcutNotification")
}