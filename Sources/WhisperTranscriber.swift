import Foundation

public struct TranscriptionResult: Sendable {
    public let language: String
    public let text: String
    public let latencyMs: Double
    
    public var isPortuguese: Bool {
        language.lowercased().starts(with: "pt")
    }
    
    public var isSpanish: Bool {
        language.lowercased().starts(with: "es")
    }
}

public class WhisperTranscriber: ObservableObject {
    public let whisperCliPath: String
    public var modelPath: String
    
    private struct WhisperJSONOutput: Decodable {
        struct ResultInfo: Decodable {
            let language: String?
        }
        struct Segment: Decodable {
            let text: String?
        }
        let result: ResultInfo?
        let transcription: [Segment]?
    }
    
    @Published public var selectedModel: String = "base"
    @Published public var targetLanguage: String = "auto"
    
    public init(
        whisperCliPath: String = "/opt/homebrew/opt/whisper-cpp/bin/whisper-cli",
        modelPath: String = "models/ggml-base.bin"
    ) {
        self.whisperCliPath = whisperCliPath
        
        // Resolve relative model path
        if modelPath.hasPrefix("/") {
            self.modelPath = modelPath
        } else {
            let projectDir = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent().path
            self.modelPath = "\(projectDir)/\(modelPath)"
        }
    }
    
    public func setModel(_ modelName: String) {
        self.selectedModel = modelName
        let projectDir = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent().path
        let newPath = "\(projectDir)/models/ggml-\(modelName).bin"
        if FileManager.default.fileExists(atPath: newPath) {
            self.modelPath = newPath
        }
    }
    
    public func transcribe(wavURL: URL) async -> TranscriptionResult? {
        let startTime = CFAbsoluteTimeGetCurrent()
        let outputBase = wavURL.deletingPathExtension().path + "_out"
        let expectedJsonPath = outputBase + ".json"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: whisperCliPath)
        
        // Optimized arguments:
        // -bs 1 -bo 1: Greedy decoding (cuts 50%+ decoding time vs beam search)
        // -t 6: Utilize M1 Max performance cores
        // -l <targetLanguage>: Auto or direct hint (direct hint cuts latency by half!)
        process.arguments = [
            "-m", modelPath,
            "-f", wavURL.path,
            "-l", targetLanguage,
            "-bs", "1",
            "-bo", "1",
            "-t", "6",
            "-oj",
            "-of", outputBase,
            "-nt",
            "-np"
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let jsonURL = URL(fileURLWithPath: expectedJsonPath)
            defer {
                try? FileManager.default.removeItem(at: wavURL)
                try? FileManager.default.removeItem(at: jsonURL)
            }
            
            guard FileManager.default.fileExists(atPath: expectedJsonPath) else {
                return nil
            }
            
            let jsonData = try Data(contentsOf: jsonURL)
            let decoded = try JSONDecoder().decode(WhisperJSONOutput.self, from: jsonData)
            
            let language = decoded.result?.language ?? "auto"
            let fullText = decoded.transcription?
                .compactMap { $0.text }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            
            // Filter hallucinations or silence tokens
            guard !fullText.isEmpty,
                  !fullText.contains("[BLANK_AUDIO]"),
                  !fullText.contains("(silencio)") else {
                return nil
            }
            
            return TranscriptionResult(language: language, text: fullText, latencyMs: latency)
            
        } catch {
            print("Error ejecutando whisper-cli: \(error)")
            try? FileManager.default.removeItem(at: wavURL)
            return nil
        }
    }
}
