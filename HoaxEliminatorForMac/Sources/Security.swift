import Foundation
import Security

// "구라제거기 for Mac": Korean banking/government security agents.
// Catalog started from hoax-eliminator-mac, then corrected from the vendors' macOS installer payloads (see ../ANALYSIS.md).
//
// hoax-eliminator-mac — MIT License, Copyright (c) 2026 John Seong
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright
// notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

struct SecurityProduct: Identifiable {
    let id: String
    let name: String
    let vendor: String
    var paths: [String] = []     // "~" = home; globs allowed in the last component only. Shared vendor parents are never listed.
    var launchd: [String] = []   // plist name globs in /Library/LaunchDaemons, /Library/LaunchAgents, ~/Library/LaunchAgents
    var receipts: [String] = []  // pkgutil package id prefixes
    var certs: [String] = []     // root CA names the installer trusts; matches a System keychain cert's name or issuer
}

let securityCatalog: [SecurityProduct] = [
    .init(id: "astx", name: "AhnLab Safe Transaction (ASTx)", vendor: "AhnLab",
          paths: ["/Applications/AhnLab/ASTx", "/Library/Application Support/AhnLab/ASTx", "~/Library/Application Support/AhnLab/ASTx",
                  "~/Library/Preferences/com.ahnlab.safetransaction*", "~/Library/Preferences/com.astx.*", "/tmp/ahnlab"],
          launchd: ["com.ahnlab.astx*"], receipts: ["com.ahnlab.astx"], certs: ["ASTxRoot2"]),
    // The installer copies its parts to /Library first and never deletes those copies.
    .init(id: "nxkey", name: "TouchEn nxKey", vendor: "RaonSecure",
          paths: ["/Applications/TouchEn nxKey", "/Library/Application Support/raonsecure/TouchEn nxKey", "/Library/Extensions/TKVHD.kext",
                  "/Library/TEK_Daemon", "/Library/TEK_Daemon2", "/Library/TEK_Daemon3", "/Library/TEK_UserAgent.app", "/Library/TKVHD.kext",
                  "/Library/TKUKMD.kext", "/Library/com.raon.touchen.UserAgent.plist", "/Library/Application Support/iniLINE/CrossEX/touchenex/nxkey.json",
                  "~/Library/Preferences/com.raon.touchen.nxkey*", "~/Library/Preferences/com.raon.touchen.UserAgent*"],
          // Globs are case-insensitive: a bare "com.raon.touchen*" would also take nxWeb's com.raon.TouchEN_TEWeb_Agent.
          launchd: ["com.raon.touchen.nxkey*", "com.raon.agent.touchen.nxkey*", "com.raon.touchen.UserAgent*"],
          receipts: ["com.raonsecure.pkg.nxkey", "com.raon.touchen.nxkey"]),
    .init(id: "crosswebex", name: "INISAFE CrossWeb EX", vendor: "INITECH",
          paths: ["/Applications/CrossWebEX", "/Library/Application Support/iniLINE/CrossEX/crosswebex", "/Library/Application Support/iniLINE/CrossWebEX",
                  "/Library/Frameworks/CrossWebEXFramework.framework", "/Library/Internet Plug-Ins/npCrossWebEXPlugin.plugin",
                  "/Library/Internet Plug-Ins/npinilinecrosswebex.plugin", "/Library/Google/Chrome/NativeMessagingHosts/kr.co.iniline.crosswebex.json",
                  "/Library/Application Support/Mozilla/NativeMessagingHosts/kr.co.iniline.crosswebex.firefox.json",
                  "~/Library/Preferences/initech.*", "~/Library/Preferences/com.initech.*", "/tmp/crosswebextmp",
                  // the older NPAPI CrossWeb plug-in, packaged by iniLINE
                  "/Applications/CrossWeb", "/Library/Application Support/iniLINE/CrossWeb", "/Library/Frameworks/CrossWebFramework.framework",
                  "/Library/Internet Plug-Ins/npCrossWebPlugin.plugin"],
          launchd: ["com.initech.*"], receipts: ["kr.co.initech.", "kr.co.iniline.pkg.CrossWebPackage"], certs: ["Initech Root Authority"]),
    // The shared bridge that nxKey, KSCertRelay and nxFirewall install (touchenex, receipt kr.co.iniline.pkg.CrossEXPackage).
    .init(id: "crossex", name: "iniLINE CrossEX (공용 모듈)", vendor: "iniLINE",
          paths: ["/Applications/CrossEX/crossex", "/Applications/CrossWarpEX", "/Library/Application Support/iniLINE/CrossEX/crossex",
                  "/Applications/CrossEX/touchenex", "/Library/Application Support/iniLINE/CrossEX/touchenex", "/Library/Internet Plug-Ins/npraontouchenex.plugin",
                  "/Library/Google/Chrome/NativeMessagingHosts/kr.co.raon.touchenex.json",
                  "/Library/Application Support/Mozilla/NativeMessagingHosts/kr.co.raon.touchenex.firefox.json",
                  "/Library/raon_touchenex_Install.pkg", "/Library/CrossEXService_Install.pkg",
                  "~/Library/Preferences/com.iniline.*", "~/Library/Preferences/kr.co.iniline.*"],
          launchd: ["com.iniline.*", "kr.co.iniline.*"], receipts: ["kr.co.iniline.pkg.CrossEX", "kr.co.iniline.crossex", "com.iniline."], certs: ["iniLINE CrossEX"]),
    .init(id: "veraport", name: "Veraport", vendor: "Wizvera",
          paths: ["/Applications/Veraport", "/Library/Application Support/wizvera/veraport", "/Library/Internet Plug-Ins/Veraport.plugin",
                  "~/Library/Preferences/com.wizvera.veraport*"],
          launchd: ["com.wizvera.veraport*"], receipts: ["com.wizvera.vp", "com.wizvera.veraport"], certs: ["VERAPORT"]),
    .init(id: "delfino", name: "Delfino", vendor: "Wizvera",
          paths: ["/Applications/Delfino", "/Library/Application Support/wizvera/delfino", "~/Library/Preferences/com.wizvera.delfino*"],
          launchd: ["com.wizvera.delfino*"], receipts: ["com.wizvera.delfino"], certs: ["DELFINO"]),
    .init(id: "keysharp", name: "KeySharp Biz / NX Biz", vendor: "RaonSecure",
          paths: ["/Library/Internet Plug-Ins/keysharpbiz.plugin", "/Applications/keysharpbiz", "/Applications/keysharpnxbiz"],
          launchd: ["com.wizvera.keysharpbiz*"], receipts: ["com.wizvera.keysharpbiz"]),
    .init(id: "ipinside", name: "IPinside LWS Agent", vendor: "Interezen",
          paths: ["/Applications/IPinside.app", "~/Library/Preferences/com.interezen.*",
                  // the older NPAPI agent
                  "/Applications/IPinside", "/Library/Internet Plug-Ins/NPI3GManager.plugin"],
          launchd: ["com.interezen.*", "com.nwsdeamond.*"], receipts: ["com.interezen.", "I3GManager.Plugin.ipinsideAgent"], certs: ["INTEREZEN CA"]),
    .init(id: "anysign", name: "AnySign4PC", vendor: "SoftForum (Hancom Secure)",
          paths: ["/Applications/SoftForum", "/Library/Application Support/SoftForum", "~/Library/Application Support/SoftForum", "~/Library/Preferences/com.softforum.*"],
          launchd: ["com.softforum.*"], receipts: ["com.softforum.anysign"], certs: ["Hancom Secure Root"]),
    // V1 and the older Netizen / Online Security v6.0 (NPAPI plug-in).
    .init(id: "nprotect", name: "nProtect Online Security", vendor: "INCA Internet",
          paths: ["/Applications/nProtect", "/Library/Application Support/nProtect", "/Library/Application Support/INCA*",
                  "/Library/PrivilegedHelperTools/com.nprotect.*", "/tmp/nProtect", "~/Library/Caches/com.nprotect.*", "~/Library/Caches/*.com.nprotect.*",
                  "~/Library/Preferences/com.nprotect.*", "~/Library/Preferences/com.inca.*",
                  "/Library/Internet Plug-Ins/nosstt60.plugin", "/Library/Internet Plug-Ins/nProtectNetizenNPI.bundle"],
          launchd: ["com.nprotect.*", "com.inca.*"], receipts: ["com.nprotect.nprotectOnlineSecurity"], certs: ["INCA Internet"]),
    .init(id: "magicline", name: "MagicLine4NX", vendor: "DreamSecurity",
          paths: ["/Applications/MagicLine4NX", "/Applications/NTSMagicLineNP.app", "/Applications/NTSMagicLineNP", "/Applications/DreamSecurity",
                  "/Library/Application Support/DreamSecurity", "/Library/Application Support/MagicLine*",
                  "~/Library/Preferences/com.dreamsecurity.MagicLine*", "~/Library/Preferences/com.dreamsecurity.NTSMagicLine*"],
          launchd: ["com.dreamsecurity.MagicLine*", "com.dreamsecurity.NTSMagicLine*"],
          receipts: ["com.dreamsecurity.MagicLine", "com.dreamsecurity.NTSMagicLine"], certs: ["Dreamsecurity ROOT CA"]),
    .init(id: "markany", name: "MarkAny MaSafeViewer / ePageSafer", vendor: "MarkAny",
          paths: ["/Applications/MaSafeViewer.app", "/Applications/MDMBroker.app", "/Applications/MarkAnyEPS", "/Applications/ePageSafer*", "/Library/markanyTemp",
                  "/Library/Application Support/MarkAny*", "~/Library/Preferences/com.markany.*",
                  // MaSafeBrowser, the older NPAPI screen-capture blocker
                  "/Library/markany", "/Library/Internet Plug-Ins/npMaSafeBrowser*.plugin"],
          launchd: ["com.markany.*"], receipts: ["com.markany."]),
    .init(id: "secukit", name: "SecuKit NXS", vendor: "KICA",
          paths: ["/Applications/kica/secukitnx.app", "/Applications/kica/Uninstaller.app", "~/Library/Preferences/com.kica.*"],
          launchd: ["com.kica.secukitnx*"], receipts: ["com.kica.secukitnx"], certs: ["KICA NXS Root CA"]),
    .init(id: "ksign", name: "KSign CASE Agent", vendor: "KSign",
          paths: ["/Applications/KCaseAgentForMac.app", "/Applications/KSign*", "/Library/Application Support/KSign*", "~/Library/Logs/KCaseAgentForMac",
                  "~/Library/Preferences/com.ksign.*"],
          launchd: ["com.ksign.*"], receipts: ["com.ksign."]),
    .init(id: "vestcert", name: "VestCert", vendor: "Yettiesoft",
          paths: ["/Applications/VestCert.app", "/Applications/Yettiesoft*", "~/Library/MangoWire", "~/Library/Preferences/com.yettiesoft.*"],
          launchd: ["com.yettiesoft.*"], receipts: ["com.yettiesoft."], certs: ["MangoWire"]),
    .init(id: "xecureweb", name: "XecureWeb", vendor: "SoftForum",
          paths: ["/Applications/XecureWebUnified", "/Applications/XecureWeb", "/Library/Application Support/XecureWeb*",
                  "/Library/Internet Plug-Ins/npXecureMacuxNPPlugin.plugin"],
          launchd: ["com.xecure*"], receipts: ["com.softforum.xecureweb", "com.xecure"]),
    // Not verified: no macOS installer could be found.
    .init(id: "unisign", name: "UniSign", vendor: "CrossCert",
          paths: ["/Applications/UniSign*", "/Library/Application Support/CrossCert*", "~/Library/Preferences/com.crosscert.*"],
          launchd: ["com.crosscert.*"], receipts: ["com.crosscert."]),
    .init(id: "kscertrelay", name: "KSCertRelay nx (인증서 복사)", vendor: "RaonSecure",
          paths: ["/Applications/KSCertRelay", "/Library/KSCertRelay.app", "/Library/KSCertRelayQr.app", "/Library/KSCertRelayMain.dylib",
                  "/Library/nxwirelesscert.json", "/Library/Application Support/raonsecure/nxwirelesscert",
                  "/Library/Application Support/iniLINE/CrossEX/touchenex/nxwirelesscert.json", "~/Library/Preferences/com.raonsecure.KSCertRelay*"],
          receipts: ["com.raonsecure.KSCertRelay"]),
    .init(id: "nxfirewall", name: "TouchEn nxFirewall", vendor: "RaonSecure",
          paths: ["/Applications/raonsecure/TouchEnnxFirewall", "/Library/Extensions/TEFWNet.kext"],
          launchd: ["com.osxkernel.TEFWNet*"], receipts: ["com.mygreatcompany.pkg.TEFWInstaller"]),
    // ponytail: its postinstall also writes an Accessibility grant into the system TCC.db, which SIP keeps out of reach.
    .init(id: "nxweb", name: "TouchEn nxWeb (화면 캡처 방지)", vendor: "RaonSecure",
          paths: ["/Applications/raonsecure/TouchEnnxWeb", "~/Library/Preferences/com.raonsecure.TouchEN*"],
          launchd: ["com.raon.TouchEN_TEWeb*"], receipts: ["com.raonsecure.TouchEN-TEWeb"]),
    .init(id: "raonk", name: "RAON K (대용량 파일 전송)", vendor: "RAONWIZ",
          paths: ["/Applications/raonk", "/Applications/raonk.app"],
          launchd: ["com.raonwiz.raonk*"], receipts: ["com.mygreatcompany.pkg.kuploadrelease"], certs: ["RAON K CA"]),
    // Hometax modules; they share their root CA with MagicLine4NX.
    .init(id: "ntsmagicxml", name: "NTSMagicXMLSecurityNP (홈택스 전자서명)", vendor: "DreamSecurity",
          paths: ["/Applications/NTSMagicXMLSecurityNP.app"],
          launchd: ["com.dreamsecurity.NTSMagicXMLSecurityNP*"], receipts: ["com.dreamsecurity.NTSFileCryptNP.ntsmagicxmlsecuritynp"],
          certs: ["Dreamsecurity ROOT CA"]),
    .init(id: "ntsfilecrypt", name: "NTSFileCryptNP (홈택스 신고파일 암호화)", vendor: "DreamSecurity",
          paths: ["/Applications/NTSFileCryptNP.app"],
          launchd: ["com.dreamsecurity.NTSFileCryptNP*"], receipts: ["com.dreamsecurity.NTSFileCryptNP.ntsfilecryptnp"], certs: ["Dreamsecurity ROOT CA"]),
    // ponytail: its /Applications/Viewer.app (com.designmade.printmade3) is left out, the name is too generic to match by path.
    .init(id: "printmade3", name: "Printmade3 (웹 인쇄)", vendor: "Nagosoft",
          paths: ["/Library/Internet Plug-Ins/Printmade3", "/Library/Internet Plug-Ins/Printmade3NPPlugin.plugin", "/Applications/PTMAphid.app"],
          receipts: ["com.designmade.printmade3ForMac"]),
    .init(id: "certshare", name: "CertShare xFree (인증서 복사)", vendor: "SoftForum (Hancom Secure)",
          paths: ["/Applications/CertShareXFree", "~/Library/Preferences/com.softforum.certshare*"], receipts: ["com.softforum.certsharexfree"]),
    .init(id: "seculog", name: "nProtect SecuLog", vendor: "INCA Internet",
          paths: ["/Applications/nProtect SLM", "/Library/Internet Plug-Ins/npefdsplugin.plugin", "~/INCAInternet"],
          receipts: ["com.nprotect.nprotectEfds"]),
    .init(id: "certconverter", name: "Delfino CertConverter (인증서 변환)", vendor: "Wizvera", paths: ["/Applications/CertConverter.app"]),
    .init(id: "aosfirewall", name: "AhnLab Online Security 방화벽", vendor: "AhnLab",
          paths: ["/Applications/AhnLab/ASP", "/Library/Internet Plug-Ins/npaosmgr.plugin"],
          launchd: ["com.aos.firewall*"], receipts: ["com.ahnlab.firewall"]),
]

