import Foundation
import AVFoundation
import ScreenCaptureKit

public protocol AudioCaptureDelegate: AnyObject {
    func didCaptureAudioSegment(wavURL: URL, duration: Double)
    func didUpdateAudioLevel(level: Float)
    func didEncounterError(message: String)
}

public enum AudioSourceType: String, CaseIterable, Identifiable {
    case systemAudio = "Audio de Google Meet / Sistema"
    case microphone = "Micrófono"
    
    public var id: String { rawValue }
}

public class AudioCaptureManager: NSObject, ObservableObject, SCStreamOutput, SCStreamDelegate {
    public weak var delegate: AudioCaptureDelegate?
    
    @Published public var isRunning = false
    @Published public var currentSource: AudioSourceType = .systemAudio
    @Published public var currentAudioLevel: Float = 0.0
    
    // ScreenCaptureKit stream
    private var scStream: SCStream?
    
    // AVAudioEngine for microphone
    private var audioEngine: AVAudioEngine?
    
    // Audio Buffering & VAD
    private let targetSampleRate: Double = 16000.0
    private var sampleBuffer: [Int16] = []
    private let bufferLock = NSLock()
    
    // VAD settings - calibrated for natural speech context and fast Portuguese
    private var isSpeaking = false
    private var silenceFramesCount = 0
    private let minSpeechFrames = 16000 * 12 / 10 // 1.2s minimum speech for full phonetic context
    private let maxSpeechFrames = 16000 * 30 / 10 // 3.0s maximum speech window
    private let silenceFramesThreshold = 16000 * 35 / 100 // 0.35s silence prevents mid-word cuts
    private let silenceEnergyThreshold: Float = 0.015
    
