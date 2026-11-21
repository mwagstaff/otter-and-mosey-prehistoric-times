import AVFoundation
import TimesTroubleCore

/// Plays the Campfire Sing-Along on the beat. `AVAudioPlayer` can't keep clips in time, so this
/// uses its own `AVAudioEngine`: the backing loop runs through an `AVAudioUnitTimePitch` for each
/// round's speed (faster without going squeaky), and every voice clip is scheduled at an exact
/// sample time on the same clock. Words on screen follow `currentBeat`, read from that clock.
@MainActor
final class SongPlayer {
    private let engine = AVAudioEngine()
    private let beatNode = AVAudioPlayerNode()
    private let pitch = AVAudioUnitTimePitch()
    private let callNode = AVAudioPlayerNode()
    private let answerNode = AVAudioPlayerNode()
    private let effectNode = AVAudioPlayerNode()
    private static let rate = 44100.0
    private let format = AVAudioFormat(standardFormatWithSampleRate: SongPlayer.rate, channels: 2)!
    /// The backing loop, cut to a whole number of bars at `SongPlan.loopBPM`.
    private var loop: AVAudioPCMBuffer?
    private var crack: AVAudioPCMBuffer?
    private var clips: [String: AVAudioPCMBuffer] = [:]
    /// When the current round's beat 0 is heard, as a host time.
    private var startHost: UInt64?
    private var secondsPerBeat = 0.6
    private var musicVolume: Float = 0.5
    private var voiceVolume: Float = 0.9

    init() {
        for node in [beatNode, callNode, answerNode, effectNode] { engine.attach(node) }
        engine.attach(pitch)
        engine.connect(beatNode, to: pitch, format: format)
        engine.connect(pitch, to: engine.mainMixerNode, format: format)
        for node in [callNode, answerNode, effectNode] { engine.connect(node, to: engine.mainMixerNode, format: format) }
        loop = Self.buffer("sing_beat", format: format, trim: false).map { Self.wholeBars(of: $0) }
        crack = Self.buffer("crack", format: format, trim: true)
    }

    /// Whether the backing loop is bundled. Without it the song still runs, silently, on the clock.
    var hasLoop: Bool { loop != nil }

    func apply(_ settings: AppSettings) {
        musicVolume = settings.muted ? 0 : Float(settings.musicVolume) * 0.9
        voiceVolume = settings.muted ? 0 : Float(max(settings.effectsVolume, 0.3))
        beatNode.volume = musicVolume
        for node in [callNode, answerNode, effectNode] { node.volume = voiceVolume }
    }

    /// Loads every clip the song needs, so nothing has to be read from disk on the beat.
    func prepare(_ plan: SongPlan) {
        for line in 0..<plan.lineCount {
            for key in [SongPlan.callKey(table: plan.table, multiplier: plan.multipliers[line]), SongPlan.answerKey(plan.product(line: line))]
            where clips[key] == nil {
                clips[key] = Self.buffer("say_\(key)", format: format, trim: true)
            }
        }
    }

    // MARK: - Playing

    /// Starts a round from its count-in bar.
    func play(_ plan: SongPlan, round: SongRound) {
        stop()
        prepare(plan)
        secondsPerBeat = plan.secondsPerBeat(round)
        pitch.rate = Float(plan.rate(round))
        beatNode.volume = musicVolume
        if let loop { beatNode.scheduleBuffer(loop, at: nil, options: .loops) }
        for cue in plan.cues(round) {
            let node: AVAudioPlayerNode
            let buffer: AVAudioPCMBuffer?
            switch cue.sound {
            case .call(let key): (node, buffer) = (callNode, clips[key])
            case .answer(let key): (node, buffer) = (answerNode, clips[key])
            case .crack: (node, buffer) = (effectNode, crack)
            }
            guard let buffer else { continue }
            schedule(buffer, on: node, atBeat: cue.beat, volume: cue.volume)
        }
        start()
    }

    /// The quiz's waiting music: the loop, quieter and steady, with no voices.
    func vamp(_ plan: SongPlan) {
        stop()
        secondsPerBeat = plan.secondsPerBeat(.together)
        pitch.rate = Float(plan.rate(.together))
        beatNode.volume = musicVolume * 0.45
        if let loop { beatNode.scheduleBuffer(loop, at: nil, options: .loops) }
        start()
    }

    /// Sings one line again from the next bar, for the quiz's hint: Otter's call, then Mosey's answer.
    func singLine(_ plan: SongPlan, line: Int) {
        prepare(plan)
        guard let beat = currentBeat else { return }
        let bar = (beat / Double(SongPlan.beatsPerBar)).rounded(.up) * Double(SongPlan.beatsPerBar)
        if let call = clips[SongPlan.callKey(table: plan.table, multiplier: plan.multipliers[line])] {
            schedule(call, on: callNode, atBeat: bar, volume: 1)
        }
        if let answer = clips[SongPlan.answerKey(plan.product(line: line))] {
            schedule(answer, on: answerNode, atBeat: bar + Double(SongPlan.beatsPerBar), volume: 1)
        }
    }

