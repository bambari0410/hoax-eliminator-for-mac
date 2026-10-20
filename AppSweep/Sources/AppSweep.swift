import SwiftUI

// Layout follows HoaxEliminator (구라제거기) for Windows: select-all line, program table, options, four buttons, status bar.

@main
struct AppSweep: App {
    var body: some Scene {
        WindowGroup("AppSweep · 맥용 보안 프로그램 제거기") {
            MainView().frame(minWidth: 760, minHeight: 660)
        }
    }
}

struct Row: Identifiable {
    let hit: SecurityHit
    var checked: Bool
    let installed: Date?
    var id: String { hit.id }
    var isHidden: Bool { hit.id == "hidden" }
    var systemWide: Bool { !hit.receipts.isEmpty || !hit.certs.isEmpty || hit.files.contains { !$0.path.hasPrefix(NSHomeDirectory() + "/") } }
}

struct MainView: View {
    @State private var rows: [Row] = []
    @State private var selection: Row.ID?
    @State private var status = ""
    @State private var scanning = false
    @State private var pending: Cleanup?
    @State private var report: Report?
    @State private var showHelp = false
    @State private var showWork = false
    @AppStorage("removeCerts") private var removeCerts = true
    @AppStorage("forgetReceipts") private var forgetReceipts = true
    @AppStorage("findHidden") private var findHidden = false
    @AppStorage("keepWork") private var keepWork = true
    @AppStorage("workPrograms") private var workPrograms = ""
    @AppStorage("seenIntro") private var seenIntro = false

    private var work: Set<String> { Set(workPrograms.split(separator: ",").map(String.init)) }
    private func isKept(_ row: Row) -> Bool { keepWork && work.contains(row.id) }
    private var removable: [Row] { rows.filter { !isKept($0) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            table
            details
            options
            buttons
            Divider()
            statusBar
        }
        .padding([.horizontal, .top])
        .padding(.bottom, 6)
        .onAppear {
            scan()
            if !seenIntro { showHelp = true; seenIntro = true }
        }
        .onChange(of: findHidden) { _ in scan() }
        .sheet(isPresented: $showHelp) { HelpSheet() }
        .sheet(isPresented: $showWork) { WorkSheet(workPrograms: $workPrograms) }
        .sheet(item: $pending) { cleanup in ConfirmSheet(cleanup: cleanup) { perform(cleanup) } }
        .sheet(item: $report) { ReportSheet(report: $0) }
    }

    private var header: some View {
        HStack {
            Toggle("발견된 보안 프로그램: \(rows.filter { !$0.isHidden }.count)개", isOn: allChecked).disabled(removable.isEmpty)
            Spacer()
            Button { scan() } label: { Image(systemName: "arrow.clockwise") }.help("목록 다시 읽기")
            Button { NSWorkspace.shared.open(URL(filePath: NSHomeDirectory() + "/.Trash")) } label: { Image(systemName: "trash") }
                .help("휴지통 열기: 지운 파일은 여기로 가요")
            Button { showHelp = true } label: { Image(systemName: "questionmark.circle") }.help("윈도우판과 다른 점, 안전하게 지우는 방법")
        }
    }

