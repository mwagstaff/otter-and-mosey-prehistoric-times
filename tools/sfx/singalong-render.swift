// Renders the sing-along audio test offline with AVAudioEngine, the way the game's song player
// would play it live: the beat runs through an AVAudioUnitTimePitch for each round's speed, and
// every voice clip is scheduled at an exact sample time on the same clock. Called by
// singalong-test.mjs with the path of its plan.json.
import AVFoundation

struct Round: Decodable { let bpm: Double; let mode: String }
struct Lines: Decodable { let calls: [String]; let answers: [String] }
struct Plan: Decodable {
    let beat, crack, out: String
    let beatSeconds, firstDownbeat, detectedBpm: Double
    let rounds: [Round]
    let deliveries: [String: Lines]
}

let plan = try JSONDecoder().decode(Plan.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let rate = 44100.0
let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!

/// A whole clip in memory, with its leading silence cut so the voice starts right on the beat.
func load(_ path: String, trim: Bool) throws -> AVAudioPCMBuffer {
    let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
    let full = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
    try file.read(into: full)
    guard trim, let data = full.floatChannelData else { return full }
    let threshold: Float = 0.0056 // -45 dB
    var first = 0
    search: while first < Int(full.frameLength) {
        for channel in 0..<Int(full.format.channelCount) where abs(data[channel][first]) > threshold { break search }
        first += 1
    }
    first = max(0, first - Int(0.01 * full.format.sampleRate))
    let length = Int(full.frameLength) - first
    let cut = AVAudioPCMBuffer(pcmFormat: full.format, frameCapacity: AVAudioFrameCount(length))!
    cut.frameLength = AVAudioFrameCount(length)
    for channel in 0..<Int(full.format.channelCount) {
        cut.floatChannelData![channel].update(from: data[channel] + first, count: length)
    }
    return cut
}

struct Cue { let buffer: AVAudioPCMBuffer; let time: Double; let volume: Float }

func render(lines: Lines, round: Round, into output: AVAudioFile) throws {
    let factor = round.bpm / plan.detectedBpm
    let beatLength = plan.beatSeconds / factor
    func at(_ bar: Int, _ beat: Int) -> Double { Double(bar * 4 + beat) * beatLength }

    var cues: [Cue] = []
    for (index, call) in lines.calls.enumerated() {
        let bar = 1 + index * 2
        let answer = try load(lines.answers[index], trim: true)
        if round.mode != "whole" { cues.append(Cue(buffer: try load(call, trim: true), time: at(bar, 0), volume: 1)) }
        if round.mode == "together" {
            cues.append(Cue(buffer: answer, time: at(bar + 1, 0), volume: 1))
        } else {
            cues.append(Cue(buffer: try load(plan.crack, trim: true), time: at(bar + 1, 2) - 0.05, volume: 0.5))
            cues.append(Cue(buffer: answer, time: at(bar + 1, 2), volume: 0.85))
        }
    }
    let seconds = at(1 + lines.calls.count * 2 + 1, 0)

    let engine = AVAudioEngine()
    try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)

    let beatFile = try AVAudioFile(forReading: URL(fileURLWithPath: plan.beat))
    let beatNode = AVAudioPlayerNode()
    let pitch = AVAudioUnitTimePitch()
    pitch.rate = Float(factor)
    engine.attach(beatNode)
    engine.attach(pitch)
    engine.connect(beatNode, to: pitch, format: beatFile.processingFormat)
    engine.connect(pitch, to: engine.mainMixerNode, format: beatFile.processingFormat)
    beatNode.volume = 0.5
    let startFrame = AVAudioFramePosition(plan.firstDownbeat * beatFile.processingFormat.sampleRate)
    beatNode.scheduleSegment(beatFile, startingFrame: startFrame,
                             frameCount: AVAudioFrameCount(beatFile.length - startFrame), at: nil)

    var voices: [AVAudioPlayerNode] = []
    for cue in cues {
        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: cue.buffer.format)
        node.volume = cue.volume
        node.scheduleBuffer(cue.buffer, at: AVAudioTime(sampleTime: AVAudioFramePosition(cue.time * cue.buffer.format.sampleRate),
                                                        atRate: cue.buffer.format.sampleRate))
        voices.append(node)
    }

    try engine.start()
    beatNode.play()
    voices.forEach { $0.play() }

    let total = AVAudioFramePosition((seconds + 0.6) * rate)
    let fade = AVAudioFramePosition(0.8 * rate)
    let chunk = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: engine.manualRenderingMaximumFrameCount)!
    while engine.manualRenderingSampleTime < total {
        let start = engine.manualRenderingSampleTime
        let frames = AVAudioFrameCount(min(AVAudioFramePosition(chunk.frameCapacity), total - start))
        guard try engine.renderOffline(frames, to: chunk) == .success else { break }
        for channel in 0..<2 {
            let samples = chunk.floatChannelData![channel]
            for frame in 0..<Int(chunk.frameLength) {
                let position = start + AVAudioFramePosition(frame)
                let gain = position > total - fade ? Float(total - position) / Float(fade) : 1
                samples[frame] = max(-0.98, min(0.98, samples[frame] * gain))
            }
        }
        try output.write(from: chunk)
    }
    engine.stop()
}

func silence(_ seconds: Double, into output: AVAudioFile) throws {
    let gap = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(seconds * rate))!
    gap.frameLength = gap.frameCapacity
    for channel in 0..<2 { gap.floatChannelData![channel].update(repeating: 0, count: Int(gap.frameLength)) }
    try output.write(from: gap)
}

for (delivery, lines) in plan.deliveries.sorted(by: { $0.key < $1.key }) {
    let url = URL(fileURLWithPath: plan.out).appendingPathComponent("singalong-test-\(delivery).wav")
    try? FileManager.default.removeItem(at: url)
    let output = try AVAudioFile(forWriting: url, settings: [
        AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: rate, AVNumberOfChannelsKey: 2,
        AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
    ], commonFormat: .pcmFormatFloat32, interleaved: false)
    for round in plan.rounds {
        try render(lines: lines, round: round, into: output)
        try silence(1.2, into: output)
    }
    print("rendered \(url.lastPathComponent)")
}
