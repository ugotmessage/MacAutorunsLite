import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        applyAppIcon()
    }

    private func applyAppIcon() {
        let icon = NSImage(named: "BrandMark")
            ?? NSImage(named: "AppIcon")
            ?? Bundle.main.url(forResource: "AppIcon", withExtension: "icns").flatMap { NSImage(contentsOf: $0) }
        guard let icon else { return }
        icon.isTemplate = false
        NSApp.applicationIconImage = icon
    }
}

@main
struct AutorunsLiteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings()
    @StateObject private var researchSession = ServiceResearchSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(researchSession)
                .preferredColorScheme(settings.appearanceMode.preferredColorScheme)
        }
        .defaultSize(width: 1180, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Window("服務研究", id: "service-research") {
            ServiceResearchRootView()
                .environmentObject(settings)
                .environmentObject(researchSession)
                .preferredColorScheme(settings.appearanceMode.preferredColorScheme)
        }
        .defaultSize(width: 1000, height: 700)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }
}

struct ServiceResearchRootView: View {
    @EnvironmentObject private var session: ServiceResearchSession

    var body: some View {
        Group {
            if let item = session.item {
                ServiceResearchView(item: item)
                    .id(item.id)
            } else {
                ContentUnavailableView(
                    "請選擇一個啟動項目",
                    systemImage: "magnifyingglass",
                    description: Text("在主視窗選取項目後，點「查詢此服務」。")
                )
            }
        }
        .frame(minWidth: 800, minHeight: 550)
        .textSelection(.enabled)
    }
}
