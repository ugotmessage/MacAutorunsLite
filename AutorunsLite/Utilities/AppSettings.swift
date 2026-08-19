import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("appearanceMode")
    var appearanceModeRawValue: String = AppearanceMode.system.rawValue {
        didSet { objectWillChange.send() }
    }

    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceModeRawValue) ?? .system }
        set {
            appearanceModeRawValue = newValue.rawValue
        }
    }

    var appearanceModeBinding: Binding<AppearanceMode> {
        Binding(
            get: { self.appearanceMode },
            set: { self.appearanceMode = $0 }
        )
    }
}