struct SecurityHit: Identifiable {
    let product: SecurityProduct
    let files: [URL]
    let receipts: [String]
    let certs: [SystemCert]
    var id: String { product.id }
}

struct SystemCert {
    let label: String   // subject summary, e.g. "VERAPORT-CA" or "127.0.0.1"
    let issuer: String  // issuer common name: catches local certs like "127.0.0.1" signed by VERAPORT-CA
    let sha1: String
    let pem: String
    var shown: String { issuer.isEmpty || issuer == label ? label : "\(label) (by \(issuer))" }
}

// `root` and `home` only exist so the self-check can scan a fake filesystem.
func scanSecurity(root: String = "", home: String = NSHomeDirectory(), receipts: [String] = installedReceipts(),
                  certs: [SystemCert] = systemCerts()) -> [SecurityHit] {
    let launchdDirs = [root + "/Library/LaunchDaemons", root + "/Library/LaunchAgents", home + "/Library/LaunchAgents"]
    return securityCatalog.compactMap { p in
        var files = p.paths.flatMap { expand($0.hasPrefix("~") ? home + $0.dropFirst() : root + $0) }
            + p.launchd.flatMap { glob in launchdDirs.flatMap { expand($0 + "/" + glob + ".plist") } }
        files += appLeftovers(in: files)
        let pkgs = receipts.filter { r in p.receipts.contains { r.hasIPrefix($0) } }
        let roots = certs.filter { c in p.certs.contains { c.label.containsI($0) || c.issuer.containsI($0) } }
        return files.isEmpty && pkgs.isEmpty && roots.isEmpty ? nil : SecurityHit(product: p, files: files, receipts: pkgs, certs: roots)
    }
}

