import AVFoundation
import Accelerate

enum AudioEngineError: Error {
    case engineNotRunning
    case noAudioData
    case conversionFailed
}

class AudioEngine {
    private let engine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferQueue = DispatchQueue(label: "com.everstage.evertalk.audiobuffer")

    // Whisper expects 16kHz mono audio
    private let targetSampleRate: Double = 16000

    func startRecording() throws {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Clear previous buffer
        bufferQueue.sync {
            audioBuffer.removeAll()
        }

        // Install tap to capture audio
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, inputSampleRate: inputFormat.sampleRate)
        }

        try engine.start()
    }

    func stopRecording() async throws -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        let result = bufferQueue.sync { () -> [Float] in
            let data = audioBuffer
            audioBuffer.removeAll()
            return data
        }

        guard !result.isEmpty else {
            throw AudioEngineError.noAudioData
        }

        return result
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, inputSampleRate: Double) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // Convert to mono if stereo
        var monoSamples = [Float](repeating: 0, count: frameCount)

        if channelCount == 1 {
            memcpy(&monoSamples, channelData[0], frameCount * MemoryLayout<Float>.size)
        } else {
            // Average channels for mono
            for i in 0..<frameCount {
                var sum: Float = 0
                for ch in 0..<channelCount {
                    sum += channelData[ch][i]
                }
                monoSamples[i] = sum / Float(channelCount)
            }
        }

        // Resample to 16kHz if needed
        let resampledSamples: [Float]
        if inputSampleRate != targetSampleRate {
            resampledSamples = resample(monoSamples, from: inputSampleRate, to: targetSampleRate)
        } else {
            resampledSamples = monoSamples
        }

        bufferQueue.sync {
            audioBuffer.append(contentsOf: resampledSamples)
        }
    }

    private func resample(_ samples: [Float], from inputRate: Double, to outputRate: Double) -> [Float] {
        let ratio = outputRate / inputRate
        let outputCount = Int(Double(samples.count) * ratio)

        var output = [Float](repeating: 0, count: outputCount)

        // Simple linear interpolation resampling
        for i in 0..<outputCount {
            let srcIndex = Double(i) / ratio
            let srcIndexInt = Int(srcIndex)
            let fraction = Float(srcIndex - Double(srcIndexInt))

            if srcIndexInt + 1 < samples.count {
                output[i] = samples[srcIndexInt] * (1 - fraction) + samples[srcIndexInt + 1] * fraction
            } else if srcIndexInt < samples.count {
                output[i] = samples[srcIndexInt]
            }
        }

        return output
    }
}
