import Foundation
import SwiftUI
import Combine

public struct SubtitleItem: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let timestamp = Date()
    public let detectedLanguage: String
    public let originalText: String
    public let translatedText: String
    public let latencyMs: Double
    
    public var flagEmoji: String {
        switch detectedLanguage.lowercased() {
        case "pt": return "🇧🇷"
        case "es": return "🇨🇱"
        case "en": return "🇺🇸"
        default: return "🌐"
        }
    }
    
    public var languageBadge: String {
        if detectedLanguage.lowercased() == "pt" {
            return "🇧🇷 Portugués ➔ Español"
        } else if detectedLanguage.lowercased() == "es" {
            return "🇨🇱 Español"
        } else {
            return "\(flagEmoji) \(detectedLanguage.uppercased())"
        }
    }
}

@available(macOS 15.0, *)
public class SubtitleCoordinator: ObservableObject, AudioCaptureDelegate {
    @Published public var isListening: Bool = false
    @Published public var audioSource: AudioSourceType = .systemAudio
    @Published public var audioLevel: Float = 0.0
    @Published public var statusMessage: String = "Listo para iniciar"
    @Published public var currentSubtitle: SubtitleItem?
    @Published public var subtitleHistory: [SubtitleItem] = []
    
    // UI Settings
    @Published public var isClickThrough: Bool = false
    @Published public var fontSize: CGFloat = 22.0
    @Published public var overlayOpacity: Double = 0.88
    @Published public var showOriginalWhenTranslated: Bool = true
    // Performance Settings
    @Published public var selectedModel: String = "tiny" // default to tiny for instant sub-second response!
    @Published public var selectedLanguageMode: String = "auto" // "auto", "pt", "es"
    
    public let audioManager: AudioCaptureManager
    public let whisper: WhisperTranscriber
    public let translator: LocalTranslator
    
    private var processingQueue = DispatchQueue(label: "subtitles.processing.queue", qos: .userInitiated)
    private var isBusyProcessing = false
    
    public init() {
        self.audioManager = AudioCaptureManager()
        self.whisper = WhisperTranscriber()
        self.translator = LocalTranslator()
        
        self.audioManager.delegate = self
        self.whisper.setModel("tiny")
        self.selectedModel = "tiny"
    }
    
    public func setModel(_ model: String) {
        selectedModel = model
        whisper.setModel(model)
        statusMessage = "Modelo activo: \(model.uppercased())"
    }
    
    public func setLanguageMode(_ mode: String) {
        selectedLanguageMode = mode
        whisper.targetLanguage = mode
        if mode == "pt" {
            statusMessage = "Modo: Fijo Portugués (2x más rápido)"
        } else if mode == "es" {
            statusMessage = "Modo: Fijo Español"
        } else {
            statusMessage = "Modo: Auto-detectar (PT/ES)"
        }
    }
    
    public func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }
    
    public func startListening() {
        audioManager.start(source: audioSource)
        isListening = true
        statusMessage = "Escuchando \(audioSource.rawValue)..."
    }
    
    public func stopListening() {
        audioManager.stop()
        isListening = false
        audioLevel = 0.0
        statusMessage = "Subtítulos en pausa"
    }
    
    public func setAudioSource(_ newSource: AudioSourceType) {
        audioSource = newSource
        if isListening {
            startListening()
        }
    }
    
    public func clearSubtitles() {
        currentSubtitle = nil
        subtitleHistory.removeAll()
    }
    
    // MARK: - AudioCaptureDelegate
    
    public func didCaptureAudioSegment(wavURL: URL, duration: Double) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.statusMessage = "🎙️ Transcribiendo (\(String(format: "%.1f", duration))s)..."
            }
            
            Task {
                guard let result = await self.whisper.transcribe(wavURL: wavURL) else {
                    DispatchQueue.main.async {
                        if self.isListening {
                            self.statusMessage = "Escuchando \(self.audioSource.rawValue)..."
                        }
                    }
                    return
                }
                
                let (translated, detectedLang) = await self.translator.translateToSpanish(
                    text: result.text,
                    sourceLanguage: result.language
                )
                
                let item = SubtitleItem(
                    detectedLanguage: detectedLang,
                    originalText: result.text,
                    translatedText: translated,
                    latencyMs: result.latencyMs
                )
                
                DispatchQueue.main.async {
                    self.currentSubtitle = item
                    self.subtitleHistory.append(item)
                    if self.subtitleHistory.count > 100 {
                        self.subtitleHistory.removeFirst()
                    }
                    self.statusMessage = "⚡ \(Int(result.latencyMs))ms • 100% Local"
                }
            }
        }
    }
    
    public func didUpdateAudioLevel(level: Float) {
        DispatchQueue.main.async {
            self.audioLevel = level
        }
    }
    
    public func didEncounterError(message: String) {
        DispatchQueue.main.async {
            self.statusMessage = "⚠️ \(message)"
        }
    }
}
