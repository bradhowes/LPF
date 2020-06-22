/*
 See LICENSE folder for this sample’s licensing information.

 Abstract:
 A simple playback engine built on AVAudioEngine and its related classes.
 */

import AVFoundation

final class SimplePlayEngine {
    
    // The engine's active unit node.
    private var activeAVAudioUnit: AVAudioUnit?

    // Synchronizes starting/stopping the engine and scheduling file segments.
    private let stateChangeQueue = DispatchQueue(label: "com.example.apple-samplecode.StateChangeQueue")
    
    // Playback engine.
    private let engine = AVAudioEngine()
    
    // Engine's player node.
    private let player = AVAudioPlayerNode()

    // File to play.
    private var file: AVAudioFile?
    
    // Whether we are playing.
    private var isPlaying = false
    
    // This block will be called every render cycle and will receive MIDI events
    private let midiOutBlock: AUMIDIOutputEventBlock = { sampleTime, cable, length, data in return noErr }

    // MARK: Initialization

    init() {
        engine.attach(player)

        guard let fileURL = Bundle(for: type(of: self)).url(forResource: "Synth", withExtension: "aif") else {
            fatalError("\"Synth.aif\" file not found.")
        }
        setPlayerFile(fileURL)

        engine.prepare()
    }
}

extension SimplePlayEngine {

    public func startPlaying() {
        stateChangeQueue.sync {
            if !self.isPlaying { self.startPlayingInternal() }
        }
    }

    public func stopPlaying() {
        stateChangeQueue.sync {
            if self.isPlaying { self.stopPlayingInternal() }
        }
    }

    public func togglePlay() -> Bool {
        if isPlaying {
            stopPlaying()
        } else {
            startPlaying()
        }
        return isPlaying
    }

    public func reset() {
        connect(avAudioUnit: nil)
    }

    public func connect(avAudioUnit: AVAudioUnit?, completion: @escaping (() -> Void) = {}) {

        // If effect, ensure audio loop is reset (but only once per call to this method)
        var needsAudioLoopReset = true

        // Destroy the currently connected audio unit, if any.
        if let audioUnit = activeAVAudioUnit {

            // Break the player -> effect connection.
            engine.disconnectNodeInput(audioUnit)

            // Break the audio unit -> mixer connection
            engine.disconnectNodeInput(engine.mainMixerNode)

            resetAudioLoop()
            needsAudioLoopReset = false

            // We're done with the unit; release all references.
            engine.detach(audioUnit)
        }

        activeAVAudioUnit = avAudioUnit

        // Internal function to resume playing and call the completion handler.
        func rewiringComplete() {
            if isPlaying {
                player.play()
            }
            completion()
        }

        let hardwareFormat = engine.outputNode.outputFormat(forBus: 0)

        // Connect the main mixer -> output node
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: hardwareFormat)

        // Pause the player before re-wiring it. It is not simple to keep it playing across an insertion or deletion.
        if isPlaying {
            player.pause()
        }

        guard let avAudioUnit = avAudioUnit else {
            if needsAudioLoopReset { resetAudioLoop() }
            rewiringComplete()
            return
        }

        let auAudioUnit = avAudioUnit.auAudioUnit

        if !auAudioUnit.midiOutputNames.isEmpty {
            auAudioUnit.midiOutputEventBlock = midiOutBlock
        }

        // Attach the AVAudioUnit the the graph.
        engine.attach(avAudioUnit)

        // Disconnect the player -> mixer.
        engine.disconnectNodeInput(engine.mainMixerNode)

        // Connect the player -> effect -> mixer.
        if let format = file?.processingFormat {
            engine.connect(player, to: avAudioUnit, format: format)
            engine.connect(avAudioUnit, to: engine.mainMixerNode, format: format)
        }

        rewiringComplete()
    }
}

private extension SimplePlayEngine {

    func setPlayerFile(_ fileURL: URL) {
        do {
            let file = try AVAudioFile(forReading: fileURL)
            self.file = file
            engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
        } catch {
            fatalError("Could not create AVAudioFile instance. error: \(error).")
        }
    }
    
    func setSessionActive(_ active: Bool) {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(active)
        } catch {
            fatalError("Could not set Audio Session active \(active). error: \(error).")
        }
        #endif
    }

    func startPlayingInternal() {
        guard let file = file else {
            fatalError("`file` must not be nil in \(#function).")
        }

        setSessionActive(true)
        scheduleEffectLoop(file)
        scheduleEffectLoop(file)

        let hardwareFormat = engine.outputNode.outputFormat(forBus: 0)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: hardwareFormat)
        
        do {
            try engine.start()
        } catch {
            isPlaying = false
            fatalError("Could not start engine. error: \(error).")
        }

        player.play()
        isPlaying = true
    }
    
    func stopPlayingInternal() {
        player.stop()
        engine.stop()
        isPlaying = false
        setSessionActive(false)
    }
    
    func scheduleEffectLoop(_ file: AVAudioFile) {
        player.scheduleFile(file, at: nil) {
            self.stateChangeQueue.async {
                if self.isPlaying {
                    self.scheduleEffectLoop(file)
                }
            }
        }
    }

    func resetAudioLoop() {
        // Connect player -> mixer.
        guard let format = file?.processingFormat else { fatalError("No AVAudioFile defined (processing format unavailable).") }
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }
}