    private var table: some View {
        Table(rows, selection: $selection) {
            TableColumn("프로그램") { row in
                HStack(spacing: 8) {
                    Toggle("", isOn: checked(row.id)).labelsHidden().disabled(isKept(row))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.hit.product.name)
                        Text(row.hit.product.vendor).font(.caption).foregroundStyle(.secondary)
                    }
                    if isKept(row) { Badge(text: "업무용", color: .blue) }
                }
            }
            TableColumn("위치") { row in
                Badge(text: row.systemWide ? "시스템" : "사용자", color: row.systemWide ? .orange : .green)
                    .help(row.systemWide ? "맥 전체에 설치돼 있어요. 지울 때 관리자 암호가 필요해요." : "내 계정에만 있어요.")
            }
            .width(80)
            TableColumn("설치일") { row in
                Text(row.installed?.formatted(.iso8601.year().month().day()) ?? "-").monospacedDigit().foregroundStyle(.secondary)
            }
            .width(100)
        }
        .tableStyle(.bordered(alternatesRowBackgrounds: true))
        .frame(minHeight: 200)
        .overlay {
            if rows.isEmpty && !scanning {
                VStack(spacing: 6) {
                    Text("깨끗해요").font(.title3.bold())
                    Text("이 맥에서 찾은 보안 프로그램이 없어요.").foregroundStyle(.secondary)
                }
            }
        }
    }

    // What the selected program left on this Mac, in plain words.
    private var details: some View {
        GroupBox {
            ScrollView {
                if let row = rows.first(where: { $0.id == selection }) {
                    VStack(alignment: .leading, spacing: 4) {
                        if row.isHidden {
                            Text("목록에 없는 이름이라 정확한지 알 수 없어요. 무엇인지 확인한 다음에 지우세요.").foregroundStyle(.orange)
                        }
                        ForEach(row.hit.files, id: \.self) { url in
                            Trace(kind: traceKind(url), text: url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        }
                        ForEach(row.hit.certs, id: \.sha1) { cert in
                            Trace(kind: "루트 인증서", text: cert.shown + " · 이 회사 인증서를 무조건 믿게 하는 설정이라 지우는 게 좋아요", warn: true)
                        }
                        ForEach(row.hit.receipts, id: \.self) { Trace(kind: "설치 기록", text: $0) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("목록에서 프로그램을 고르면 무엇이 남아 있는지 보여 드려요.").foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(height: 96)
        }
    }

    private var options: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "gearshape.2.fill").font(.system(size: 38)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 5) {
                Toggle("루트 인증서도 지우기 (권장)", isOn: $removeCerts)
                Toggle("설치 기록도 지우기", isOn: $forgetReceipts)
                Toggle("목록에 없는 숨은 프로그램도 찾기", isOn: $findHidden)
                Toggle("업무용 프로그램은 지우지 않기", isOn: $keepWork)
            }
        }
    }

    private var buttons: some View {
        HStack {
            Button("업무용 프로그램 관리…") { showWork = true }
            Spacer()
            Button("목록 다시 읽기") { scan() }
            Button("선택 항목 제거") { confirm(removable.filter(\.checked)) }.disabled(!removable.contains(where: \.checked))
            Button("모두 제거") { confirm(removable.filter { !$0.isHidden || $0.checked }) }.disabled(!removable.contains { !$0.isHidden })
        }
        .controlSize(.large)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Text("\(rows.filter(\.checked).count)/\(rows.count) 선택 · 검사 대상 \(securityCatalog.count)종").monospacedDigit()
            Divider().frame(height: 12)
            Text(status).lineLimit(1).truncationMode(.tail)
            Spacer()
            if scanning { ProgressView().controlSize(.small) }
        }
        .font(.callout).foregroundStyle(.secondary)
    }

    private var allChecked: Binding<Bool> {
        Binding(get: { !removable.isEmpty && removable.filter { !$0.isHidden }.allSatisfy(\.checked) },
                set: { on in for i in rows.indices where !isKept(rows[i]) && !rows[i].isHidden { rows[i].checked = on } })
    }

    private func checked(_ id: String) -> Binding<Bool> {
        Binding(get: { rows.first { $0.id == id }?.checked ?? false },
                set: { on in if let i = rows.firstIndex(where: { $0.id == id }) { rows[i].checked = on } })
    }

    private func scan() {
        scanning = true
        status = "찾는 중이에요…"
        let hidden = findHidden, kept = work, keep = keepWork
        Task.detached {
            var hits = scanSecurity()
            if hidden {
                let suspects = hiddenSuspects(excluding: hits.flatMap(\.files))
                if !suspects.isEmpty {
                    hits.append(SecurityHit(product: SecurityProduct(id: "hidden", name: "목록에 없는 의심 항목", vendor: "이름만 보고 찾았어요. 꼭 확인하고 지우세요"),
                                            files: suspects, receipts: [], certs: []))
                }
            }
            let found = hits.map { Row(hit: $0, checked: $0.id != "hidden" && !(keep && kept.contains($0.id)), installed: installDate(of: $0)) }
            await MainActor.run {
                rows = found
                scanning = false
                let count = found.filter { !$0.isHidden }.count
                status = count == 0 ? "찾은 보안 프로그램이 없어요." : "보안 프로그램 \(count)개를 찾았어요. 지운 파일은 휴지통으로 가요."
            }
        }
    }

    private func confirm(_ chosen: [Row]) {
        guard !chosen.isEmpty else { return }
        pending = makeCleanup(chosen.map(\.hit), certs: removeCerts, receipts: forgetReceipts)
    }

    // Admin part first: if the password prompt is cancelled, nothing has changed yet.
    private func perform(_ cleanup: Cleanup) {
        status = "정리하는 중이에요…"
        var failed: [String] = []
        if !cleanup.plan.isEmpty {
            switch runPrivileged(cleanup.plan) {
            case .cancelled:
                status = "취소했어요. 아무것도 바뀌지 않았어요."
                return
            case .error(let message):
                status = "관리자 권한으로 실행하지 못했어요."
                report = Report(cleanup: cleanup, failed: [message])
                return
            case .finished(let rootFailed):
                failed = rootFailed
            }
        }
        failed += trash(cleanup.userFiles).failed.map { "\($0.url.path) (\($0.reason))" }
        report = Report(cleanup: cleanup, failed: failed)
        scan()
    }
}

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text).font(.caption.weight(.medium)).padding(.horizontal, 7).padding(.vertical, 2)
            .background(color.opacity(0.18), in: Capsule()).foregroundStyle(color)
    }
}