// relatedFiles() applied to each app the product left behind: its preferences, caches, saved state,
// containers and launch jobs. Matched by bundle id only (isSubBundle), so generic names like "Uninstaller.app"
// never pull in other vendors' files.
func appLeftovers(in found: [URL]) -> [URL] {
    let apps = found.flatMap { url in
        url.pathExtension == "app" ? [url]
            : ((try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []).filter { $0.pathExtension == "app" }
    }
    let known = Set(found.map(\.path))
    return apps.compactMap { AppTarget(url: $0, isSubBundle: true) }
        .filter { !($0.bundleID ?? "com.apple.").hasIPrefix("com.apple.") }
        .flatMap { $0.relatedFiles().filter(\.selected).map(\.url) }
        .filter { u in !known.contains(u.path) && !known.contains { u.path.hasPrefix($0 + "/") } }
}

// "Also find hidden ones not in the list": vendor keywords in the usual install folders. Report only, starts unchecked.
let hiddenKeywords = "ahnlab|astx|raon|touchen|nxkey|wizvera|veraport|delfino|initech|inisafe|iniline|crossweb|crossex|crosswarp|interezen|"
    + "ipinside|softforum|anysign|xecure|nprotect|inca\\.|dreamsecurity|magicline|markany|epagesafer|masafe|ksign|crosscert|unisign|"
    + "yettie|vestcert|secukit|sgasol|kica|signgate|moasign|ubikey|hancomwith|securekey|keysharp|nppfs|ezpdf|"
    + "kscertrelay|nxwireless|tefw|ntsmagic|ntsfilecrypt|printmade|ptmaphid|certshare|incainternet|npefds|i3gmanager|certconverter|com\\.aos\\."

func hiddenSuspects(excluding known: [URL], home: String = NSHomeDirectory()) -> [URL] {
    let dirs = ["/Library/LaunchDaemons", "/Library/LaunchAgents", home + "/Library/LaunchAgents", "/Applications",
                "/Library/Application Support", "/Library/Internet Plug-Ins", "/Library/PrivilegedHelperTools"]
    let paths = known.map(\.path)
    return dirs.flatMap { dir in
        ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? [])
            .filter { $0.range(of: hiddenKeywords, options: [.regularExpression, .caseInsensitive]) != nil }
            .map { URL(filePath: dir).appending(path: $0) }
    }
    .filter { u in !paths.contains { u.path == $0 || u.path.hasPrefix($0 + "/") || $0.hasPrefix(u.path + "/") } }
}

