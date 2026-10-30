import AVFoundation
import Foundation

/// Sound effects for the horde game, synthesized at startup.
///
/// Nothing is shipped as an audio file. Every effect is generated as PCM from a
/// few lines of arithmetic, in the idiom of early-90s DOS shooters — noise
/// cracks, square-wave squawks and exponential decays — which is a style, not
/// an asset, and so carries no licence with it.
///
/// If a matching `.wav` exists in `assets/sounds/`, it is loaded in preference
/// to the synthesized version. That is the hook for using your own recordings
/// locally without any of them having to live in the repository.
final class Sound {

  static let shared = Sound()

  enum Effect: String, CaseIterable {
    case shot
    case death
    /// A heavy going down. Bigger raiders only — brutes keep the ordinary
    /// death cry, which reads better under their own arrival growl.
    case deathHeavy
    case nuke
    case field
    case boss
    case bite
    /// A health crate being shot open.
    case pickup
  }

  /// Simultaneous voices. Gunfire overlaps heavily, so the pool has to be deep
  /// enough that a burst does not cut itself off.
  private static let voiceCount = 14
  private static let sampleRate = 44_100.0

  private var engine: AVAudioEngine?
  private var voices: [AVAudioPlayerNode] = []
  private var nextVoice = 0
  private var buffers: [Effect: [AVAudioPCMBuffer]] = [:]
  /// Earliest time each effect may be heard again, so a long sample cannot
  /// stack a dozen copies on itself.
  private var nextAllowed: [Effect: TimeInterval] = [:]
  private var minimumGap: [Effect: TimeInterval] = [:]

  /// A node of its own for held-down sounds, kept clear of the round-robin
  /// pool so gunfire cannot be cut off by a death cry taking its turn.
  private var loopVoice: AVAudioPlayerNode?
  /// Seamless versions of the effects that are held rather than triggered.
  private var loopBuffers: [Effect: AVAudioPCMBuffer] = [:]
  private(set) var looping: Effect?

  private(set) var isRunning = false
  var muted = false
  /// Scales everything. Gunfire at fifteen rounds a second needs headroom.
  var masterVolume: Float = 0.55

  /// Effects requested this session, for checking routing in tests.
  private(set) var debugPlayLog: [Effect] = []
  func debugClearPlayLog() { debugPlayLog.removeAll() }

  private init() {}

  // MARK: - Lifecycle

  /// Brings the audio engine up. Only ever called from the windowed app — the
  /// headless modes leave it down, so they neither open a device nor make a
  /// sound on a build machine.
  func start() {
    guard !isRunning else { return }
    guard let format = AVAudioFormat(standardFormatWithSampleRate: Sound.sampleRate, channels: 1)
    else { return }

    let engine = AVAudioEngine()
    let sustain = AVAudioPlayerNode()
    engine.attach(sustain)
    engine.connect(sustain, to: engine.mainMixerNode, format: format)
    loopVoice = sustain

    for _ in 0..<Sound.voiceCount {
      let node = AVAudioPlayerNode()
      engine.attach(node)
      engine.connect(node, to: engine.mainMixerNode, format: format)
      voices.append(node)
    }

    buffers = Sound.buildLibrary(format: format)
    minimumGap = Sound.spacing(for: buffers)
    for effect in Sound.heldEffects {
      if let source = buffers[effect]?.first {
        loopBuffers[effect] = Sound.makeLoop(from: source, format: format)
      }
    }

    do {
      try engine.start()
    } catch {
      // No audio device, or it refused to start. The game is still playable.
      FileHandle.standardError.write(Data("Audio unavailable: \(error)\n".utf8))
      voices.removeAll()
      return
    }

    for node in voices { node.play() }
    loopVoice?.play()
    self.engine = engine
    isRunning = true
  }

  func stop() {
    stopLoop()
    engine?.stop()
    engine = nil
    voices.removeAll()
    isRunning = false
  }

  // MARK: - Playing