    func stop() {
        for node in [beatNode, callNode, answerNode, effectNode] { node.stop() }
        startHost = nil
    }

    func shutDown() {
        stop()
        engine.stop()
    }

    /// Beats since the round's first beat was heard, or nil while stopped.
    var currentBeat: Double? {
        guard let startHost else { return nil }
        let now = mach_absolute_time()
        let elapsed = now >= startHost ? AVAudioTime.seconds(forHostTime: now - startHost) : -AVAudioTime.seconds(forHostTime: startHost - now)
        return elapsed / secondsPerBeat
    }

    private func schedule(_ buffer: AVAudioPCMBuffer, on node: AVAudioPlayerNode, atBeat beat: Double, volume: Float) {
        // Every node starts at the same moment, so a node's own sample time is the song's time.
        // The beat runs through the time-pitch unit, which delays it a little; the voices wait to match.
        let seconds = max(beat, 0) * secondsPerBeat + pitch.auAudioUnit.latency
        let time = AVAudioTime(sampleTime: AVAudioFramePosition(seconds * Self.rate), atRate: Self.rate)
        if volume < 1, let quieter = Self.scaled(buffer, by: volume) {
            node.scheduleBuffer(quieter, at: time)
        } else {
            node.scheduleBuffer(buffer, at: time)
        }
    }

    private func start() {
        do {
            if !engine.isRunning { try engine.start() }
        } catch {
            return
        }
        // A little ahead, so every node starts on exactly the same sample.
        let latency = AVAudioSession.sharedInstance().outputLatency
        let host = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.12)
        let start = AVAudioTime(hostTime: host)
        for node in [beatNode, callNode, answerNode, effectNode] { node.play(at: start) }
        startHost = host + AVAudioTime.hostTime(forSeconds: latency)
    }

    // MARK: - Loading

    /// A bundled sound in the engine's format, with any silence before it starts cut off, so a
    /// voice starts right on its beat.
    private static func buffer(_ name: String, format: AVAudioFormat, trim: Bool) -> AVAudioPCMBuffer? {
        guard let url = ["mp3", "m4a", "wav", "caf"].lazy.compactMap({ Bundle.main.url(forResource: name, withExtension: $0) }).first,
              let file = try? AVAudioFile(forReading: url),
              let source = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: source)) != nil,
              let converter = AVAudioConverter(from: file.processingFormat, to: format) else { return nil }
        let capacity = AVAudioFrameCount(Double(source.frameLength) * format.sampleRate / file.processingFormat.sampleRate) + 1024
        guard let converted = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var given = false
        var error: NSError?
        converter.convert(to: converted, error: &error) { _, status in
            if given {
                status.pointee = .endOfStream
                return nil
            }
            given = true
            status.pointee = .haveData
            return source
        }
        guard error == nil, converted.frameLength > 0 else { return nil }
        return trim ? trimmed(converted) : converted
    }

    private static func trimmed(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard let data = buffer.floatChannelData else { return buffer }
        let threshold: Float = 0.0056 // -45 dB
        var first = 0
        search: while first < Int(buffer.frameLength) {
            for channel in 0..<Int(buffer.format.channelCount) where abs(data[channel][first]) > threshold { break search }
            first += 1
        }
        first = max(0, first - Int(0.01 * buffer.format.sampleRate))
        let length = Int(buffer.frameLength) - first
        guard first > 0, length > 0, let cut = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: AVAudioFrameCount(length)) else { return buffer }
        cut.frameLength = AVAudioFrameCount(length)
        for channel in 0..<Int(buffer.format.channelCount) { cut.floatChannelData![channel].update(from: data[channel] + first, count: length) }
        return cut
    }

    /// The loop, trimmed to exactly the whole bars it holds, so it repeats on the beat.
    private static func wholeBars(of buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        let bar = Int((60 / SongPlan.loopBPM * Double(SongPlan.beatsPerBar) * buffer.format.sampleRate).rounded())
        let bars = Int(buffer.frameLength) / bar
        guard bars > 0 else { return buffer }
        buffer.frameLength = AVAudioFrameCount(bars * bar)
        return buffer
    }

    private static func scaled(_ buffer: AVAudioPCMBuffer, by volume: Float) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength),
              let from = buffer.floatChannelData, let to = copy.floatChannelData else { return nil }
        copy.frameLength = buffer.frameLength
        for channel in 0..<Int(buffer.format.channelCount) {
            for frame in 0..<Int(buffer.frameLength) { to[channel][frame] = from[channel][frame] * volume }
        }
        return copy
    }
}