// The "설치일" column: the receipt's install time, else when the files were put in place.
// Creation dates are useless here: installers keep the vendor's build date (IPinside shows 2018).
func installDate(of hit: SecurityHit) -> Date? {
    let receipts = hit.receipts.compactMap { id in
        output("/usr/sbin/pkgutil", "--pkg-info", id).split(separator: "\n").first { $0.hasPrefix("install-time: ") }
            .flatMap { TimeInterval($0.dropFirst(14)) }.map { Date(timeIntervalSince1970: $0) }
    }
    return receipts.min() ?? hit.files.compactMap { try? $0.resourceValues(forKeys: [.addedToDirectoryDateKey]).addedToDirectoryDate }.min()
}

// What one press of "제거" will do: files the user can move, and everything else in one administrator run.
struct Cleanup: Identifiable {
    let id = UUID()
    let names: [String]
    var userFiles: [URL] = []
    var plan = PrivilegedPlan()
    var fileCount = 0, jobCount = 0, certCount = 0, receiptCount = 0
}

func makeCleanup(_ hits: [SecurityHit], certs: Bool, receipts: Bool, uid: uid_t = getuid()) -> Cleanup {
    var seen = Set<String>(), certSeen = Set<String>()
    let all = hits.flatMap(\.files).filter { !isSIPRestricted($0) && seen.insert($0.path).inserted }
    // Several products trust the same root CA (MagicLine4NX and the Hometax modules): delete it once.
    let rootCerts = certs ? hits.flatMap(\.certs).filter { certSeen.insert($0.sha1).inserted } : []
    let top = all.filter { u in !seen.contains { u.path.hasPrefix($0 + "/") } }  // nxKey sits inside CrossEX's folder
    let root = top.filter { needsAdmin($0, uid: uid) }
    var c = Cleanup(names: hits.map(\.product.name), userFiles: top.filter { !needsAdmin($0, uid: uid) })
    c.plan = privilegedPlan(files: root, receipts: receipts ? hits.flatMap(\.receipts) : [], certs: rootCerts, uid: uid)
    c.fileCount = c.userFiles.count + root.count - c.plan.skipped.count
    c.jobCount = top.filter { $0.path.contains("/LaunchDaemons/") || $0.path.contains("/LaunchAgents/") }.count
    c.certCount = rootCerts.count
    c.receiptCount = receipts ? hits.flatMap(\.receipts).count : 0
    return c
}