  /// Plays an effect on the next free voice, round-robin.
  func play(_ effect: Effect, gain: Float = 1.0) {
    // Recorded before the guards, so the headless tests can check which effect
    // the game asked for even with no engine running.
    debugPlayLog.append(effect)
    if debugPlayLog.count > 256 { debugPlayLog.removeFirst(128) }

    guard isRunning, !muted, let options = buffers[effect], !options.isEmpty else { return }

    // Rate limited by how long the sound actually is. The caller does not have
    // to know whether it is firing a 70ms synthesized crack or a three-quarter
    // second chaingun burst someone dropped into the folder.
    let now = CACurrentMediaTime()
    if let earliest = nextAllowed[effect], now < earliest { return }
    nextAllowed[effect] = now + (minimumGap[effect] ?? 0.05)

    // Several takes of each, picked at random, so a repeated effect does not
    // turn into one flat tone — which is exactly what rapid fire does.
    let buffer = options.randomElement()!
    let node = voices[nextVoice]
    nextVoice = (nextVoice + 1) % voices.count

    node.volume = min(max(gain * masterVolume, 0), 1)
    node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
  }

  // MARK: - Held sounds

  /// Effects that are held down rather than triggered. Gunfire is continuous
  /// while the trigger is held, so retriggering a sample is wrong twice over:
  /// it restarts the attack every time, and a sample with a decay tail turns
  /// into a stutter of bangs and fades.
  static let heldEffects: Set<Effect> = [.shot]

  /// Starts an effect looping, if it is not already.
  func startLoop(_ effect: Effect, gain: Float = 1.0) {
    guard isRunning, !muted, Sound.heldEffects.contains(effect) else { return }
    guard looping != effect, let buffer = loopBuffers[effect], let voice = loopVoice else {
      return
    }
    voice.stop()
    voice.volume = min(max(gain * masterVolume, 0), 1)
    voice.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
    voice.play()
    looping = effect
  }

  /// Stops whatever is being held.
  func stopLoop(_ effect: Effect? = nil) {
    guard looping != nil else { return }
    if let effect, looping != effect { return }
    loopVoice?.stop()
    loopVoice?.play()
    looping = nil
  }

  /// Cuts a sample down to the part worth looping and crossfades the seam.
  ///
  /// A recorded burst is an attack, a body, and a decay. Looping the whole
  /// thing plays the decay every cycle; looping only the body gives
  /// continuous fire. The end of the loop is crossfaded into material from
  /// just past it, so the seam does not click.
  static func makeLoop(from source: AVAudioPCMBuffer, format: AVAudioFormat)
    -> AVAudioPCMBuffer?
  {
    guard let samples = source.floatChannelData?[0] else { return nil }
    let total = Int(source.frameLength)
    guard total > 128 else { return source }

    // Energy per 10ms window.
    let window = max(Int(sampleRate * 0.01), 1)
    var levels: [Float] = []
    var index = 0
    while index < total {
      let end = min(index + window, total)
      var sum: Float = 0
      for i in index..<end { sum += samples[i] * samples[i] }
      levels.append((sum / Float(end - index)).squareRoot())
      index += window
    }
    guard let peak = levels.max(), peak > 0 else { return source }

    // Keep everything up to where it falls to half the peak — that is the
    // sustained firing, before the tail takes over.
    let threshold = peak * 0.5
    var lastLoud = 0
    for (i, level) in levels.enumerated() where level >= threshold { lastLoud = i }
    var loopFrames = min((lastLoud + 1) * window, total)
    // Guard against a sample that is all tail or all attack.
    loopFrames = max(loopFrames, Int(sampleRate * 0.05))
    loopFrames = min(loopFrames, total)

    let fade = min(Int(sampleRate * 0.006), max(loopFrames / 4, 1))
    guard
      let loop = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(loopFrames)),
      let out = loop.floatChannelData?[0]
    else { return source }
    loop.frameLength = AVAudioFrameCount(loopFrames)