    private var tempDir: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("MeetSubtitlesAudio", isDirectory: true)
    }
    
    public override init() {
        super.init()
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    // MARK: - Public Controls
    
    public func start(source: AudioSourceType) {
        stop()
        currentSource = source
        
        switch source {
        case .systemAudio:
            startSystemAudioCapture()
        case .microphone:
            startMicrophoneCapture()
        }
    }
    
    public func stop() {
        if let stream = scStream {
            stream.stopCapture { _ in }
            scStream = nil
        }
        
        if let engine = audioEngine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
            audioEngine = nil
        }
        
        bufferLock.lock()
        sampleBuffer.removeAll()
        isSpeaking = false
        silenceFramesCount = 0
        bufferLock.unlock()
        
        DispatchQueue.main.async {
            self.isRunning = false
            self.currentAudioLevel = 0.0
        }
    }
    
    // MARK: - ScreenCaptureKit (System Audio)
    
    private func startSystemAudioCapture() {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    self.delegate?.didEncounterError(message: "No se encontró pantalla para capturar audio del sistema.")
                    return
                }
                
                let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                let config = SCStreamConfiguration()
                config.capturesAudio = true
                config.sampleRate = 16000
                config.channelCount = 1
                config.excludesCurrentProcessAudio = true
                
                // Minimal video footprint
                config.width = 100
                config.height = 100
                config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
                
                let stream = SCStream(filter: filter, configuration: config, delegate: self)
                try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "audio.sck.queue"))
                try await stream.startCapture()
                
                self.scStream = stream
                DispatchQueue.main.async {
                    self.isRunning = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.delegate?.didEncounterError(message: "Error al capturar audio del sistema: \(error.localizedDescription).\nVerifica los permisos de 'Grabación de pantalla y audio del sistema' en Preferencias del Sistema.")
                }
            }
        }
    }
    
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        processCMSampleBuffer(sampleBuffer)
    }
    
    // MARK: - Microphone (AVAudioEngine)
    
    private func startMicrophoneCapture() {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: targetSampleRate, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            delegate?.didEncounterError(message: "No se pudo configurar convertidor de audio del micrófono.")
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * self.targetSampleRate / inputFormat.sampleRate)
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else { return }
            
            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            if error == nil, let int16Data = convertedBuffer.int16ChannelData?[0] {
                let frameLength = Int(convertedBuffer.frameLength)
                let samples = Array(UnsafeBufferPointer(start: int16Data, count: frameLength))
                self.processAudioSamples(samples)
            }
        }
        
        do {
            try engine.start()
            self.audioEngine = engine
            DispatchQueue.main.async {
                self.isRunning = true
            }
        } catch {
            delegate?.didEncounterError(message: "Error al iniciar micrófono: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Audio Sample Processing & VAD
    
    private func processCMSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        
        var lengthAtOffset: Int = 0
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        
        guard CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: &totalLength, dataPointerOut: &dataPointer) == noErr,
              let data = dataPointer else { return }
        
        // Samples from SCK with config.sampleRate = 16000 & channelCount = 1 are Float32 or Int16
        // Let's inspect format description
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee else { return }
        
        var int16Samples: [Int16] = []
        
        if asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
            let floatCount = totalLength / MemoryLayout<Float32>.size
            data.withMemoryRebound(to: Float32.self, capacity: floatCount) { floatBuffer in
                int16Samples.reserveCapacity(floatCount)
                for i in 0..<floatCount {
                    let clamped = max(-1.0, min(1.0, floatBuffer[i]))
                    int16Samples.append(Int16(clamped * 32767.0))
                }
            }
        } else if asbd.mBitsPerChannel == 16 {
            let sampleCount = totalLength / MemoryLayout<Int16>.size
            data.withMemoryRebound(to: Int16.self, capacity: sampleCount) { int16Buffer in
                int16Samples = Array(UnsafeBufferPointer(start: int16Buffer, count: sampleCount))
            }
        }
        
        if !int16Samples.isEmpty {
            processAudioSamples(int16Samples)
        }
    }
    
    private func processAudioSamples(_ samples: [Int16]) {
        // Compute RMS energy for VAD
        var sumSquares: Double = 0.0
        for sample in samples {
            let normalized = Double(sample) / 32768.0
            sumSquares += normalized * normalized
        }
        let rms = Float(sqrt(sumSquares / Double(samples.count)))
        
        DispatchQueue.main.async {
            self.currentAudioLevel = min(1.0, rms * 5.0)
            self.delegate?.didUpdateAudioLevel(level: self.currentAudioLevel)
        }
        
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        if rms > silenceEnergyThreshold {
            isSpeaking = true
            silenceFramesCount = 0
            sampleBuffer.append(contentsOf: samples)
        } else if isSpeaking {
            silenceFramesCount += samples.count
            sampleBuffer.append(contentsOf: samples)
            
            // Check if speech has ended or exceeded max duration
            let shouldCut = (silenceFramesCount >= silenceFramesThreshold && sampleBuffer.count >= minSpeechFrames) ||
                            (sampleBuffer.count >= maxSpeechFrames)
            
            if shouldCut {
                let chunkToProcess = sampleBuffer
                // Keep 200ms overlap to avoid clipping next word
                let overlapCount = min(chunkToProcess.count, Int(targetSampleRate * 0.2))
                sampleBuffer = Array(chunkToProcess.suffix(overlapCount))
                isSpeaking = false
                silenceFramesCount = 0
                
                exportAndDispatchChunk(chunkToProcess)
            }
        }
    }
    
    private func exportAndDispatchChunk(_ samples: [Int16]) {
        guard samples.count >= minSpeechFrames else { return }
        
        let chunkID = UUID().uuidString
        let fileURL = tempDir.appendingPathComponent("chunk_\(chunkID).wav")
        let wavData = createWavData(from: samples, sampleRate: 16000)
        
        do {
            try wavData.write(to: fileURL)
            let duration = Double(samples.count) / targetSampleRate
            DispatchQueue.global(qos: .userInitiated).async {
                self.delegate?.didCaptureAudioSegment(wavURL: fileURL, duration: duration)
            }
        } catch {
            print("Error escribiendo archivo WAV temporal: \(error)")
        }
    }
    
    // MARK: - WAV Creation Helper
    
    private func createWavData(from samples: [Int16], sampleRate: Int32) -> Data {
        let numChannels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let byteRate = sampleRate * Int32(numChannels * (bitsPerSample / 8))
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = Int32(samples.count * MemoryLayout<Int16>.size)
        let chunkSize = 36 + dataSize
        
        var data = Data()
        data.reserveCapacity(44 + Int(dataSize))
        
        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        data.append(contentsOf: withUnsafeBytes(of: Int32(16).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: Int16(1).littleEndian) { Array($0) }) // PCM
        data.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        
        samples.withUnsafeBytes { buffer in
            data.append(contentsOf: buffer)
        }
        
        return data
    }
}
