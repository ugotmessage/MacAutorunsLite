import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        applyAppIcon()
        NSApp.activate(ignoringOtherApps: true)
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
                .environment(\.locale, settings.resolvedLocale)
                .frame(minWidth: 880, minHeight: 520)
        }
        .defaultSize(width: 1180, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Window(L10n.text("research.window_title"), id: "service-research") {
            ServiceResearchRootView()
                .environmentObject(settings)
                .environmentObject(researchSession)
                .preferredColorScheme(settings.appearanceMode.preferredColorScheme)
                .environment(\.locale, settings.resolvedLocale)
        }
        .defaultSize(width: 1000, height: 700)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environment(\.locale, settings.resolvedLocale)
        }
        .defaultSize(width: 560, height: 520)
        .windowResizability(.contentMinSize)
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
                    L10n.text("research.empty_title"),
                    systemImage: "magnifyingglass",
                    description: Text(L10n.text("research.empty_description"))
                )
            }
        }
        .frame(minWidth: 800, minHeight: 550)
        .textSelection(.enabled)
    }
}
