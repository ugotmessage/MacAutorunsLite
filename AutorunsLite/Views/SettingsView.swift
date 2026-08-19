import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section("外觀") {
                Picker("外觀模式", selection: settings.appearanceModeBinding) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420, alignment: .leading)
        .preferredColorScheme(settings.appearanceMode.preferredColorScheme)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}