// Owned by someone else, or sitting in a folder the user cannot write to.
func needsAdmin(_ url: URL, uid: uid_t = getuid()) -> Bool {
    var s = stat()
    guard lstat(url.path, &s) == 0 else { return false }
    return s.st_uid != uid || access(url.deletingLastPathComponent().path, W_OK) != 0
}

// Existing paths for one pattern. Dangling symlinks count (a launchd plist often links into a deleted app).
func expand(_ path: String) -> [URL] {
    let url = URL(filePath: path), name = url.lastPathComponent, dir = url.deletingLastPathComponent().path
    let exists = { (p: String) in (try? FileManager.default.attributesOfItem(atPath: p)) != nil }
    guard name.contains(where: { "*?[".contains($0) }) else { return exists(path) ? [url] : [] }
    return ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? [])
        .filter { fnmatch(name, $0, FNM_CASEFOLD) == 0 }.sorted().map { URL(filePath: dir).appending(path: $0) }
}

func installedReceipts() -> [String] { output("/usr/sbin/pkgutil", "--pkgs").split(separator: "\n").map(String.init) }

// Every certificate in the System keychain (read-only, no admin needed).
func systemCerts() -> [SystemCert] {
    var certs: [SystemCert] = [], sha1 = "", pem = ""
    for line in output("/usr/bin/security", "find-certificate", "-a", "-Z", "-p", "/Library/Keychains/System.keychain").split(separator: "\n") {
        if line.hasPrefix("SHA-1 hash: ") { sha1 = String(line.dropFirst(12)) }
        if line.hasPrefix("-----BEGIN") { pem = "" }
        pem += line + "\n"
        guard line.hasPrefix("-----END"), let cert = certificate(fromPEM: pem) else { continue }
        certs.append(SystemCert(label: SecCertificateCopySubjectSummary(cert) as String? ?? "", issuer: issuerName(cert), sha1: sha1, pem: pem))
    }
    return certs
}

func certificate(fromPEM pem: String) -> SecCertificate? {
    let body = pem.split(separator: "\n").filter { !$0.hasPrefix("-----") }.joined()
    return Data(base64Encoded: body).flatMap { SecCertificateCreateWithData(nil, $0 as CFData) }
}

func issuerName(_ cert: SecCertificate) -> String {
    let key = kSecOIDX509V1IssuerName as String
    let values = SecCertificateCopyValues(cert, [key] as CFArray, nil) as? [String: [String: Any]]
    let parts = values?[key]?[kSecPropertyKeyValue as String] as? [[String: Any]] ?? []
    return parts.first { $0[kSecPropertyKeyLabel as String] as? String == kSecOIDCommonName as String }?[kSecPropertyKeyValue as String] as? String ?? ""
}

func output(_ tool: String, _ args: String...) -> String {
    let p = Process(), pipe = Pipe()
    p.executableURL = URL(filePath: tool)
    p.arguments = args
    p.standardOutput = pipe
    guard (try? p.run()) != nil else { return "" }
    let out = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return String(decoding: out, as: UTF8.self)
}
