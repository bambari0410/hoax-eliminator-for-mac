import SwiftUI
import UniformTypeIdentifiers

@main
struct AppSweep: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView().tabItem { Text("Apps") }
                SecurityView().tabItem { Text("Security Programs") }
            }
            .frame(minWidth: 560, minHeight: 420)
        }
    }
}

struct Item: Identifiable {
    let url: URL
    let size: Int64
    var on: Bool
    let selectable: Bool
    var id: URL { url }
}

struct ItemRow: View {
    @Binding var item: Item

    var body: some View {
        Toggle(isOn: $item.on) {
            HStack {
                Text(item.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")).lineLimit(1).truncationMode(.middle)
                Spacer()
                Text(item.size.formatted(.byteCount(style: .file))).foregroundStyle(.secondary)
            }
        }
        .disabled(!item.selectable)
    }
}

// Shows exactly what will run as root before macOS asks for the administrator password.
struct PrivilegedSheet: View {
    let plan: PrivilegedPlan
    let run: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Some items need administrator rights").font(.headline)
            Text("These commands will run as root. They only touch items from the scan; files go to the Trash.").foregroundStyle(.secondary)
            ScrollView {
                Text(plan.preview).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
            .frame(minHeight: 220).background(.quaternary.opacity(0.5))
            if !plan.skipped.isEmpty {
                Text("Skipped (outside the allowed locations): " + plan.skipped.joined(separator: ", ")).font(.caption).foregroundStyle(.orange)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Run as Administrator…") { dismiss(); run() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 640)
    }
}

struct SecurityView: View {
    struct Group: Identifiable {
        let hit: SecurityHit
        var items: [Item]
        var forget = true  // pkgutil --forget the receipts
        var revoke = true  // remove the trusted root CAs
        var id: String { hit.id }
        var hasWork: Bool { items.contains(where: \.on) || forget && !hit.receipts.isEmpty || revoke && !hit.certs.isEmpty }
    }
    @State private var groups: [Group] = []
    @State private var message: String?
    @State private var plan: PrivilegedPlan?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            List {
                ForEach($groups) { $group in
                    Section("\(group.hit.product.name) · \(group.hit.product.vendor)") {
                        ForEach($group.items) { ItemRow(item: $0) }
                        if !group.hit.receipts.isEmpty {
                            Toggle("Forget install receipts: " + group.hit.receipts.joined(separator: ", "), isOn: $group.forget)
                        }
                        if !group.hit.certs.isEmpty {
                            Toggle("Remove trusted root CA from the System keychain: " + group.hit.certs.map(\.shown).joined(separator: ", "), isOn: $group.revoke)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .overlay { if groups.isEmpty { Text("No Korean security programs found.").foregroundStyle(.secondary) } }
            HStack {
                Button("Rescan", action: scan)
                Spacer()
                Button("Remove Selected", role: .destructive, action: remove).disabled(!groups.contains(where: \.hasWork))
            }
            if let message { Text(message).textSelection(.enabled) }
        }
        .padding()
        .onAppear(perform: scan)
        .sheet(item: $plan) { plan in PrivilegedSheet(plan: plan) { message = runPrivileged(plan); scan() } }
    }

    // ponytail: a few dozen stat calls plus one pkgutil run, fine on the main thread.
    private func scan() {
        groups = scanSecurity().map { hit in
            Group(hit: hit, items: hit.files.map { Item(url: $0, size: diskSize(of: $0), on: !isSIPRestricted($0), selectable: !isSIPRestricted($0)) })
        }
    }

    private func remove() {
        let urls = groups.flatMap { $0.items.filter(\.on).map(\.url) }
        let paths = Set(urls.map(\.path))  // nxKey lives inside CrossEX's folder: trash the parent only
        let failed = trash(urls.filter { u in !paths.contains { u.path.hasPrefix($0 + "/") } }).failed
        // Root-owned leftovers, receipts and certificates go through one administrator run.
        let rootPlan = privilegedPlan(files: failed.map(\.url), receipts: groups.filter(\.forget).flatMap(\.hit.receipts),
                                      certs: groups.filter(\.revoke).flatMap(\.hit.certs))
        message = failed.isEmpty ? "Moved to Trash." : nil
        if !rootPlan.isEmpty { plan = rootPlan }
        scan()
    }
}

struct ContentView: View {
    @State private var app: AppTarget?
    @State private var items: [Item] = []
    @State private var message: String?
    @State private var picking = false
    @State private var scanning = false
    @State private var plan: PrivilegedPlan?

    private var selectedSize: Int64 { items.filter(\.on).reduce(0) { $0 + $1.size } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let app {
                HStack {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                    VStack(alignment: .leading) {
                        Text(app.name).font(.title2.bold())
                        Text(app.bundleID ?? "").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Back") { self.app = nil; items = []; scanning = false }
                }
                List($items) { ItemRow(item: $0) }
                .overlay { if scanning { ProgressView() } }
                HStack {
                    Text("\(items.filter(\.on).count) items, \(selectedSize.formatted(.byteCount(style: .file)))")
                    Spacer()
                    Button("Move to Trash", role: .destructive, action: remove).disabled(!items.contains(where: \.on))
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "trash").font(.system(size: 48))
                    Text("Drop an app here")
                    Button("Choose…") { picking = true }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8])).foregroundStyle(.secondary))
            }
            if let message { Text(message).textSelection(.enabled) }
        }
        .padding()
        .dropDestination(for: URL.self) { urls, _ in urls.first.map(select); return true }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.applicationBundle]) { if case .success(let url) = $0 { select(url) } }
        .sheet(item: $plan) { plan in PrivilegedSheet(plan: plan) { message = runPrivileged(plan); app = nil; items = [] } }
    }

    private func select(_ url: URL) {
        message = nil
        guard let target = AppTarget(url: url) else { message = "Not an app bundle."; return }
        if let refusal = target.refusal { message = refusal; return }
        app = target
        items = []
        scanning = true
        Task.detached {
            let found = [Found(url: target.url)] + target.relatedFiles()
            let items = found.map { Item(url: $0.url, size: diskSize(of: $0.url), on: $0.selected && $0.selectable, selectable: $0.selectable) }
            await MainActor.run {
                guard app?.url == target.url else { return }
                self.items = items
                scanning = false
            }
        }
    }

    private func remove() {
        let failed = trash(items.filter(\.on).map(\.url)).failed
        if failed.isEmpty { app = nil; items = []; message = "Moved to Trash."; return }
        message = failed.map { "\($0.url.path): \($0.reason)" }.joined(separator: "\n")
        let rootPlan = privilegedPlan(files: failed.map(\.url))  // e.g. root-owned receipts or /Library files
        if !rootPlan.isEmpty { plan = rootPlan }
    }
}
