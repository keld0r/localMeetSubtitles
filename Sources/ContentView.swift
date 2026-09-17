import SwiftUI
import Translation

@available(macOS 15.0, *)
public struct ContentView: View {
    @ObservedObject var coordinator: SubtitleCoordinator
    var onToggleClickThrough: ((Bool) -> Void)?
    
    @State private var showHistory: Bool = false
    @State private var translationConfig: TranslationSession.Configuration?
    
    public init(coordinator: SubtitleCoordinator, onToggleClickThrough: ((Bool) -> Void)? = nil) {
        self.coordinator = coordinator
        self.onToggleClickThrough = onToggleClickThrough
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            headerBar
            Divider().background(Color.white.opacity(0.2))
            if showHistory {
                historyView
            } else {
                subtitleView
            }
        }
        .frame(minWidth: 550, maxWidth: 900)
        .background(
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(coordinator.overlayOpacity)
            }
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(8)
        .translationTask(translationConfig) { session in
            coordinator.translator.activeSessionTranslator = { text in
                let response = try await session.translate(text)
                return response.targetText
            }
        }
        .onAppear {
            translationConfig = TranslationSession.Configuration(
                source: Locale.Language(identifier: "pt"),
                target: Locale.Language(identifier: "es")
            )
            coordinator.startListening()
        }
    }
    
    // MARK: - Header Bar
    @ViewBuilder
    private var headerBar: some View {
        HStack(spacing: 12) {
            // Live Status Pill
            HStack(spacing: 6) {
                Circle()
                    .fill(coordinator.isListening ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                    .shadow(color: coordinator.isListening ? .green : .clear, radius: 4)
                
                Text(coordinator.isListening ? "EN VIVO" : "PAUSADO")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(coordinator.isListening ? .green : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.4))
            .cornerRadius(6)
            
            // Audio Level Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(LinearGradient(colors: [.green, .yellow, .red], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(coordinator.audioLevel))))
                }
            }
            .frame(width: 50, height: 6)
            
            Spacer()
            
            // Source Selector
            Menu {
                Button("🔊 Audio Google Meet / Sistema") {
                    coordinator.setAudioSource(.systemAudio)
                }
                Button("🎙️ Micrófono de Mac") {
                    coordinator.setAudioSource(.microphone)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: coordinator.audioSource == .systemAudio ? "speaker.wave.3.fill" : "mic.fill")
                    Text(coordinator.audioSource == .systemAudio ? "Google Meet" : "Micrófono")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12))
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
            
            // Speed & Model Selector
            Menu {
                Button("🎯 Small (Recomendado PT-BR • ~150ms)") {
                    coordinator.setModel("small")
                }
                Button("🏆 Large-v3-Turbo (Máx. Precisión • ~220ms)") {
                    coordinator.setModel("large-v3-turbo")
                }
                Button("⚖️ Base (Rápido • ~100ms)") {
                    coordinator.setModel("base")
                }
                Button("⚡ Tiny (Ultra-Rápido • ~70ms)") {
                    coordinator.setModel("tiny")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: coordinator.selectedModel == "large-v3-turbo" ? "trophy.fill" : (coordinator.selectedModel == "small" ? "target" : "bolt.fill"))
                        .foregroundColor(coordinator.selectedModel == "small" ? .green : (coordinator.selectedModel == "large-v3-turbo" ? .yellow : .cyan))
                    Text(modelDisplayName(coordinator.selectedModel))
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12))
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
            .help("Small es el recomendado para portugués rápido; Large-v3-Turbo ofrece máxima precisión para acentos difíciles.")
            
            // Language Mode Selector
            Menu {
                Button("🌐 Auto-detectar (PT / ES)") {
                    coordinator.setLanguageMode("auto")
                }
                Button("🇧🇷 Solo Portugués (Corta latencia al doble)") {
                    coordinator.setLanguageMode("pt")
                }
                Button("🇨🇱 Solo Español") {
                    coordinator.setLanguageMode("es")
                }
            } label: {
                HStack(spacing: 4) {
                    Text(coordinator.selectedLanguageMode == "pt" ? "🇧🇷 Solo PT" : (coordinator.selectedLanguageMode == "es" ? "🇨🇱 Solo ES" : "🌐 Auto"))
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12))
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
            .help("Fijar a Portugués omite la evaluación de 99 idiomas y reduce la latencia en 50%.")
            
            // Font Size controls
            HStack(spacing: 2) {
                Button(action: { coordinator.fontSize = max(16, coordinator.fontSize - 2) }) {
                    Text("A-").font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.plain)
                
                Button(action: { coordinator.fontSize = min(36, coordinator.fontSize + 2) }) {
                    Text("A+").font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.12))
            .cornerRadius(6)
            
            // Click-through Toggle
            Button(action: {
                coordinator.isClickThrough.toggle()
                onToggleClickThrough?(coordinator.isClickThrough)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: coordinator.isClickThrough ? "lock.fill" : "hand.point.up.fill")
                    Text(coordinator.isClickThrough ? "Click-Through" : "Interactivo")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(coordinator.isClickThrough ? .yellow : .white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(coordinator.isClickThrough ? Color.yellow.opacity(0.2) : Color.white.opacity(0.12))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Modo Click-Through: los clics traspasan los subtítulos hacia la llamada de Google Meet.")
            
            // Toggle Play/Pause
            Button(action: { coordinator.toggleListening() }) {
                Image(systemName: coordinator.isListening ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(coordinator.isListening ? .yellow : .green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            // History Toggle
            Button(action: { showHistory.toggle() }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Historial de la conversación")
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }
    
    // MARK: - Subtitles Live Display
    @ViewBuilder
    private var subtitleView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let subtitle = coordinator.currentSubtitle {
                // Speaker Language Badge
                HStack(spacing: 6) {
                    Text(subtitle.languageBadge)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(6)
                    
                    Text("100% Localhost • \(Int(subtitle.latencyMs))ms")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Spacer()
                }
                
                // Main Translated Text (Spanish)
                Text(subtitle.translatedText)
                    .font(.system(size: coordinator.fontSize, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Original Spoken Text (if translated from Portuguese)
                if subtitle.detectedLanguage.lowercased().starts(with: "pt") && coordinator.showOriginalWhenTranslated {
                    Text("🇧🇷 Original: \"\(subtitle.originalText)\"")
                        .font(.system(size: max(12, coordinator.fontSize - 6), weight: .regular))
                        .foregroundColor(.white.opacity(0.65))
                        .italic()
                        .lineLimit(2)
                }
            } else {
                // Idle / Listening State
                HStack(spacing: 10) {
                    Image(systemName: coordinator.isListening ? "waveform" : "ear")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(coordinator.isListening ? "Escuchando llamada de Google Meet..." : "Subtítulos en Pausa")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(coordinator.statusMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - History List View
    @ViewBuilder
    private var historyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if coordinator.subtitleHistory.isEmpty {
                    Text("No hay historial de subtítulos aún.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(coordinator.subtitleHistory) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(item.languageBadge)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.yellow)
                                Spacer()
                                Text(item.timestamp, style: .time)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Text(item.translatedText)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            if item.detectedLanguage.lowercased().starts(with: "pt") {
                                Text(item.originalText)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.6))
                                    .italic()
                            }
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 14)
        }
        .frame(maxHeight: 180)
    }
    
    private func modelDisplayName(_ model: String) -> String {
        switch model {
        case "small": return "🎯 Small"
        case "large-v3-turbo": return "🏆 Large-Turbo"
        case "base": return "⚖️ Base"
        case "tiny": return "⚡ Tiny"
        default: return model.uppercased()
        }
    }
}

// Visual Effect Blur helper for macOS AppKit inside SwiftUI
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