struct Trace: View {
    let kind: String
    let text: String
    var warn = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(kind).font(.caption.weight(.medium)).frame(width: 92, alignment: .leading).foregroundStyle(warn ? .orange : .secondary)
            Text(text).font(.caption).textSelection(.enabled).lineLimit(2).truncationMode(.middle)
        }
    }
}

func traceKind(_ url: URL) -> String {
    let p = url.path
    if p.contains("/LaunchDaemons/") || p.contains("/LaunchAgents/") { return "자동 실행 설정" }
    if p.contains("/Internet Plug-Ins/") || p.contains("/NativeMessagingHosts/") { return "브라우저 연결" }
    if p.contains("/PrivilegedHelperTools/") { return "관리자 도우미" }
    if p.contains("/db/receipts/") { return "설치 기록" }
    if p.hasPrefix("/Applications/") || url.pathExtension == "app" { return "프로그램" }
    if p.contains("/Preferences/") { return "설정 파일" }
    if p.contains("/Caches/") || p.contains("/Logs/") || p.hasPrefix("/tmp/") || p.hasPrefix("/private/tmp/") { return "캐시·로그" }
    if p.contains("/Frameworks/") { return "공용 라이브러리" }
    return "지원 파일"
}

struct ConfirmSheet: View {
    let cleanup: Cleanup
    let run: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(cleanup.names.count)개 프로그램을 정리할게요").font(.title2.bold())
            Text(cleanup.names.joined(separator: ", ")).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                if cleanup.fileCount > 0 { Line("파일 \(cleanup.fileCount)개를 휴지통으로 옮겨요. 필요하면 휴지통에서 되돌릴 수 있어요.") }
                if cleanup.jobCount > 0 { Line("백그라운드에서 돌던 자동 실행 \(cleanup.jobCount)개를 멈춰요.") }
                if cleanup.certCount > 0 { Line("키체인에서 루트 인증서 \(cleanup.certCount)개를 지워요.") }
                if cleanup.receiptCount > 0 { Line("설치 기록 \(cleanup.receiptCount)개를 지워요.") }
                Line("공동인증서(NPKI) 폴더와 키체인의 다른 인증서는 건드리지 않아요.")
                if !cleanup.plan.isEmpty { Line("맥 전체에 설치된 항목이 있어서, 다음 단계에서 관리자 암호를 한 번 물어봐요.") }
            }

            if !cleanup.plan.skipped.isEmpty {
                Text("다른 프로그램과 같이 쓰는 위치라서 이번에는 건너뛰어요:\n" + cleanup.plan.skipped.joined(separator: "\n"))
                    .font(.caption).foregroundStyle(.orange)
            }

            if !cleanup.plan.isEmpty {
                DisclosureGroup("관리자 권한으로 실행할 명령 보기") {
                    ScrollView {
                        Text(cleanup.plan.preview).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                    }
                    .frame(height: 180).background(.quaternary.opacity(0.5))
                }
            }

            Text("은행이나 관공서 사이트에서 다시 설치하라고 할 수 있어요. 그때 설치하고, 볼일을 마치면 다시 정리하면 돼요.")
                .font(.callout).foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("취소", role: .cancel) { dismiss() }
                Button("정리하기") { dismiss(); run() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 600)
    }
}

struct Line: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.green)
            Text(text)
        }
    }
}

struct Report: Identifiable {
    let id = UUID()
    let cleanup: Cleanup
    let failed: [String]
}

struct ReportSheet: View {
    let report: Report
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(report.failed.isEmpty ? "정리했어요" : "일부는 지우지 못했어요").font(.title2.bold())
            VStack(alignment: .leading, spacing: 6) {
                Line("\(report.cleanup.names.joined(separator: ", "))")
                if report.cleanup.fileCount > 0 { Line("파일은 휴지통에 있어요. 휴지통을 비울 때 관리자 암호를 다시 물어볼 수 있어요.") }
            }
            if !report.failed.isEmpty {
                Text("남은 항목:\n" + report.failed.joined(separator: "\n")).font(.caption).textSelection(.enabled).foregroundStyle(.orange)
                Text("'목록 다시 읽기'를 눌러 다시 확인해 보세요. 계속 남으면 제작사 제거 프로그램을 실행해 보세요.").font(.callout)
            }
            HStack {
                Button("휴지통 열기") { NSWorkspace.shared.open(URL(filePath: NSHomeDirectory() + "/.Trash")) }
                Spacer()
                Button("확인") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 520)
    }
}

