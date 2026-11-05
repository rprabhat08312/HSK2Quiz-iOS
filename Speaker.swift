import AVFoundation

/// Text-to-speech (Chinese by default, English optional). Uses the voices installed on the iPad:
/// Settings > Accessibility > Spoken Content > Voices > Chinese.
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()

    private let synth = AVSpeechSynthesizer()
    private(set) var ready = false
    private(set) var missing = false
    private(set) var englishOk = false
    /// 1 = normal. The history animation lowers it so the voice is slower and clearer.
    var rateScale: Float = 1
    private var done = [AVSpeechUtterance: () -> Void]()

    private override init() {
        super.init()
        synth.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        ready = AVSpeechSynthesisVoice(language: "zh-CN") != nil
        missing = !ready
        englishOk = AVSpeechSynthesisVoice(language: "en-US") != nil
    }

    private func utterance(_ text: String, english: Bool) -> AVSpeechUtterance {
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: english ? "en-US" : "zh-CN")
        let base: Float = english ? 0.46 : 0.40
        u.rate = max(AVSpeechUtteranceMinimumSpeechRate, min(AVSpeechUtteranceMaximumSpeechRate, base * rateScale))
        return u
    }

    /// Fire-and-forget Chinese speech (interrupts whatever is playing).
    func speak(_ text: String) {
        guard ready, !text.isEmpty else { return }
        cancelAll()
        synth.speak(utterance(text, english: false))
    }

    /// Speaks, then calls `completion` when finished (or after ~10 s). Used by "Play all".
    func say(_ text: String, english: Bool = false, completion: @escaping () -> Void) {
        if !ready || (english && !englishOk) || text.trimmingCharacters(in: .whitespaces).isEmpty {
            completion(); return
        }
        cancelAll()
        let u = utterance(text, english: english)
        var finished = false
        let finish: () -> Void = {
            if finished { return }
            finished = true
            completion()
        }
        done[u] = finish
        synth.speak(u)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if self?.done[u] != nil { self?.done[u] = nil; finish() }
        }
    }

    private func cancelAll() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    }

    func stop() {
        let pending = done
        done.removeAll()
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        for (_, f) in pending { f() }
    }

    // MARK: AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { complete(u) }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { complete(u) }
    private func complete(_ u: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            if let f = self?.done.removeValue(forKey: u) { f() }
        }
    }
}
