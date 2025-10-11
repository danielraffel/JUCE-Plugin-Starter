import SwiftUI

@main
struct DiagnosticApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            if let config = AppConfig.load() {
                MainView(config: config)
            } else {
                ErrorView()
            }
        }
        .windowResizability(.contentSize)
        .commands {
            // Remove some default menu items
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .undoRedo) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (optional - makes it feel more like a utility)
        // NSApp.setActivationPolicy(.accessory)
    }
}

struct ErrorView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Configuration Error")
                .font(.headline)

            Text("Could not load .env configuration file.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("Please ensure the app was built correctly with a valid .env file.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}
