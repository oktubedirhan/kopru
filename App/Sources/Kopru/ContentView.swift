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

    private var graphicsSummary: String {
        var parts = ["D3DMetal 4 (DirectX → Metal)"]
        if model.settings.metalHUD { parts.append("FPS göstergesi") }
        if let fps = model.settings.maxFPS { parts.append("en fazla \(fps) FPS") }
        return parts.joined(separator: " · ")
    }
    private var launching: Bool { model.launching[game.id] != nil }

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
                    if game.needsUpdate {
                        Label("Steam önce güncelleme isteyecek", systemImage: "arrow.down.circle")
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 20)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow { Text("Diskte").foregroundStyle(.secondary)
                        Text(game.sizeOnDisk.formatted(.byteCount(style: .file))) }
                    GridRow { Text("Steam AppID").foregroundStyle(.secondary)
                        Text(game.appID).textSelection(.enabled) }
                    if let extra = GameProfiles.extraArguments[game.appID] {
                        GridRow { Text("Ek seçenekler").foregroundStyle(.secondary)
                            Text(extra.joined(separator: " ")).monospaced() }
                    }
                    GridRow { Text("Grafik").foregroundStyle(.secondary)
                        Text(graphicsSummary) }
                }
                .padding(.horizontal, 20)

                Button("Oyun Klasörünü Göster", systemImage: "folder") {
                    model.reveal(game.installURL)
                }
                .buttonStyle(.link)
                .padding(.horizontal, 20)

                Text("Oyun Steam üzerinden açılır; Steam kapalıysa önce o açılır. Kayıtlar oyundan çıkınca Steam Cloud'a yüklenir.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        }
        .navigationTitle(game.name)
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
