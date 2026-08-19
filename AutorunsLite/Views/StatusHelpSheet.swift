import SwiftUI

struct StatusHelpSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.text("status_help.title"))
                    .font(.title2.weight(.semibold))

                Text(L10n.text("status_help.intro"))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("status_help.flow.plist"))
                    Image(systemName: "arrow.down")
                        .foregroundStyle(.secondary)
                    Text(L10n.text("status_help.flow.load"))
                    Image(systemName: "arrow.down")
                        .foregroundStyle(.secondary)
                    Text(L10n.text("status_help.flow.wait"))
                    Image(systemName: "arrow.down")
                        .foregroundStyle(.secondary)
                    Text(L10n.text("status_help.flow.run"))
                }
                .font(.callout)

                Group {
                    Text(L10n.text("status_help.note.loaded"))
                    Text(L10n.text("status_help.note.unloaded"))
                    Text(L10n.text("status_help.note.recommendation"))
                }
                .font(.callout)

                Divider()

                Text(L10n.text("status_help.what_is_launch_agent"))
                    .font(.headline)
                Text(L10n.text("status_help.what_is_launch_agent_body"))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(L10n.text("status_help.what_is_launch_daemon"))
                    .font(.headline)
                Text(L10n.text("status_help.what_is_launch_daemon_body"))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(L10n.text("status_help.modern_sources_title"))
                    .font(.headline)
                Text(L10n.text("status_help.modern_sources_body"))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Divider()

                ForEach(statusCases, id: \.displayName) { status in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(status.displayName)
                            .font(.headline)
                        Text(status.shortDescription)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .frame(minWidth: 460, minHeight: 520)
    }

    private var statusCases: [LoadStatus] {
        [.loaded, .unloaded, .disabled, .orphaned, .error(""), .unknown]
    }
}
