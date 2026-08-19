import SwiftUI
import AppKit

struct PlistViewerSheet: View {
    let plistPath: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("plist")
                        .font(.headline)
                    Text(plistPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                Button("關閉") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            ScrollView {
                Text(contents)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .frame(minWidth: 640, minHeight: 480)
    }

    private var contents: String {
        do {
            return try String(contentsOf: URL(fileURLWithPath: plistPath), encoding: .utf8)
        } catch {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
               let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
               let xml = try? PropertyListSerialization.data(fromPropertyList: object, format: .xml, options: 0),
               let text = String(data: xml, encoding: .utf8) {
                return text
            }
            return "無法讀取 plist：\(error.localizedDescription)"
        }
    }
}

struct SessionLogSheet: View {
    let entries: [SessionLogEntry]
    @Environment(\.dismiss) private var dismiss

    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("工作階段紀錄")
                    .font(.headline)
                Spacer()
                Button("關閉") { dismiss() }
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(entries) { entry in
                        Text("\(formatter.string(from: entry.date)) \(entry.message)")
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    if entries.isEmpty {
                        Text("尚無紀錄")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 360)
    }
}
