import AppKit
import Security
import UniformTypeIdentifiers

// Related-file search: everything an app leaves in the Library folders, installer receipts and /Users/Shared.

struct Roots {
    var libraries: [URL]  // ~/Library, /Library (user + local domain)
    var receipts = URL(filePath: "/private/var/db/receipts")
    var shared = URL(filePath: "/Users/Shared")
    static let system = Roots(libraries: FileManager.default.urls(for: .libraryDirectory, in: [.userDomainMask, .localDomainMask]))

    func lib(_ components: String...) -> [URL] { libraries.map { components.reduce($0) { $0.appending(path: $1) } } }

    // Standard Library folders are never offered for removal.
    var protected: Set<String> { Set(libraries.flatMap { lib in protectedLibraryFolders.map { lib.appending(path: $0).resolvingSymlinksInPath().path } }) }
}

let protectedLibraryFolders = [
    "Accounts", "Application Support", "Audio", "Autosave Information", "Caches", "Caches/Metadata", "ColorPickers", "Colors",
    "ColorSync", "Components", "Compositions", "Containers", "Contextual Menu Items", "Cookies", "CoreMediaIO", "Desktop Pictures",
    "Developer", "Dictionaries", "DirectoryServices", "Extensions", "Favorites", "Filesystems", "FontCollections", "Fonts",
    "Frameworks", "Graphics", "Group Containers", "IdentityServices", "Image Capture", "Input Methods", "Internet Plug-Ins",
    "Keyboard Layouts", "Keychains", "LanguageModeling", "LaunchAgents", "LaunchDaemons", "Logs", "MobileDevice", "Modem Scripts",
    "OpenDirectory", "PDF Services", "PreferencePanes", "Preferences", "Printers", "PrivilegedHelperTools", "PubSub", "QuickLook",
    "QuickTime", "Receipts", "Recent Documents", "Sandbox", "Saved Application State", "ScriptingAdditions", "Scripts", "Security",
    "Services", "Sounds", "Speech", "Spelling", "Spotlight", "StartupItems", "SyncedPreferences", "Video", "Voices", "WebKit", "Widgets",
]

// Nested bundle types that count as part of the app.
let pluginExtensions: Set = ["framework", "plugin", "webplugin", "bundle", "appex", "mdimporter", "dext", "qlgenerator", "xpc",
                             "driver", "prefpane", "mailbundle", "component", "service"]

struct Found {
    let url: URL
    var selected = true
    var selectable: Bool { !isSIPRestricted(url) }
}

struct AppTarget {
    let url: URL
    var bundleID: String?
    var name: String
    var displayName: String?
    var executable: String
    var groups: [String] = []
    var privilegedExecutables: [String] = []
    var isApp = true  // false for plug-ins, prefpanes and other non-app bundles
    var isSubBundle = false
    var alias: URL?
}

