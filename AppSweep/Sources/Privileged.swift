import Foundation

// Option (A) "run as administrator": a single `do shell script ... with administrator privileges` runs a script
// built only from scan results, after the user has seen every command. Files go to the Trash, never rm.

struct PrivilegedPlan: Identifiable {
    let id = UUID()
    var steps: [(shown: String, script: String)] = []
    var skipped: [String] = []  // offered paths outside the allowed locations: never sent to root
    var preview: String { steps.map(\.shown).joined(separator: "\n") }
    var isEmpty: Bool { steps.isEmpty }
}

let privilegedRoots = ["/Applications/", "/Library/", "/private/var/db/receipts/", "/Users/Shared/", "/private/tmp/", "/tmp/"]
// Vendor folders shared by several products: only removed with rmdir once empty, deepest first.
let sharedVendorDirs = ["/Library/Application Support/iniLINE/CrossEX", "/Library/Application Support/iniLINE", "/Library/Application Support/wizvera",
                        "/Library/Application Support/AhnLab", "/Applications/AhnLab", "/Applications/CrossEX", "/Applications/kica"]
let neverMoveAsRoot = ["/Applications/Utilities", "/Library/Google", "/Library/Google/Chrome", "/Library/Google/Chrome/NativeMessagingHosts",
                       "/Library/Application Support/Mozilla", "/Library/Application Support/Mozilla/NativeMessagingHosts"] + sharedVendorDirs

// The allowlist every root-moved path must pass, on top of coming from a scan.
func allowedAsRoot(_ url: URL, home: String = NSHomeDirectory()) -> Bool {
    let p = url.path
    guard !p.contains("\n"), !p.contains("/../"), !p.hasSuffix("/.."), url.standardizedFileURL.path == p,
          (privilegedRoots + [home + "/Library/"]).contains(where: { p.hasPrefix($0) && p.count > $0.count }),
          !p.contains("/Keychains"), !["NPKI", "GPKI", "MPKI"].contains(where: { p.contains("/Preferences/\($0)") })  // user certificates
    else { return false }
    let standard = Roots(libraries: [URL(filePath: home + "/Library"), URL(filePath: "/Library")]).protected
    return !standard.contains(p) && !neverMoveAsRoot.contains(p)
}

func shQuote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

func launchdLabel(_ plist: URL) -> String {
    NSDictionary(contentsOf: plist)?["Label"] as? String ?? plist.deletingPathExtension().lastPathComponent  // dangling link: file name
}

func privilegedPlan(files: [URL], receipts: [String] = [], certs: [SystemCert] = [], home: String = NSHomeDirectory(), uid: uid_t = getuid()) -> PrivilegedPlan {
    var plan = PrivilegedPlan()
    func add(_ shown: String, _ script: String? = nil) { plan.steps.append((shown, script ?? shown)) }
    var taken = Set<String>()
    plan.skipped = files.filter { !allowedAsRoot($0, home: home) }.map(\.path)
    let allowed = files.filter { allowedAsRoot($0, home: home) }
    for url in allowed {
        let p = url.path, q = shQuote(p)
        if p.hasPrefix("/Library/LaunchDaemons/") { add("launchctl bootout \(shQuote("system/" + launchdLabel(url))) 2>/dev/null") }
        if p.hasPrefix("/Library/LaunchAgents/") { add("launchctl bootout \(shQuote("gui/\(uid)/" + launchdLabel(url))) 2>/dev/null") }
        var dst = home + "/.Trash/" + url.lastPathComponent
        if (try? FileManager.default.attributesOfItem(atPath: dst)) != nil || taken.contains(dst) { dst += " " + UUID().uuidString.prefix(8) }
        taken.insert(dst)
        add("mv -n \(q) \(shQuote(dst)) && [ ! -e \(q) ] && [ ! -L \(q) ] || echo \(shQuote("failed: " + p))")
    }
    for id in receipts where id.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil {
        add("pkgutil --forget \(id) >/dev/null || echo 'failed: receipt \(id)'")
    }
    for c in certs where c.sha1.range(of: "^[0-9A-F]{40}$", options: .regularExpression) != nil
        && c.pem.range(of: #"^-----BEGIN CERTIFICATE-----\n[A-Za-z0-9+/=\n]+-----END CERTIFICATE-----\n$"#, options: .regularExpression) != nil {
        // Trust settings live apart from the keychain item, so drop both.
        add("security remove-trusted-cert -d <\(c.label) PEM>; security delete-certificate -Z \(c.sha1) /Library/Keychains/System.keychain",
            "t=$(mktemp) && cat > \"$t\" <<'PEM'\n\(c.pem)PEM\nsecurity remove-trusted-cert -d \"$t\" 2>/dev/null; rm -f \"$t\"\n"
            + "security delete-certificate -Z \(c.sha1) /Library/Keychains/System.keychain >/dev/null || echo 'failed: certificate \(c.sha1)'")
    }
    for dir in sharedVendorDirs where allowed.contains(where: { $0.path.hasPrefix(dir + "/") }) {
        add("rmdir \(shQuote(dir)) 2>/dev/null")
    }
    return plan
}

/// Runs the plan behind the macOS administrator prompt. Returns a message for the user.
func runPrivileged(_ plan: PrivilegedPlan) -> String {
    let script = plan.steps.map(\.script).joined(separator: "\n")
    let literal = script.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    var error: NSDictionary?
    let result = NSAppleScript(source: "do shell script \"\(literal)\" with administrator privileges without altering line endings")?
        .executeAndReturnError(&error)
    if let error {
        return error[NSAppleScript.errorNumber] as? Int == -128 ? "Cancelled." : "Failed: \(error[NSAppleScript.errorMessage] ?? error)"
    }
    let failed = (result?.stringValue ?? "").split(separator: "\n")
    return failed.isEmpty ? "Done as administrator. Items are in the Trash (emptying it may ask for the password again)."
        : failed.joined(separator: "\n")
}
