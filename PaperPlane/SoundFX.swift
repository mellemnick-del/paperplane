import AVFoundation

/// The prototype's two Web Audio sounds, rendered once into PCM buffers at launch:
/// a band-passed noise burst for the paper crumple and a rising triangle chirp per point.
///
/// All audio work runs on a private serial queue. Activating the audio session or
/// starting the engine can block for a moment, and doing that on the main thread
/// trips iOS's "AVAudioSession Hang Risk" check and stalls touches.
final class SoundFX {
    private let queue = DispatchQueue(label: "com.nickmellem.paperplane.sound", qos: .userInitiated)
    private let engine = AVAudioEngine()
    private let crumplePlayer = AVAudioPlayerNode()
    private let chirpPlayer = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var crumpleBuffer: AVAudioPCMBuffer?
    private var chirpBuffer: AVAudioPCMBuffer?
    private var configured = false

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        queue.async { self.setUp() }
    }

    func crumple() { queue.async { self.play(self.crumpleBuffer, on: self.crumplePlayer) } }
    func chirp() { queue.async { self.play(self.chirpBuffer, on: self.chirpPlayer) } }

    /// Call when the app returns to the foreground; iOS can stop the engine in the background.
    func start() { queue.async { self.startEngine() } }

    // MARK: Audio queue only

    private func setUp() {
        let rate = format.sampleRate
        crumpleBuffer = makeBuffer(Self.crumpleSamples(rate: rate))
        chirpBuffer = makeBuffer(Self.chirpSamples(rate: rate))

        // Ambient: respects the silent switch and mixes with the player's music.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)

        for player in [crumplePlayer, chirpPlayer] {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
        configured = true
        startEngine()
    }

    private func startEngine() {
        guard configured, !engine.isRunning else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        engine.prepare()
        try? engine.start()
    }

    private func play(_ buffer: AVAudioPCMBuffer?, on player: AVAudioPlayerNode) {
        guard configured, let buffer else { return }
        if !engine.isRunning { startEngine() }
        guard engine.isRunning else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(samples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        for i in 0..<samples.count { channel[i] = samples[i] }
        return buffer
    }

    /// Noise (30% loud grains) -> bandpass 2500 Hz, Q 0.8 -> gain 0.5 decaying to 0.001 over 0.35 s.
    private static func crumpleSamples(rate: Double) -> [Float] {
        let count = Int(rate * 0.4)
        // RBJ band-pass (0 dB peak), the same filter Web Audio's BiquadFilterNode uses.
        let w0 = 2 * Double.pi * 2500 / rate
        let alpha = sin(w0) / (2 * 0.8)
        let a0 = 1 + alpha
        let b0 = alpha / a0, b2 = -alpha / a0
        let a1 = -2 * cos(w0) / a0, a2 = (1 - alpha) / a0
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        var out = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let x = Double.random(in: -1..<1) * (Double.random(in: 0..<1) < 0.3 ? 1 : 0.25)
            let y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1; x1 = x; y2 = y1; y1 = y
            let t = Double(i) / rate
            let gain = 0.5 * pow(0.001 / 0.5, min(t, 0.35) / 0.35)
            out[i] = Float(y * gain)
        }
        return out
    }

    /// Triangle wave sweeping 660 -> 990 Hz over 0.08 s, gain 0.14 decaying to 0.001 over 0.15 s.
    private static func chirpSamples(rate: Double) -> [Float] {
        let count = Int(rate * 0.17)
        var phase = 0.0
        var out = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / rate
            let freq = 660 * pow(990.0 / 660, min(t, 0.08) / 0.08)
            phase += freq / rate
            phase -= phase.rounded(.down)
            let tri = 1 - 4 * abs(phase - 0.5)
            let gain = 0.14 * pow(0.001 / 0.14, min(t, 0.15) / 0.15)
            out[i] = Float(tri * gain)
        }
        return out
    }
}