extension AppTarget {
    init?(url original: URL, isSubBundle: Bool = false) {
        let url = original.resolvingSymlinksInPath()
        guard let info = Bundle(url: url)?.infoDictionary ?? CFBundleCopyInfoDictionaryForURL(url as CFURL) as? [String: Any] else { return nil }
        var name = (info["CFBundleName"] as? String)?.normalized ?? ""
        if name.isBlank {
            name = url.deletingPathExtension().lastPathComponent.normalized
            if let date = name.range(of: #"(?<=.) \d{2}.\d{2}.\d{2}$"#, options: .regularExpression) { name.removeSubrange(date) }
        }
        let display = (info["CFBundleDisplayName"] as? String)?.normalized
        self.init(url: url,
                  bundleID: (info["CFBundleIdentifier"] as? String).flatMap { $0.isBlank ? nil : Self.normalizeBundleID($0) },
                  name: name,
                  displayName: display.flatMap { $0.equalsI(name) ? nil : $0 },
                  executable: info["CFBundleExecutable"] as? String ?? url.lastPathComponent,
                  groups: Self.appGroups(of: url),
                  privilegedExecutables: Array((info["SMPrivilegedExecutables"] as? [String: Any] ?? [:]).keys),
                  isApp: url.conforms(to: .applicationBundle),
                  isSubBundle: isSubBundle,
                  alias: original.standardizedFileURL.path == url.path ? nil : original)
    }

    // "com.foo.Bar.app2" -> "com.foo.Bar"
    static func normalizeBundleID(_ id: String) -> String {
        guard id.count >= 8,
              let r = id.range(of: #"\.(app|application|demo|trial)?[0-9-_ab]*$"#, options: [.regularExpression, .caseInsensitive]),
              !r.isEmpty, id.distance(from: id.startIndex, to: r.lowerBound) >= 5 else { return id }
        return String(id[..<r.lowerBound])
    }

    // Reads com.apple.security.application-groups from the code signature.
    static func appGroups(of url: URL) -> [String] {
        var code: SecStaticCode?
        var info: CFDictionary?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
              SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let ents = (info as? [String: Any])?[kSecCodeInfoEntitlementsDict as String] as? [String: Any]
        else { return [] }
        let groups = ents["com.apple.security.application-groups"]
        return groups as? [String] ?? (groups as? String).map { [$0] } ?? []
    }

    // System apps and running apps can't be removed.
    var refusal: String? {
        if url.path.hasPrefix("/System/Applications/") { return "System apps can't be removed." }
        if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleURL?.path == url.path }) { return "\(name) is running. Quit it first." }
        return nil
    }

    var names: [String] {
        [name, name.noWS, name.strippingTrailingDigits, displayName, displayName?.noWS].compactMap { $0 }.filter { !$0.isEmpty }
    }

