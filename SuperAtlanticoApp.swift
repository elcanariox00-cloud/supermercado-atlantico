import SwiftUI
import UserNotifications

@main
struct SuperAtlanticoApp: App {
    @StateObject private var store = Store()
    init() { UNUserNotificationCenter.current().delegate = Notifier.shared }
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store) }
    }
}
