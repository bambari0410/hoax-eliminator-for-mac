import Foundation

switch CommandLine.arguments.dropFirst().first {
case "--e2e": try E2E.run(); exit(E2E.failures == 0 ? 0 : 1)
case "--plant": try E2E.plant(); exit(0)
case "--verify": E2E.verify(); exit(E2E.failures == 0 ? 0 : 1)
case "--clean": E2E.clean(); exit(0)
default: break
}

// Read-only peeks at the real system: .build/check --security | .build/check /Applications/Foo.app
if CommandLine.arguments.dropFirst().first == "--security" {
    for hit in scanSecurity() { print("[\(hit.id)] \(hit.product.name)", hit.files.map(\.path), hit.receipts, hit.certs.map(\.shown)) }
    exit(0)
}
if CommandLine.arguments.count > 1, let app = AppTarget(url: URL(filePath: CommandLine.arguments[1])) {
    for f in app.relatedFiles() { print(f.selected ? "[x]" : "[ ]", f.url.path) }
    exit(0)
}

let tag = "appsweep-check-\(UUID().uuidString)"
let tmp = FileManager.default.temporaryDirectory.appending(path: tag)
defer { try? FileManager.default.removeItem(at: tmp) }
let roots = Roots(libraries: [tmp.appending(path: "home/Library"), tmp.appending(path: "sys/Library")],
                  receipts: tmp.appending(path: "receipts"), shared: tmp.appending(path: "Shared"))

func touch(_ paths: [String]) throws {
    for p in paths {
        let url = tmp.appending(path: p)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: Data("x".utf8))
    }
}
func rel(_ found: [Found]) -> [String: Bool] {
    Dictionary(uniqueKeysWithValues: found.map { ($0.url.path.components(separatedBy: tag + "/").last!, $0.selected) })
}

// bundle id normalization
assert(AppTarget.normalizeBundleID("com.acme.FooApp.app2") == "com.acme.FooApp")
assert(AppTarget.normalizeBundleID("com.acme.b") == "com.acme")
assert(AppTarget.normalizeBundleID("com.acme.FooApp") == "com.acme.FooApp")

let expected = [
    "home/Library/Preferences/com.acme.FooApp.plist", "home/Library/Preferences/FooApp Settings.plist",
    "home/Library/Preferences/ByHost/com.acme.FooApp.1234.plist", "home/Library/Containers/com.acme.FooApp",
    "home/Library/Application Support/Foo App", "home/Library/Application Support/Foo App 2", "home/Library/Application Support/FooApp_cache",
    "sys/Library/Caches/com.acme.FooApp", "home/Library/Caches/xcom.acme.FooApp.tmp",
    "home/Library/Saved Application State/com.acme.FooApp.savedState", "home/Library/Cookies/com.acme.FooApp.binarycookies",
    "sys/Library/LaunchDaemons/com.acme.FooApp.helper.plist", "sys/Library/PrivilegedHelperTools/com.acme.FooApp.helper",
    "home/Library/Logs/DiagnosticReports/FooApp_2026-10-20.ips", "home/Library/Logs/Foo App", "home/Library/Logs/sub/Foo App.log",
    "receipts/com.acme.FooApp.pkg.bom", "Shared/Foo App",
]
let unchecked = ["home/Library/Group Containers/TEAM.group.acme", "Apps/Foo App"]  // shared group container, parent folder
let unrelated = ["home/Library/Preferences/com.other.plist", "home/Library/Containers/com.acme.FooApp.helper",
                 "home/Library/Application Support/Foo Apple", "home/Library/Logs/a/b/Foo App.log"]
try touch(["home/Library/Logs/Foo App/x.log", "Apps/Foo App/Foo App.app/x"] + expected + unchecked + unrelated)

let app = AppTarget(url: tmp.appending(path: "Apps/Foo App/Foo App.app"), bundleID: "com.acme.FooApp", name: "Foo App",
                    executable: "FooApp", groups: ["TEAM.group.acme"])
let found = rel(app.relatedFiles(in: roots))
assert(Set(found.keys) == Set(expected + unchecked), "diff: \(Set(found.keys).symmetricDifference(expected + unchecked).sorted())")
assert(expected.allSatisfy { found[$0] == true } && unchecked.allSatisfy { found[$0] == false })

// protected Library folders are never offered, even when the name matches
try touch(["home/Library/Fonts/a"])
let fonts = AppTarget(url: tmp.appending(path: "Apps/Fonts.app"), name: "Fonts", executable: "Fonts")
assert(rel(fonts.relatedFiles(in: roots)).keys.allSatisfy { !$0.hasSuffix("Library/Fonts") })

// security catalog: dangling launchd symlink, globs, and AhnLab V3 must not be caught by the ASTx entry
try touch(["sec/Library/LaunchDaemons/com.interezen.nwsdaemon.plist", "sec/Library/LaunchDaemons/com.ahnlab.v3.plist",
           "sec/Library/Application Support/wizvera/veraport/veraport.dat", "sec/home/Library/Preferences/com.ahnlab.safetransaction.Status.plist"])
try FileManager.default.createDirectory(at: tmp.appending(path: "sec/Library/LaunchAgents"), withIntermediateDirectories: true)
try FileManager.default.createSymbolicLink(atPath: tmp.appending(path: "sec/Library/LaunchAgents/com.wizvera.veraport.plist").path,
                                           withDestinationPath: "/nonexistent/veraport.plist")