    // Default name test: bundle id first, then the app's names.
    func defaultMatch(_ file: String) -> Bool {
        if let id = bundleID {
            if id.count >= 8 && file.containsI(id) { return true }
            if id.count >= 4 && file.hasIPrefix(id) { return true }
        }
        if isSubBundle { return false }
        return names.contains { n in
            n.count <= 3 ? file.equalsI(n) || file.stem.equalsI(n)
                : file.range(of: "^\(NSRegularExpression.escapedPattern(for: n))(?:[.\\-_\\s\\d]+.*)?$", options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    func relatedFiles(in r: Roots = .system) -> [Found] {
        var found: [Found] = []
        var seen = Set<String>()
        func add(_ urls: [URL], selected: Bool = true) {
            for u in urls where seen.insert(u.path).inserted { found.append(Found(url: u, selected: selected)) }
        }
        let id = bundleID ?? ""

        if isApp && !isSubBundle {
            let (nested, workflows) = parseBundle()
            add(related(r.lib("Services")) { workflows.contains($0.lowercased()) })
            add(related(r.lib("Services"), match: defaultMatch))
            for b in nested { for f in b.relatedFiles(in: r) { add([f.url], selected: f.selected) } }
        }
        // ponytail: Dashboard widgets skipped, they are gone since macOS 10.15.

        // Preferences
        add(related(r.lib("Preferences")) { f in
            if f.hasIPrefix("widget-") { return false }
            if !id.isEmpty && id != "net.sourceforge" && (id.count <= 3 ? f.equalsI(id + ".plist") : f.hasIPrefix(id)) { return true }
            guard isApp && !isSubBundle else { return false }
            let nw = name.noWS
            if nw.count >= 4 && (f.hasIPrefix(name) || f.hasIPrefix(nw)) { return true }
            return nw.count >= 8 && (f.containsI(name) || f.containsI(nw))
        })
        if id.count >= 4 && id != "net.sourceforge" {
            add(related(r.lib("Preferences", "ByHost") + r.lib("SyncedPreferences")) { $0.hasIPrefix(id) })
        }

        // Library, Application Support and other per-app folders
        if !isSubBundle {
            var dirs = r.libraries + r.lib("Application Support")
            if !url.pathExtension.equalsI("prefPane") { dirs += r.lib("PreferencePanes") }
            add(related(dirs + r.lib("Services") + r.lib("Safari", "Extensions") + [r.shared], match: defaultMatch))
            if id.count >= 8 {
                add(related(r.lib("Cookies") + r.lib("HTTPStorages") + r.lib("WebKit")
                            + r.lib("Application Support", "com.apple.sharedfilelist", "com.apple.LSSharedFileList.ApplicationRecentDocuments")) { $0.hasIPrefix(id) })
            }
        }

        // Containers: shared group containers start unchecked
        if !id.isEmpty {
            add(related(r.lib("Containers") + r.lib("Application Scripts")) { $0.equalsI(id) })
            add(related(r.lib("Group Containers")) { $0.equalsI(id) || groups.contains($0) }, selected: false)
        }

        // Caches
        if isApp {
            add(related(r.lib("Caches") + r.lib("Caches", "Metadata") + r.lib("Caches", "com.apple.Safari", "Extensions"), match: defaultMatch))
            if id.count >= 4 && !isSubBundle {
                add(related(r.lib("Caches", "com.apple.helpd", "Generated")) { $0.stem.hasIPrefix(id) })
                add(related(r.lib("Caches", "com.apple.helpd", "SDMHelpData"), maxDepth: 4) { $0.stem.hasIPrefix(id) })
            }
        }

        // Saved state
        if !id.isEmpty {
            add(related(r.lib("Saved Application State")) { $0.hasIPrefix(id) || (name.count >= 8 && $0.hasIPrefix(name)) })
        }

        // Installer receipts
        if isApp && id.count > 3 { add(related([r.receipts]) { $0.hasIPrefix(id) }) }

        // Launch agents, daemons and privileged helpers
        let jobs = r.lib("LaunchAgents") + r.lib("LaunchDaemons"), helpers = r.lib("PrivilegedHelperTools")
        if id.count >= 8 { add(related(jobs) { $0.hasIPrefix(id) }) }
        for key in privilegedExecutables {
            add(related(jobs) { $0.equalsI(key + ".plist") })
            add(related(helpers) { $0.equalsI(key) })
        }
        if id.count >= 8 { add(related(helpers) { $0.hasIPrefix(id) }) }

        // Logs
        add(related(r.lib("Application Support", "CrashReporter") + r.lib("Logs", "DiagnosticReports")) { $0.hasIPrefix(executable + "_") })
        add(related(r.lib("Logs"), maxDepth: 3, match: defaultMatch))

        found.sort { $0.url.path < $1.url.path }
        // ponytail: the parent folder starts unchecked. Its name test is a loose contains, so
        // "Desk.app" sitting in ~/Desktop would otherwise put the whole Desktop in the Trash.
        if isApp, let parent = parentFolder { found.insert(Found(url: parent, selected: false), at: 0) }
        if let alias { found.insert(Found(url: alias), at: 0) }

        let protected = r.protected
        return found.filter { !protected.contains($0.url.resolvingSymlinksInPath().path) }
    }

    // A vendor folder like /Applications/Foo/ that holds Foo.app.
    var parentFolder: URL? {
        guard !isSubBundle else { return nil }
        let parent = url.deletingLastPathComponent()
        // ponytail: never offer a volume root, which also covers apps run from a mounted disk image.
        if (try? parent.resourceValues(forKeys: [.isVolumeKey]))?.isVolume == true { return nil }
        let p = parent.lastPathComponent.noWS, s = url.deletingPathExtension().lastPathComponent.noWS
        if p.equalsI("Applications") { return nil }
        // "<name>[0-9BETAbeta.-]*" without anchors is the same as a plain contains.
        if s.count <= 3 ? p.equalsI(s) : p.containsI(s) { return parent }
        return url.path.hasPrefix("/opt/homebrew-cask") ? parent : nil
    }

    // Helpers/XPC/extensions inside the app, and Services workflows.
    func parseBundle() -> (nested: [AppTarget], workflows: Set<String>) {
        var nested: [AppTarget] = [], workflows = Set<String>()
        guard let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.contentTypeKey]) else { return ([], []) }
        while let u = e.nextObject() as? URL {
            if e.level >= 7 { e.skipDescendants() }
            if u.conforms(to: .framework) { continue }
            let ext = u.pathExtension.lowercased()
            if ext == "workflow" { workflows.insert(u.lastPathComponent.lowercased()); continue }
            let executable = u.conforms(to: .executable)
            guard u.conforms(to: .bundle) || executable, ext != "dylib",
                  u.conforms(to: .applicationBundle) || executable || pluginExtensions.contains(ext),
                  let b = AppTarget(url: u, isSubBundle: true), let bid = b.bundleID, !bid.hasIPrefix("org.sparkle-project")
            else { continue }
            nested.append(b)
        }
        return (nested, workflows)
    }
}

// maxDepth 0 = top level only.
func related(_ dirs: [URL], maxDepth: Int = 0, match: (String) -> Bool) -> [URL] {
    dirs.flatMap { dir -> [URL] in
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.isDirectoryKey],
                                                     options: maxDepth == 0 ? .skipsSubdirectoryDescendants : []) else { return [] }
        var out: [URL] = []
        while let u = e.nextObject() as? URL {
            if maxDepth > 0 && e.level >= maxDepth { e.skipDescendants(); continue }
            guard match(u.lastPathComponent.normalized) else { continue }
            out.append(u)
            if (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true { e.skipDescendants() }
        }
        return out
    }
}

