import SwiftUI
import AppKit

struct FilterBar: View {
    @Binding var selectedFilter: StartupFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StartupFilter.toolbarFilters) { filter in
                    FilterChip(
                        title: filter.title,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    isSelected
                        ? Color.accentColor.opacity(0.18)
                        : Color(nsColor: .controlBackgroundColor)
                )
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .textSelection(.disabled)
    }
}