    for i in 0..<loopFrames { out[i] = samples[i] }
    // Crossfade the seam using whatever follows the loop point.
    for i in 0..<fade {
      let follow = loopFrames + i
      guard follow < total else { break }
      let mix = Float(i) / Float(fade)
      out[i] = out[i] * mix + samples[follow] * (1 - mix)
    }
    return loop
  }

  // MARK: - Inspection

  /// Renders one effect without needing an engine, so the synthesis can be
  /// checked and listened to on a machine with no audio device.
  func debugRender(_ effect: Effect) -> AVAudioPCMBuffer? {
    guard let format = AVAudioFormat(standardFormatWithSampleRate: Sound.sampleRate, channels: 1)
    else { return nil }
    if let file = Sound.overrideFiles()[effect]?.first,
      let loaded = Sound.loadOverride(file, format: format)
    {
      return loaded
    }
    return Sound.synthesize(effect, format: format).first
  }

  /// Which file, if any, an effect is being taken from. Reported by the sound
  /// test so a folder of drop-ins can be checked at a glance.
  func debugSource(_ effect: Effect) -> String {
    guard let files = Sound.overrideFiles()[effect], !files.isEmpty else { return "synthesized" }
    return files.map { $0.lastPathComponent }.joined(separator: ", ")
  }

  /// Writes a buffer out as a 16-bit WAV.
  func debugWriteWAV(_ buffer: AVAudioPCMBuffer, to url: URL) {
    guard let samples = buffer.floatChannelData?[0] else { return }
    let count = Int(buffer.frameLength)
    let rate = UInt32(Sound.sampleRate)

    var data = Data()
    func append<T: FixedWidthInteger>(_ value: T) {
      withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }

    data.append(contentsOf: Array("RIFF".utf8))
    append(UInt32(36 + count * 2))
    data.append(contentsOf: Array("WAVEfmt ".utf8))
    append(UInt32(16))
    append(UInt16(1))  // PCM
    append(UInt16(1))  // mono
    append(rate)
    append(rate * 2)  // byte rate
    append(UInt16(2))  // block align
    append(UInt16(16))  // bits
    data.append(contentsOf: Array("data".utf8))
    append(UInt32(count * 2))
    for index in 0..<count {
      append(Int16(max(min(samples[index], 1), -1) * 32_000))
    }
    try? data.write(to: url)
  }

  /// How close together each effect may repeat, as a fraction of its own
  /// length. Deaths want to overlap; gunfire and one-shots do not.
  private static func spacing(
    for buffers: [Effect: [AVAudioPCMBuffer]]
  ) -> [Effect: TimeInterval] {
    let factor: [Effect: Double] = [
      .shot: 0.46, .death: 0.24, .deathHeavy: 0.5, .bite: 0.5, .nuke: 0.85,
      .field: 0.85, .boss: 0.9, .pickup: 0.8,
    ]
    var gaps: [Effect: TimeInterval] = [:]
    for (effect, options) in buffers {
      guard let longest = options.map({ Double($0.frameLength) / sampleRate }).max() else {
        continue
      }
      gaps[effect] = longest * (factor[effect] ?? 0.5)
    }
    return gaps
  }

  /// The gap an effect is currently held to, for the sound test.
  func debugGap(_ effect: Effect) -> TimeInterval {
    if let gap = minimumGap[effect] { return gap }
    guard let format = AVAudioFormat(standardFormatWithSampleRate: Sound.sampleRate, channels: 1)
    else { return 0 }
    return Sound.spacing(for: Sound.buildLibrary(format: format))[effect] ?? 0
  }

  // MARK: - The library

  private static func buildLibrary(format: AVAudioFormat) -> [Effect: [AVAudioPCMBuffer]] {
    var library: [Effect: [AVAudioPCMBuffer]] = [:]
    let overrides = overrideFiles()

    for effect in Effect.allCases {
      let loaded = (overrides[effect] ?? []).compactMap { loadOverride($0, format: format) }
      // Anything the folder does not cover falls back to the synthesized
      // version, so a partial set of files still works.
      library[effect] = loaded.isEmpty ? synthesize(effect, format: format) : loaded
    }
    return library
  }

  /// Where to look for sound files, in order of preference.
  static var soundDirectories: [URL] {
    var directories: [URL] = []
    if let override = ProcessInfo.processInfo.environment["LEMMINGS_SOUNDS"] {
      directories.append(URL(fileURLWithPath: override))
    }
    // Alongside the package, which is where they are easiest to drop.
    directories.append(
      URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // LegoLemmings
        .deletingLastPathComponent()  // Sources
        .deletingLastPathComponent()  // swift
        .appendingPathComponent("sounds"))
    directories.append(Assets.directory.appendingPathComponent("sounds"))
    return directories
  }

  /// Filenames that count as a given effect, beyond its own name.
  ///
  /// Sounds ripped out of a game arrive under that game's names, not this
  /// one's, so matching is by alias and ignores case and any trailing digits —
  /// which is also how two files like `GUARD_DIE1` and `GUARD_DIE2` become two
  /// takes of the same effect.
  private static let aliases: [Effect: [String]] = [
    .shot: ["shot", "chaingun", "gun", "machinegun", "mgun", "pistol", "fire"],
    .death: ["death", "guard_die", "guarddie", "die", "dies", "scream", "tod"],
    .deathHeavy: [
      "deathheavy", "heavydeath", "death_heavy", "lebensnd", "lebens", "mutti",
      "bigdeath", "officer",
    ],
    .boss: ["boss", "achtung", "alert", "halt", "schutzstaffel", "mutti", "roar"],
    .nuke: ["nuke", "explosion", "explode", "boom", "blast"],
    .field: ["field", "shield", "dome", "powerup", "barrier"],
    .bite: ["bite", "hit", "thud", "knock", "wall"],
    .pickup: [
      "pickup", "health", "healthkit", "medkit", "heal", "bonus", "treasure",
      "getkey", "item",
    ],
  ]

  private static let audioExtensions: Set<String> = [
    "wav", "aiff", "aif", "caf", "mp3", "m4a", "au",
  ]

  /// Finds every file that maps onto an effect, across the search directories.
  private static func overrideFiles() -> [Effect: [URL]] {
    var found: [Effect: [URL]] = [:]
    for directory in soundDirectories {
      guard
        let entries = try? FileManager.default.contentsOfDirectory(
          at: directory, includingPropertiesForKeys: nil)
      else { continue }

      for url in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
        guard audioExtensions.contains(url.pathExtension.lowercased()) else { continue }
        // Strip the extension, lowercase it, and drop any trailing take number.
        var stem = url.deletingPathExtension().lastPathComponent.lowercased()
        while let last = stem.last, last.isNumber { stem.removeLast() }
        stem = stem.trimmingCharacters(in: CharacterSet(charactersIn: "_- "))

        for (effect, names) in aliases {
          if names.contains(stem) || names.contains(where: { stem.hasPrefix($0) }) {
            found[effect, default: []].append(url)
            break
          }
        }
      }
      // First directory that yields anything wins, so a local folder can
      // shadow the shipped one wholesale rather than half of it.
      if !found.isEmpty { break }
    }
    return found
  }

  /// Reads a file and brings it into the engine's own format.
  private static func loadOverride(_ url: URL, format: AVAudioFormat) -> AVAudioPCMBuffer? {
    guard let file = try? AVAudioFile(forReading: url) else { return nil }
    let frames = AVAudioFrameCount(file.length)
    guard frames > 0,
      let raw = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames),
      (try? file.read(into: raw)) != nil
    else { return nil }

    guard let converted = convert(raw, to: format) else { return nil }
    normalize(converted, toPeak: 0.82)
    return converted
  }

  /// Resamples into the engine's format.
  ///
  /// Needed in practice, not in theory: period game audio tends to be 8-bit at
  /// something like 7kHz, and scheduling a buffer whose format does not match
  /// the node it is played on simply fails.
  private static func convert(
    _ buffer: AVAudioPCMBuffer, to format: AVAudioFormat
  ) -> AVAudioPCMBuffer? {
    if buffer.format == format { return buffer }
    guard let converter = AVAudioConverter(from: buffer.format, to: format) else { return nil }

    let ratio = format.sampleRate / buffer.format.sampleRate
    let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 2048
    guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
      return nil
    }

    var supplied = false
    var conversionError: NSError?
    converter.convert(to: output, error: &conversionError) { _, status in
      if supplied {
        status.pointee = .endOfStream
        return nil
      }
      supplied = true
      status.pointee = .haveData
      return buffer
    }

    guard conversionError == nil, output.frameLength > 0 else { return nil }
    return output
  }

  /// Levels a loaded sound against the synthesized ones, so dropping in files
  /// recorded at some other era's idea of loudness does not blow the mix apart.
  private static func normalize(_ buffer: AVAudioPCMBuffer, toPeak target: Float) {
    guard let samples = buffer.floatChannelData?[0] else { return }
    let count = Int(buffer.frameLength)
    var peak: Float = 0
    for index in 0..<count { peak = max(peak, abs(samples[index])) }
    guard peak > 0.0001 else { return }
    let gain = target / peak
    for index in 0..<count { samples[index] *= gain }
  }

  /// Builds a buffer from a closure over time in seconds.
  private static func render(
    _ format: AVAudioFormat, seconds: Double, _ sample: (Double) -> Float
  ) -> AVAudioPCMBuffer? {
    let frames = AVAudioFrameCount(seconds * sampleRate)
    guard frames > 0,
      let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
      let channel = buffer.floatChannelData?[0]
    else { return nil }

    buffer.frameLength = frames
    for index in 0..<Int(frames) {
      let t = Double(index) / sampleRate
      channel[index] = max(min(sample(t), 1), -1)
    }
    return buffer
  }

  /// A square wave, which is what gives these their period flavour.
  private static func square(_ frequency: Double, _ t: Double) -> Double {
    sin(2 * .pi * frequency * t) >= 0 ? 1 : -1
  }

  private static func noise() -> Double {
    Double.random(in: -1...1)
  }

  private static func synthesize(_ effect: Effect, format: AVAudioFormat) -> [AVAudioPCMBuffer] {
    switch effect {

    case .shot:
      // A continuous chaingun rather than one crack: nine rounds at the gun's
      // actual rate, which is an exact number of cycles and so loops with no
      // seam at all.
      let roundsPerSecond = 45.0
      let period = 1 / roundsPerSecond
      let cycles = 9.0
      return [render(format, seconds: period * cycles) { t in
        let phase = t.truncatingRemainder(dividingBy: period)
        let crack = exp(-phase * 150)
        let body = exp(-phase * 46)
        return Float(
          noise() * 0.6 * crack
            + square(176, phase) * 0.4 * body
            + sin(2 * .pi * 82 * phase) * 0.28 * body)
      }].compactMap { $0 }

    case .death:
      // A squawk falling away, the way a sprite death sounded when it was four
      // bytes of frequency and a decay.
      return [1.0, 0.86, 1.18].compactMap { scale in
        render(format, seconds: 0.3) { t in
          let frequency = (440 * exp(-t * 7.5) + 74) * scale
          let envelope = min(t * 220, 1) * exp(-t * 8.5)
          return Float((square(frequency, t) * 0.5 + noise() * 0.22) * envelope)
        }
      }

    case .deathHeavy:
      // Lower and longer than the ordinary death, for something with more mass
      // to it. Only used when no file is supplied.
      return [1.0, 0.9].compactMap { scale in
        render(format, seconds: 0.46) { t in
          let frequency = (250 * exp(-t * 5.0) + 52) * scale
          let envelope = min(t * 160, 1) * exp(-t * 5.2)
          return Float((square(frequency, t) * 0.52 + noise() * 0.2) * envelope)
        }
      }

    case .pickup:
      // Two rising tones and a sparkle — the universal sound of picking
      // something up, which is as period-correct as anything else here.
      return [render(format, seconds: 0.34) { t in
        let step = t < 0.1 ? 0.0 : (t < 0.19 ? 1.0 : 2.0)
        let frequency = 660 * pow(1.26, step)
        let envelope = min(t * 90, 1) * exp(-t * 3.6)
        let sparkle = sin(2 * .pi * frequency * 2.02 * t) * 0.18
        return Float((square(frequency, t) * 0.42 + sparkle) * envelope)
      }].compactMap { $0 }

    case .bite:
      // A dry knock for a raider taking a chunk out of the wall.
      return [render(format, seconds: 0.11) { t in
        let envelope = exp(-t * 40)
        return Float((noise() * 0.4 + square(120, t) * 0.4) * envelope)
      }].compactMap { $0 }

    case .nuke:
      // A long way down, with the noise outlasting the tone.
      return [render(format, seconds: 1.5) { t in
        let frequency = 96 * exp(-t * 2.4) + 26
        let tone = sin(2 * .pi * frequency * t)
        let rumble = noise() * exp(-t * 1.7) * 0.5
        let envelope = min(t * 400, 1) * exp(-t * 2.1)
        return Float((tone * 0.75 + rumble) * envelope)
      }].compactMap { $0 }

    case .field:
      // A rising shimmer that settles, for the dome coming up.
      return [render(format, seconds: 0.55) { t in
        let frequency = 300 + t * 980
        let shimmer = sin(2 * .pi * 31 * t) * 0.3 + 0.7
        let envelope = min(t * 26, 1) * exp(-t * 3.4)
        return Float(sin(2 * .pi * frequency * t) * shimmer * envelope * 0.5)
      }].compactMap { $0 }

    case .boss:
      // A low growl with a slow wobble, for the brute walking on.
      return [render(format, seconds: 1.1) { t in
        let wobble = sin(2 * .pi * 6.5 * t) * 14
        let envelope = min(t * 10, 1) * exp(-t * 1.5)
        return Float(
          (square(56 + wobble, t) * 0.45 + sin(2 * .pi * 38 * t) * 0.4) * envelope)
      }].compactMap { $0 }
    }
  }
}
