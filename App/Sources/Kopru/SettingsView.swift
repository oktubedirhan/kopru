import SwiftUI

/// Köprü → Ayarlar (⌘,)
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Toggle("FPS göstergesi (Metal HUD)", isOn: $model.settings.metalHUD)
                Text("Oyun penceresinin köşesinde FPS, kare süresi ve GPU belleği gösterilir (MTL_HUD_ENABLED).")
                    .font(.caption).foregroundStyle(.secondary)

                Picker("FPS sınırı", selection: $model.settings.maxFPS) {
                    Text("Sınırsız").tag(Int?.none)
                    ForEach(LaunchSettings.fpsChoices, id: \.self) { Text("\($0)").tag(Int?.some($0)) }
                }
                Text("D3DMetal kare hızını bu sayıyla sınırlar (D3DM_MAX_FPS). Isınmayı ve pil tüketimini azaltır.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: {
                Text("Grafik")
            } footer: {
                Text("Oyunlar bu ayarları Steam'den alır; değişiklikler Steam yeniden başlatılınca geçerli olur.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
