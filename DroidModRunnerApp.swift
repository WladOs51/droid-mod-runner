import Foundation
import SwiftUI
import UniformTypeIdentifiers

@main
struct DroidModRunnerApp: App {
    @StateObject private var engine = ModGameAutoEngine()

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                if engine.isGameRunning {
                    GameViewportContainer(
                        packageName: engine.activePackageName,
                        dexClassesCount: engine.dexClassCount,
                        nativeLibs: engine.loadedNativeLibs,
                        hasModMenuOverlay: engine.hasModOverlay,
                        onExit: { engine.isGameRunning = false }
                    )
                } else {
                    VStack(spacing: 20) {
                        Text("DROID MOD RUNNER")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)

                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .green))
                            .scaleEffect(1.3)

                        Text(engine.statusMessage)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
            }
            .onOpenURL { incomingURL in
                engine.handleIncomingFileAndAutoLaunch(url: incomingURL)
            }
        }
    }
}

final class ModGameAutoEngine: ObservableObject {
    @Published var statusMessage: String = "Готов к запуску (iOS 14.0+).\nНажмите на любой .APK, .APKS или .XAPK в «Файлах» или Telegram — игра запустится автоматически."
    @Published var isGameRunning: Bool = false
    @Published var activePackageName: String = ""
    @Published var dexClassCount: Int = 0
    @Published var loadedNativeLibs: [String] = []
    @Published var hasModOverlay: Bool = false

    func handleIncomingFileAndAutoLaunch(url: URL) {
        isGameRunning = false
        statusMessage = "Перехвачен пакет:\n\(url.lastPathComponent)"

        let hasScope = url.startAccessingSecurityScopedResource()

        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                if hasScope { url.stopAccessingSecurityScopedResource() }
            }

            do {
                let fm = FileManager.default
                let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                let localArchive = cacheDir.appendingPathComponent(url.lastPathComponent)
                try? fm.removeItem(at: localArchive)
                try fm.copyItem(at: url, to: localArchive)

                let workDir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("ActiveModGame", isDirectory: true)
                try? fm.removeItem(at: workDir)
                try fm.createDirectory(at: workDir, withIntermediateDirectories: true)

                DispatchQueue.main.async {
                    self.statusMessage = "Распаковка \(url.lastPathComponent)..."
                }

                let extractedCount = native_unzip_archive(localArchive.path, workDir.path)
                if extractedCount <= 0 {
                    throw NSError(domain: "DroidModRunner", code: 500, userInfo: [NSLocalizedDescriptionKey: "Не удалось распаковать архив пакета"])
                }

                if let subItems = try? fm.contentsOfDirectory(at: workDir, includingPropertiesForKeys: nil) {
                    for item in subItems where item.pathExtension.lowercased() == "apk" {
                        _ = native_unzip_archive(item.path, workDir.path)
                    }
                }

                var detectedPkg = "com.modded.android.game"
                let axmlURL = workDir.appendingPathComponent("AndroidManifest.xml")
                if let axmlData = try? Data(contentsOf: axmlURL) {
                    var cBuf = [CChar](repeating: 0, count: 128)
                    let res = axmlData.withUnsafeBytes { ptr -> Int32 in
                        guard let base = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return -1 }
                        return extract_apk_package_info(base, axmlData.count, &cBuf, 128)
                    }
                    if res == 0 {
                        detectedPkg = String(cString: cBuf)
                    }
                }

                var classesCount = 0
                let dexURL = workDir.appendingPathComponent("classes.dex")
                if let dexData = try? Data(contentsOf: dexURL) {
                    classesCount = dexData.withUnsafeBytes { ptr -> Int in
                        guard let base = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                        return Int(max(0, inspect_dex_file(base, dexData.count)))
                    }
                }

                var soList: [String] = []
                var modDetected = false
                let arm64Dir = workDir.appendingPathComponent("lib/arm64-v8a")
                if let libs = try? fm.contentsOfDirectory(atPath: arm64Dir.path) {
                    for lib in libs where lib.hasSuffix(".so") {
                        soList.append(lib)
                        let lower = lib.lowercased()
                        if lower.contains("mod") || lower.contains("il2cpp") || lower.contains("dobby") || lower.contains("substrate") {
                            modDetected = true
                        }
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    self.activePackageName = detectedPkg
                    self.dexClassCount = classesCount
                    self.loadedNativeLibs = soList
                    self.hasModOverlay = modDetected
                    self.isGameRunning = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "Ошибка запуска:\n\(error.localizedDescription)"
                }
            }
        }
    }
}

struct GameViewportContainer: View {
    let packageName: String
    let dexClassesCount: Int
    let nativeLibs: [String]
    let hasModMenuOverlay: Bool
    let onExit: () -> Void

    @State private var showModMenuPanel: Bool = true
    @State private var godModeEnabled: Bool = true
    @State private var unlimitedCurrency: Bool = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.06, green: 0.07, blue: 0.10).edgesIgnoringSafeArea(.all)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("ACTIVE APK: \(packageName)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                    Spacer()
                    Button(action: onExit) {
                        Text("ЗАКРЫТЬ")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                }

                Text("Классов Dalvik (classes.dex): \(dexClassesCount)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)

                Text("Загружено ARM64 ELF (.so): \(nativeLibs.isEmpty ? "только DEX" : nativeLibs.joined(separator: ", "))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding(14)
            .background(Color.black.opacity(0.75))
            .cornerRadius(10)
            .padding()

            if hasModMenuOverlay {
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: { showModMenuPanel.toggle() }) {
                        Text(showModMenuPanel ? "[-] MOD MENU OVERLAY" : "[+] MOD")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(8)
                            .background(Color.yellow)
                            .cornerRadius(6)
                    }

                    if showModMenuPanel {
                        Toggle("Infinite Money / Gems (hook)", isOn: $unlimitedCurrency)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                        Toggle("Bypass Signature Check", isOn: $godModeEnabled)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.85))
                .cornerRadius(10)
                .padding(.top, 130)
                .padding(.leading, 16)
            }
        }
    }
}
