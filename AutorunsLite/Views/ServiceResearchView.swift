import SwiftUI
import AppKit

struct ServiceResearchView: View {
    @EnvironmentObject private var settings: AppSettings
    let item: StartupItem

    @StateObject private var browser = EmbeddedBrowserController()
    @State private var selectedQuery: ServiceResearchQueryType = .overview
    @State private var queryText = ""
    @State private var unknownVariables: [String] = []
    @State private var urlBuildFailed = false

    private let research = ServiceResearchService()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            queryButtons
            Divider()
            navigationBar
            Divider()
            searchField
            Divider()
            webArea
            Divider()
            Text(L10n.text("research.disclaimer"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(10)
        }
        .frame(minWidth: 800, minHeight: 550)
        .onAppear {
            apply(queryType: .overview)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text("research.window_title"))
                    .font(.title2.weight(.semibold))
                Text(item.displayName)
                    .font(.headline)
                Text(item.label)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                Text("\(item.type.researchTypeKeyword) · \(item.origin.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .textSelection(.enabled)
            Spacer()
            Button {
                openCurrentInSystemBrowser()
            } label: {
                Label(L10n.text("research.open_external"), systemImage: "arrow.up.right.square")
            }
            .textSelection(.disabled)
            .help(L10n.text("research.open_in_browser_current"))
        }
        .padding(12)
    }

    private var queryButtons: some View {
        HStack(spacing: 8) {
            ForEach(ServiceResearchQueryType.allCases) { type in
                Button(type.displayName) {
                    apply(queryType: type)
                }
                .buttonStyle(.bordered)
                .tint(selectedQuery == type ? Color.accentColor : Color.secondary)
                .foregroundStyle(selectedQuery == type ? Color.accentColor : Color.primary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var navigationBar: some View {
        HStack(spacing: 12) {
            Button {
                browser.goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!browser.canGoBack)
            .help(L10n.text("research.back"))

            Button {
                browser.goForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!browser.canGoForward)
            .help(L10n.text("research.forward"))

            Button {
                browser.reload()
                urlBuildFailed = false
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help(L10n.text("research.reload"))

            Button {
                openCurrentInSystemBrowser()
            } label: {
                Image(systemName: "arrow.up.right.square")
            }
            .help(L10n.text("research.open_in_browser"))

            if browser.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(L10n.text("research.search_field_prompt"), text: $queryText)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submitSearchField)
            if !unknownVariables.isEmpty {
                Text(L10n.text("research.unknown_variables", ["variables": unknownVariables.joined(separator: "、")]))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var webArea: some View {
        ZStack {
            EmbeddedWebView(controller: browser)
            if urlBuildFailed {
                failureOverlay(
                    title: L10n.text("research.url_build_failed_title"),
                    retry: { apply(queryType: selectedQuery) }
                )
            } else if browser.loadFailed {
                failureOverlay(
                    title: L10n.text("research.load_failed_title"),
                    message: L10n.text("research.load_failed_message"),
                    retry: { browser.reload() }
                )
            }
        }
    }

    private func failureOverlay(title: String, message: String? = nil, retry: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)
            if let message {
                Text(message)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button(L10n.text("research.reload"), action: retry)
                Button(L10n.text("research.open_in_browser"), action: openCurrentInSystemBrowser)
            }
            .textSelection(.disabled)
        }
        .textSelection(.enabled)
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.92))
    }

    private func apply(queryType: ServiceResearchQueryType) {
        selectedQuery = queryType
        let result = research.query(item: item, type: queryType, settings: settings)
        queryText = result.query
        unknownVariables = result.unknownVariables
        load(queryOrURL: result.query)
    }

    private func submitSearchField() {
        load(queryOrURL: queryText)
    }

    private func load(queryOrURL: String) {
        switch research.destination(from: queryOrURL) {
        case .url(let url):
            urlBuildFailed = false
            browser.load(url)
        case .invalid:
            urlBuildFailed = true
            #if DEBUG
            print("[Research] unable to build search URL for \(queryOrURL)")
            #endif
        }
    }

    private func openCurrentInSystemBrowser() {
        if let current = browser.currentURL {
            NSWorkspace.shared.open(current)
            return
        }
        if case .url(let url) = research.destination(from: queryText) {
            NSWorkspace.shared.open(url)
        }
    }
}
