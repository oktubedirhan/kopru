import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmForceQuit = false

    var body: some View {
        @Bindable var model = model
        Group {
            if let problem = model.setupProblem {
                ContentUnavailableView("Kurulum eksik", systemImage: "exclamationmark.triangle",
                                       description: Text(problem))
            } else {
                NavigationSplitView {
                    List(model.games, selection: $model.selection) { game in
                        GameRow(game: game, running: model.status.runningGameIDs.contains(game.id))
                    }
                    .navigationSplitViewColumnWidth(min: 220, ideal: 260)
                    .overlay {
                        if model.games.isEmpty {
                            ContentUnavailableView("Kurulu oyun yok", systemImage: "gamecontroller",
                                                   description: Text("Steam'den bir oyun kurunca burada görünür."))
                        }
                    }
                } detail: {
                    if let game = model.selectedGame {
                        GameDetail(game: game)
                    } else {
                        ContentUnavailableView("Bir oyun seç", systemImage: "gamecontroller")
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .status) {
                Label(model.status.steamRunning ? "Steam açık" : "Steam kapalı", systemImage: "circle.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(model.status.steamRunning ? .green : .secondary)
            }
            ToolbarItem {
                if model.status.steamRunning {
                    Button("Steam'i Kapat", systemImage: "stop.circle") { model.closeSteam() }
                } else {
                    Button("Steam'i Aç", systemImage: "play.circle") { model.openSteam() }
                }
            }
            ToolbarItem {
                Menu("Diğer", systemImage: "ellipsis.circle") {
                    Button("Listeyi Yenile", systemImage: "arrow.clockwise") { model.reload() }
                    Button("Prefix Klasörünü Göster", systemImage: "folder") { model.reveal(model.paths.steamPrefix) }
                    Button("Günlükleri Göster", systemImage: "doc.text") { model.showLogs() }
                    Divider()
                    Button("Zorla Kapat…", systemImage: "xmark.octagon", role: .destructive) { confirmForceQuit = true }
                }
            }
        }
        .confirmationDialog("Steam ve oyunlar zorla kapatılsın mı?", isPresented: $confirmForceQuit) {
            Button("Zorla Kapat", role: .destructive) { model.forceQuit() }
        } message: {
            Text("Prefix'teki bütün Windows süreçleri (wineserver -k) hemen kapanır. Oyundaki kaydedilmemiş ilerleme kaybolur ve Steam Cloud eşitlemesi yapılmaz. Yalnızca bir şey takıldığında kullan.")
        }
        .safeAreaInset(edge: .top) {
            if model.needsSteamRestart {
                HStack {
                    Label("Ayarlar değişti. Oyunlara geçmesi için Steam yeniden başlatılmalı.",
                          systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    Button("Steam'i Yeniden Başlat") { model.restartSteam() }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.15))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let message = model.message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.bar)
            }
        }
    }
}

private struct GameRow: View {
    let game: InstalledGame
    let running: Bool

    var body: some View {
        HStack(spacing: 10) {
            CoverImage(url: game.capsuleImage)
                .frame(width: 36, height: 54)
                .clipShape(.rect(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 2) {
                Text(game.name).lineLimit(2)
                if running {
                    Text("Çalışıyor").font(.caption).foregroundStyle(.green)
                } else if !game.isFullyInstalled {
                    Text("Kuruluyor / kurulu değil").font(.caption).foregroundStyle(.secondary)
                } else if game.needsUpdate {
                    Text("Güncelleme gerekiyor").font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct GameDetail: View {
    @Environment(AppModel.self) private var model
    let game: InstalledGame

    private var running: Bool { model.status.runningGameIDs.contains(game.id) }
    private var launching: Bool { model.launching[game.id] != nil }
    private var profile: GameProfile? { model.profile(for: game) }
    private var mode: GameProfile.LaunchMode { model.launchMode(for: game) }

    /// Bu oyuna gerçekten uygulanacak grafik ayarı: Steam yolunda genel ayar, doğrudan yolda oyuna özel (varsa).
    private var effectiveGraphics: LaunchSettings {
        mode == .direct ? (model.settings(for: game).graphics ?? model.settings) : model.settings
    }

    private var graphicsSummary: String {
        var parts = [(profile ?? GameProfile()).rendererDescription]
        if effectiveGraphics.metalHUD { parts.append("FPS göstergesi") }
        if let fps = effectiveGraphics.maxFPS { parts.append("en fazla \(fps) FPS") }
        return parts.joined(separator: " · ")
    }

    private var saveSummary: String {
        guard model.saveFolder(for: game) != nil else { return "Save klasörü bilinmiyor (profiles.json → saveDirectory)" }
        guard let last = model.lastBackups[game.appID] else { return "Henüz yedek yok; Oyna'ya basınca otomatik alınır" }
        return "Son yedek: \(last.lastPathComponent.replacingOccurrences(of: "_", with: " ")) · Oyna'dan önce otomatik"
    }

    private var extraArguments: [String] {
        (mode == .steam ? profile?.steamArguments : profile?.arguments) ?? []
    }

    // Oyun başına seçimler (AppModel.gameSettings) için bağlamalar
    private func update(_ change: (inout GameSettings) -> Void) {
        var s = model.settings(for: game)
        change(&s)
        model.setSettings(s, for: game)
    }
    private var modeBinding: Binding<GameProfile.LaunchMode> {
        Binding(get: { mode }, set: { value in update { $0.launchMode = value } })
    }
    private var customGraphics: Binding<Bool> {
        Binding(get: { model.settings(for: game).graphics != nil },
                set: { on in update { $0.graphics = on ? ($0.graphics ?? model.settings) : nil } })
    }
    private var hudBinding: Binding<Bool> {
        Binding(get: { model.settings(for: game).graphics?.metalHUD ?? false },
                set: { value in update { $0.graphics?.metalHUD = value } })
    }
    private var fpsBinding: Binding<Int?> {
        Binding(get: { model.settings(for: game).graphics?.maxFPS },
                set: { value in update { $0.graphics?.maxFPS = value } })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Boyutu sabit boş bir kutu; görsel onun üstüne bindiriliyor (overlay). scaledToFill görsel
                // doğrudan yerleştirilirse kendini pencereden geniş bildirir ve bütün sayfayı kaydırır.
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .overlay { CoverImage(url: game.heroImage) }
                    .clipped()
                    .overlay(alignment: .bottomLeading) { heroTitle }
                    .background(.quaternary)

                HStack(spacing: 16) {
                    Button {
                        model.play(game)
                    } label: {
                        Label(running ? "Çalışıyor" : launching ? "Başlatılıyor…" : "Oyna",
                              systemImage: running ? "checkmark.circle.fill" : "play.fill")
                            .frame(minWidth: 120)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.extraLarge)
                    .disabled(running || launching || !game.isFullyInstalled)

                    if launching { ProgressView().controlSize(.small) }
                    if !game.isFullyInstalled {
                        Label("Steam'de kuruluyor ya da kurulumu yarım; bitince Oyna açılır",
                              systemImage: "arrow.down.circle")
                            .foregroundStyle(.secondary)
                    } else if game.needsUpdate {
                        Label("Steam önce güncelleme isteyecek", systemImage: "arrow.down.circle")
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 20)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow { Text("Diskte").foregroundStyle(.secondary)
                        Text(game.sizeOnDisk > 0 ? game.sizeOnDisk.formatted(.byteCount(style: .file)) : "—") }
                    GridRow { Text("Steam AppID").foregroundStyle(.secondary)
                        Text(game.appID).textSelection(.enabled) }
                    if !extraArguments.isEmpty {
                        GridRow { Text("Ek seçenekler").foregroundStyle(.secondary)
                            Text(extraArguments.joined(separator: " ")).monospaced() }
                    }
                    if mode == .direct, let exe = profile?.executable {
                        GridRow { Text("Program").foregroundStyle(.secondary)
                            Text(exe).monospaced().textSelection(.enabled) }
                    }
                    GridRow { Text("Grafik").foregroundStyle(.secondary)
                        Text(graphicsSummary) }
                    GridRow { Text("Kayıtlar").foregroundStyle(.secondary)
                        Text(saveSummary) }
                }
                .padding(.horizontal, 20)

                if let saves = model.saveFolder(for: game) {
                    HStack(spacing: 16) {
                        Button("Şimdi Yedekle", systemImage: "externaldrive.badge.timemachine") { model.backupNow(game) }
                        Button("Save Klasörü", systemImage: "folder") { model.reveal(saves) }
                            .disabled(!FileManager.default.fileExists(atPath: saves.path))
                        if let last = model.lastBackups[game.appID] {
                            Button("Yedekler", systemImage: "clock.arrow.circlepath") { model.reveal(last) }
                        }
                    }
                    .buttonStyle(.link)
                    .padding(.horizontal, 20)
                }

                if profile?.executable != nil { launchSection }

                Button("Oyun Klasörünü Göster", systemImage: "folder") {
                    model.reveal(game.installURL)
                }
                .buttonStyle(.link)
                .padding(.horizontal, 20)

                Group {
                    if mode == .steam {
                        Text("Oyun Steam üzerinden açılır; Steam kapalıysa önce o açılır. Kayıtlar oyundan çıkınca Steam Cloud'a yüklenir. Grafik ayarı genel ayarlardan (⌘,) gelir.")
                    } else {
                        Text("Oyun exe'si Steam'e sorulmadan başlatılır (Steam açık kalır, oyun SteamAppId ile bağlanır). Böylece oyuna özel ayar mümkün; ama Steam Cloud'un açılıştaki eşitlemesi ve Steam'in ilk kurulum adımları atlanır.")
                    }
                    if let notes = profile?.notes { Text(notes).italic() }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        }
        .navigationTitle(game.name)
    }

    /// Başlatma yolu (yalnızca profilde exe yolu varsa) ve doğrudan yolda oyuna özel grafik ayarı.
    private var launchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Başlatma", selection: modeBinding) {
                Text("Steam üzerinden").tag(GameProfile.LaunchMode.steam)
                Text("Doğrudan").tag(GameProfile.LaunchMode.direct)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
            .disabled(running || launching)

            if mode == .direct {
                Toggle("Bu oyuna özel grafik ayarı", isOn: customGraphics)
                if customGraphics.wrappedValue {
                    HStack(spacing: 20) {
                        Toggle("FPS göstergesi", isOn: hudBinding)
                        Picker("FPS sınırı", selection: fpsBinding) {
                            Text("Sınırsız").tag(Int?.none)
                            ForEach(LaunchSettings.fpsChoices, id: \.self) { Text("\($0)").tag(Int?.some($0)) }
                        }
                        .frame(maxWidth: 200)
                    }
                    .padding(.leading, 20)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    /// Büyük görselin sol altında: alttan kararan geçiş + oyunun logosu (yoksa adı).
    private var heroTitle: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
            if let logo = game.logoImage, let image = NSImage(contentsOf: logo) {
                Image(nsImage: image).resizable().scaledToFit()
                    .frame(maxWidth: 320, maxHeight: 110)
                    .padding(20)
            } else {
                Text(game.name).font(.largeTitle.bold()).foregroundStyle(.white).padding(20)
            }
        }
    }
}

/// Steam'in önbellekteki görseli; yoksa gri bir yer tutucu.
private struct CoverImage: View {
    let url: URL?

    var body: some View {
        if let url, let image = NSImage(contentsOf: url) {
            Image(nsImage: image).resizable().scaledToFill()
        } else {
            Rectangle().fill(.quaternary)
                .overlay { Image(systemName: "gamecontroller").foregroundStyle(.secondary) }
        }
    }
}