let sec = scanSecurity(root: tmp.appending(path: "sec").path, home: tmp.appending(path: "sec/home").path, receipts: ["com.ahnlab.astxd.pkg", "com.apple.pkg.Core"],
                       certs: [SystemCert(label: "INTEREZEN CA", issuer: "INTEREZEN CA", sha1: "", pem: ""),
                               SystemCert(label: "127.0.0.1", issuer: "VERAPORT-CA", sha1: "", pem: ""),  // local cert signed by Veraport's CA
                               SystemCert(label: "Apple Root CA", issuer: "Apple Root CA", sha1: "", pem: "")])
let hits = Dictionary(uniqueKeysWithValues: sec.map { ($0.id, $0.files.map { $0.path.components(separatedBy: "sec/").last! }) })
assert(hits == ["ipinside": ["Library/LaunchDaemons/com.interezen.nwsdaemon.plist"],
                "veraport": ["Library/Application Support/wizvera/veraport", "Library/LaunchAgents/com.wizvera.veraport.plist"],
                "astx": ["home/Library/Preferences/com.ahnlab.safetransaction.Status.plist"]], "\(hits)")
assert(sec.first { $0.id == "astx" }?.receipts == ["com.ahnlab.astxd.pkg"])
assert(sec.first { $0.id == "veraport" }?.certs.map(\.label) == ["127.0.0.1"] && sec.first { $0.id == "ipinside" }?.certs.map(\.label) == ["INTEREZEN CA"])

// privileged plan: allowlist, quoting, and nothing but scan results reach root (built only, never run here)
let tester = "/Users/tester"
for ok in ["/Library/LaunchDaemons/com.interezen.nwsdaemon.plist", "/Library/Application Support/wizvera/veraport", "/Applications/Veraport",
           "/private/var/db/receipts/com.x.bom", tester + "/Library/Preferences/com.x.plist"] { assert(allowedAsRoot(URL(filePath: ok), home: tester), ok) }
for bad in ["/Library/LaunchDaemons", "/Library/Application Support", "/Library/Application Support/wizvera", "/Applications", "/System/Library/Foo",
            "/etc/hosts", "/usr/local/bin/x", "/Library/Keychains/System.keychain", tester + "/Library/Preferences/NPKI/yessign",
            "/Library/../etc/passwd", "/Library/Google/Chrome/NativeMessagingHosts", tester + "/Library/Fonts"] {
    assert(!allowedAsRoot(URL(filePath: bad), home: tester), bad)
}
assert(shQuote("/a'b") == "'/a'\\''b'")
let rootPlan = privilegedPlan(files: [URL(filePath: "/Library/LaunchDaemons/com.example.gone.plist"), URL(filePath: "/Library/Application Support/iniLINE/CrossEX/touchenex"),
                                      URL(filePath: "/etc/hosts")],
                              receipts: ["com.interezen.IPinside", "x; rm -rf /"],
                              certs: [SystemCert(label: "INTEREZEN CA", issuer: "", sha1: String(repeating: "A", count: 40),
                                                 pem: "-----BEGIN CERTIFICATE-----\nQUJD\n-----END CERTIFICATE-----\n"),
                                      SystemCert(label: "evil", issuer: "", sha1: "A; rm -rf /", pem: "")],
                              home: tester, uid: 501)
let shown = rootPlan.preview.split(separator: "\n").map(String.init)
assert(rootPlan.skipped == ["/etc/hosts"], "\(rootPlan.skipped)")
assert(shown == [
    "launchctl bootout 'system/com.example.gone' 2>/dev/null",
    "mv -n '/Library/LaunchDaemons/com.example.gone.plist' '/Users/tester/.Trash/com.example.gone.plist' && [ ! -e '/Library/LaunchDaemons/com.example.gone.plist' ] && [ ! -L '/Library/LaunchDaemons/com.example.gone.plist' ] || echo 'failed: /Library/LaunchDaemons/com.example.gone.plist'",
    "mv -n '/Library/Application Support/iniLINE/CrossEX/touchenex' '/Users/tester/.Trash/touchenex' && [ ! -e '/Library/Application Support/iniLINE/CrossEX/touchenex' ] && [ ! -L '/Library/Application Support/iniLINE/CrossEX/touchenex' ] || echo 'failed: /Library/Application Support/iniLINE/CrossEX/touchenex'",
    "pkgutil --forget com.interezen.IPinside >/dev/null || echo 'failed: receipt com.interezen.IPinside'",
    "security remove-trusted-cert -d <INTEREZEN CA PEM>; security delete-certificate -Z \(String(repeating: "A", count: 40)) /Library/Keychains/System.keychain",
    "rmdir '/Library/Application Support/iniLINE/CrossEX' 2>/dev/null",
    "rmdir '/Library/Application Support/iniLINE' 2>/dev/null",
], shown.joined(separator: "\n"))
assert(!rootPlan.steps.map(\.script).joined().contains("rm -rf /") && !rootPlan.steps.map(\.script).joined().contains("/etc/hosts"))

print("ok: \(found.count) related files, \(unrelated.count) unrelated ignored")
