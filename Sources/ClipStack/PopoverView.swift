import SwiftUI

struct PopoverView: View {
    @ObservedObject var monitor: ClipboardMonitor
    @ObservedObject var loginItem: LoginItem
    var dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if monitor.clippings.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(monitor.clippings.enumerated()), id: \.element.id) { index, clipping in
                            ClippingRow(index: index, clipping: clipping) {
                                monitor.copy(clipping)
                                dismiss()
                            }
                            if clipping.id != monitor.clippings.last?.id {
                                Divider().padding(.leading, 32)
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
            }

            Divider()
            footer
        }
        .frame(width: 320)
    }

    private var header: some View {
        HStack {
            Text("ClipStack").font(.system(size: 13, weight: .semibold))
            Spacer()
            if !monitor.clippings.isEmpty {
                Button("Clear") { monitor.clear() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "clipboard")
                .font(.system(size: 20))
                .foregroundStyle(.tertiary)
            Text("Nothing copied yet")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Toggle("Launch at login", isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.setEnabled($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

            Spacer()

            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}

private struct ClippingRow: View {
    let index: Int
    let clipping: ClipboardMonitor.Clipping
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                Text("\(index + 1)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 12, alignment: .trailing)

                leading

                VStack(alignment: .leading, spacing: 2) {
                    Text(clipping.preview)
                        .font(.system(size: 12))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let detail = clipping.detail {
                        Text(detail)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(isHovering ? Color.primary.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Copy to clipboard")
    }

    /// Screenshots get a thumbnail, files get their Finder icon, text gets nothing.
    @ViewBuilder
    private var leading: some View {
        switch clipping.payload {
        case .image:
            if let thumbnail = clipping.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 34, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .overlay(RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(width: 34, height: 24)
            }
        case .files(let paths):
            Image(nsImage: NSWorkspace.shared.icon(forFile: paths[0]))
                .resizable()
                .frame(width: 16, height: 16)
        case .text:
            EmptyView()
        }
    }
}
