import SwiftUI

struct StatusBadge: View {
    let status: LoadStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.systemImage)
                .imageScale(.small)
            Text(status.displayName)
        }
        .foregroundStyle(status.color)
        .help(status.shortDescription)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.accessibilityLabel)
        .textSelection(.disabled)
    }
}
