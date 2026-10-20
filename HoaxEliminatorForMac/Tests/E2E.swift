import Foundation

// End-to-end check against the real ~/Library with a throwaway app "HoaxDummy" (com.example.HoaxDummy).
// Creates and removes only paths named after the dummy or "e2etest"; trashed items land in ~/.Trash.
//   ./build.sh test --e2e     plant, scan, trash, verify, clean (no UI)
//   ./build.sh test --plant   plant, then open the app: the fake leftovers show up under Veraport and TouchEn nxKey.
//                             Remove those two rows (on a Mac with real leftovers they are in the same rows)
//   ./build.sh test --verify  check that the UI removed the fake leftovers
//   ./build.sh test --clean   remove every dummy trace
enum E2E {
    static let id = "com.example.HoaxDummy", agent = "com.example.HoaxDummy.agent"
    static let app = URL(filePath: FileManager.default.currentDirectoryPath).appending(path: ".build/e2e/HoaxDummy.app")
    static let lib = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library")
    static let removed = [  // offered checked, must leave their original place
        "Preferences/com.example.HoaxDummy.plist",  // uchg-locked: exercises the flag clearing in trash()
        "Caches/com.example.HoaxDummy", "Application Support/HoaxDummy", "Saved Application State/com.example.HoaxDummy.savedState",
        "Logs/HoaxDummy", "HTTPStorages/com.example.HoaxDummy", "LaunchAgents/com.example.HoaxDummy.agent.plist",
    ]
    static let kept = "Group Containers/com.example.HoaxDummy"  // offered unchecked
    static let decoy = "Application Support/HoaxDummyOther"     // never offered
    static let security = ["veraport": "Preferences/com.wizvera.veraport.e2etest.plist", "nxkey": "LaunchAgents/com.raon.e2etest.plist"]
    static var failures = 0

    static func check(_ ok: Bool, _ what: String) {
        print(ok ? "  ✓" : "  ✗", what)
        if !ok { failures += 1 }
    }

    static func exists(_ rel: String) -> Bool { (try? FileManager.default.attributesOfItem(atPath: lib.appending(path: rel).path)) != nil }
    static var agentLoaded: Bool { sh("/bin/launchctl", "print", "gui/\(getuid())/\(agent)") == 0 }

    static func plant() throws {
        clean()
        let fm = FileManager.default
        try fm.createDirectory(at: app.appending(path: "Contents/MacOS"), withIntermediateDirectories: true)
        try plist(["CFBundleIdentifier": id, "CFBundleName": "HoaxDummy", "CFBundleExecutable": "HoaxDummy", "CFBundlePackageType": "APPL"])
            .write(to: app.appending(path: "Contents/Info.plist"))
        try Data("#!/bin/sh\n".utf8).write(to: app.appending(path: "Contents/MacOS/HoaxDummy"))
        for rel in removed + [kept, decoy] + security.values {
            let url = lib.appending(path: rel)
            if rel.hasSuffix(".plist") {
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                // No RunAtLoad/KeepAlive: launchd never actually starts these jobs.
                try plist(["Label": url.deletingPathExtension().lastPathComponent, "ProgramArguments": ["/usr/bin/true"]]).write(to: url)
            } else {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
                try Data("e2e".utf8).write(to: url.appending(path: "data"))
            }
        }
        chflags(lib.appending(path: removed[0]).path, UInt32(UF_IMMUTABLE))
        sh("/bin/launchctl", "bootstrap", "gui/\(getuid())", lib.appending(path: "LaunchAgents/\(agent).plist").path)
        print("planted \(app.path) and its traces in ~/Library")
    }

    // Manual UI run: only the fake security leftovers are reachable from the window.
    static func verifyUI() {
        for (product, rel) in security.sorted(by: <) { check(!exists(rel), "\(product): ~/Library/\(rel) removed") }
    }

    static func verify() {
        check(!FileManager.default.fileExists(atPath: app.path), "app bundle moved")
        for rel in removed { check(!exists(rel), "moved: ~/Library/\(rel)") }
        check(exists(kept), "unchecked group container left alone")
        check(exists(decoy), "decoy left alone")
        check(!agentLoaded, "launch agent unloaded")
    }

    // Removes the dummy's traces. Trashed items can only be removed by exact path: macOS hides ~/.Trash listings.
    static func clean(trashed: [URL] = []) {
        sh("/bin/launchctl", "bootout", "gui/\(getuid())/\(agent)")
        let paths = (removed + [kept, decoy] + security.values).map { lib.appending(path: $0).path } + trashed.map(\.path)
        for p in paths {
            chflags(p, 0)
            try? FileManager.default.removeItem(atPath: p)
        }
        try? FileManager.default.removeItem(at: app.deletingLastPathComponent())
    }

    static func run() throws {
        try plant()
        print("scan HoaxDummy")
        guard let target = AppTarget(url: app) else { check(false, "dummy app readable"); return }
        check(target.refusal == nil, "dummy app accepted")
        check(agentLoaded, "launch agent loaded before removal")
        let found = [Found(url: target.url)] + target.relatedFiles()
        let offered = Dictionary(uniqueKeysWithValues: found.map { ($0.url.path.replacingOccurrences(of: lib.path + "/", with: ""), $0.selected) })
        let expected = Dictionary(uniqueKeysWithValues: removed.map { ($0, true) } + [(kept, false), (app.path, true)])
        check(offered == expected, "offered exactly the planted traces" + (offered == expected ? "" : ": \(offered)"))

        print("move to Trash")
        var (trashed, failed) = trash(found.filter(\.selected).map(\.url))
        check(failed.isEmpty, "no failures" + (failed.isEmpty ? "" : ": \(failed)"))
        verify()

        print("security programs (fake user-domain leftovers)")
        let hits = scanSecurity()
        for (product, rel) in security.sorted(by: <) {
            check(hits.first { $0.id == product }?.files.contains(lib.appending(path: rel)) == true, "\(product) finds ~/Library/\(rel)")
        }
        let sec = trash(security.values.map { lib.appending(path: $0) })
        trashed += sec.moved
        check(sec.failed.isEmpty && security.values.allSatisfy { !exists($0) }, "fake leftovers moved")

        clean(trashed: trashed)
        print(failures == 0 ? "e2e ok" : "e2e: \(failures) failure(s)")
    }

    static func plist(_ dict: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
    }

    @discardableResult
    static func sh(_ tool: String, _ args: String...) -> Int32 {
        let p = Process()
        p.executableURL = URL(filePath: tool)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return -1 }
        p.waitUntilExit()
        return p.terminationStatus
    }
}