struct WorkSheet: View {
    @Binding var workPrograms: String
    @Environment(\.dismiss) private var dismiss

    private func binding(_ id: String) -> Binding<Bool> {
        Binding(get: { workPrograms.split(separator: ",").contains { $0 == id } },
                set: { on in
                    var ids = Set(workPrograms.split(separator: ",").map(String.init))
                    if on { ids.insert(id) } else { ids.remove(id) }
                    workPrograms = ids.sorted().joined(separator: ",")
                })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("업무용 프로그램 관리").font(.title2.bold())
            Text("회사 업무에 꼭 필요한 프로그램에 표시해 두세요. '업무용 프로그램은 지우지 않기'가 켜져 있으면 모두 제거할 때도 남겨 둬요.")
                .foregroundStyle(.secondary)
            List(securityCatalog) { product in
                Toggle(isOn: binding(product.id)) {
                    Text(product.name) + Text("  \(product.vendor)").foregroundColor(.secondary)
                }
            }
            .frame(height: 300)
            HStack {
                Spacer()
                Button("완료") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 520)
    }
}

struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("맥용 보안 프로그램 제거기").font(.title2.bold())
                Text("은행이나 관공서 사이트에서 깔라고 했던 보안 프로그램을 찾아서 한 번에 정리해요.").foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Section(title: "윈도우판과 이렇게 달라요") {
                        Para("윈도우의 구라제거기는 '프로그램 추가/제거' 목록에서 보안 프로그램을 찾고, 제작사 제거 프로그램을 차례로 실행해요. 맥에는 그런 목록이 없어서, 프로그램이 설치하면서 남긴 흔적을 하나하나 직접 찾아요.")
                        Para("그래서 찾는 대상도 달라요.")
                        Item(name: "프로그램", text: "응용 프로그램 폴더에 있는 앱과 폴더")
                        Item(name: "자동 실행 설정", text: "맥을 켤 때마다 뒤에서 돌던 항목이에요. 윈도우의 '서비스'와 비슷해요.")
                        Item(name: "브라우저 연결", text: "크롬이나 파이어폭스가 보안 프로그램과 통신하게 해 주는 파일")
                        Item(name: "루트 인증서", text: "이 회사가 만든 인증서를 무조건 믿게 하는 설정이에요. 제작사 제거 프로그램으로 지워도 남는 경우가 많아요.")
                        Item(name: "설치 기록", text: "맥이 기억하고 있는 설치 정보")
                        Para("ActiveX나 키보드 보안 드라이버처럼 윈도우에만 있는 것은 맥에 없어요. 맥용이 따로 없는 프로그램도 있어서 목록이 윈도우판과 조금 달라요.")
                        Para("'위치' 열의 시스템/사용자는 윈도우판의 HKLM/HKCU와 비슷해요. 맥 전체에 깔린 것은 지울 때 관리자 암호가 필요해요.")
                    }
                    Section(title: "이렇게 안전하게 지워요") {
                        Item(name: "휴지통으로", text: "파일은 바로 지우지 않고 휴지통으로 옮겨요. 잘못 지웠다면 휴지통에서 꺼내면 돼요.")
                        Item(name: "손대지 않는 곳", text: "공동인증서(NPKI) 폴더, 키체인의 다른 인증서, macOS 시스템 폴더는 건드리지 않아요.")
                        Item(name: "같이 쓰는 폴더", text: "여러 회사 프로그램이 같이 쓰는 폴더는 비어 있을 때만 정리해요.")
                        Item(name: "미리 보여 드려요", text: "관리자 암호가 필요한 작업은 실행하기 전에 무엇을 하는지 모두 보여 드려요.")
                        Item(name: "업무용", text: "회사 업무에 필요한 프로그램은 '업무용'으로 표시해 두면 지우지 않아요.")
                    }
                    Section(title: "다시 필요해지면") {
                        Para("은행 사이트에 들어가면 설치하라고 다시 안내해요. 그때 설치하고, 볼일을 마치면 다시 정리하면 돼요.")
                    }
                    Text("윈도우용 구라제거기(BLUEnLIVE)에서 아이디어를 얻은 별도 프로그램이에요. 보안 프로그램 목록은 hoax-eliminator-mac(MIT 라이선스)을 바탕으로, 각 제작사의 맥용 설치 파일을 직접 확인해서 고쳤어요.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Spacer()
                Button("확인") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 580, height: 600)
    }

    struct Section<Content: View>: View {
        let title: String
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                content
            }
        }
    }

    struct Para: View {
        let text: String
        init(_ text: String) { self.text = text }
        var body: some View { Text(text).fixedSize(horizontal: false, vertical: true) }
    }

    struct Item: View {
        let name: String
        let text: String

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(name).font(.callout.weight(.semibold)).frame(width: 104, alignment: .leading)
                Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