// SF_RESTRICTED (0x80000) marks SIP-protected files.
func isSIPRestricted(_ url: URL) -> Bool {
    var s = stat()
    return stat(url.path, &s) == 0 && s.st_flags & 0x80000 != 0
}

func diskSize(of url: URL) -> Int64 {
    let key: Set<URLResourceKey> = [.totalFileAllocatedSizeKey]
    func size(_ u: URL) -> Int64 { Int64((try? u.resourceValues(forKeys: key))?.totalFileAllocatedSize ?? 0) }
    let children = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(key))?.compactMap { $0 as? URL } ?? []
    return children.reduce(size(url)) { $0 + size($1) }
}

// Unload user launch agents, clear the uchg flag, move to Trash.
// Returns where each item landed in the Trash, and every item that could not be moved with the reason.
// Root-owned failures are retried as administrator through privilegedPlan/runPrivileged (Privileged.swift).
func trash(_ urls: [URL]) -> (moved: [URL], failed: [(url: URL, reason: String)]) {
    let agents = NSHomeDirectory() + "/Library/LaunchAgents/"
    var moved: [URL] = []
    let failed: [(url: URL, reason: String)] = urls.compactMap { url in
        if url.path.hasPrefix(agents) {
            let p = Process()
            p.executableURL = URL(filePath: "/bin/launchctl")
            p.arguments = ["unload", url.path]
            p.standardError = FileHandle.nullDevice  // "Unload failed" just means the job wasn't loaded
            try? p.run()
            p.waitUntilExit()
        }
        var s = stat()
        if stat(url.path, &s) == 0, s.st_flags & UInt32(UF_IMMUTABLE) != 0 { chflags(url.path, s.st_flags & ~UInt32(UF_IMMUTABLE)) }
        var landed: NSURL?
        do { try FileManager.default.trashItem(at: url, resultingItemURL: &landed) } catch { return (url, error.localizedDescription) }
        if let landed { moved.append(landed as URL) }
        return nil
    }
    return (moved, failed)
}

extension URL {
    func conforms(to type: UTType) -> Bool { (try? resourceValues(forKeys: [.contentTypeKey]))?.contentType?.conforms(to: type) == true }
}

extension String {
    var normalized: String { trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
    var noWS: String { replacingOccurrences(of: " ", with: "") }
    var strippingTrailingDigits: String { replacingOccurrences(of: #"\s*\d+$"#, with: "", options: .regularExpression) }
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var stem: String { (self as NSString).deletingPathExtension }
    func hasIPrefix(_ p: String) -> Bool { range(of: p, options: [.caseInsensitive, .anchored, .diacriticInsensitive, .widthInsensitive]) != nil }
    func containsI(_ s: String) -> Bool { range(of: s, options: .caseInsensitive) != nil }
    func equalsI(_ s: String) -> Bool { caseInsensitiveCompare(s) == .orderedSame }
}
