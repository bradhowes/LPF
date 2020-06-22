/*
 See LICENSE folder for this sample’s licensing information.

 Abstract:
 A simple playback engine built on AVAudioEngine and its related classes.
 */

import AVFoundation

final class SimplePlayEngine {
    
    // The engine's active unit node.
    private var activeAVAudioUnit: AVAudioUnit?

    private var instrumentPlayer: InstrumentPlayer?

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

    private var componentType: OSType {
        return activeAVAudioUnit?.audioComponentDescription.componentType ?? kAudioUnitType_Effect
    }
    
    private var isEffect: Bool {
        // SimplePlayEngine only supports effects or instruments.
        // If it's not an instrument, it's an effect
        return !isInstrument
    }

    private var isInstrument: Bool {
        return componentType == kAudioUnitType_MusicDevice
    }

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
            if isEffect {
                // Break the player -> effect connection.
                engine.disconnectNodeInput(audioUnit)
            }

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
            if isEffect && isPlaying {
                player.play()
            } else if isInstrument && isPlaying {
                instrumentPlayer = InstrumentPlayer(audioUnit: activeAVAudioUnit?.auAudioUnit)
                instrumentPlayer?.play()
            }
            completion()
        }

        let hardwareFormat = engine.outputNode.outputFormat(forBus: 0)

        // Connect the main mixer -> output node
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: hardwareFormat)

        // Pause the player before re-wiring it. It is not simple to keep it playing across an insertion or deletion.
        if isEffect && isPlaying {
            player.pause()
        } else if isInstrument && isPlaying {
            instrumentPlayer?.stop()
            instrumentPlayer = nil
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

        if isEffect {
            // Disconnect the player -> mixer.
            engine.disconnectNodeInput(engine.mainMixerNode)

            // Connect the player -> effect -> mixer.
            if let format = file?.processingFormat {
                engine.connect(player, to: avAudioUnit, format: format)
                engine.connect(avAudioUnit, to: engine.mainMixerNode, format: format)
            }
        } else {
            let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: hardwareFormat.sampleRate, channels: 2)
            engine.connect(avAudioUnit, to: engine.mainMixerNode, format: stereoFormat)
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
        // assumptions: we are protected by stateChangeQueue. we are not playing.
        setSessionActive(true)
        
        if isEffect {
            // Schedule buffers on the player.
            scheduleEffectLoop()
            scheduleEffectLoop()
        }
        
        let hardwareFormat = engine.outputNode.outputFormat(forBus: 0)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: hardwareFormat)
        
        // Start the engine.
        do {
            try engine.start()
        } catch {
            isPlaying = false
            fatalError("Could not start engine. error: \(error).")
        }
        
        if isEffect {
            // Start the player.
            player.play()
        } else if isInstrument {
            instrumentPlayer = InstrumentPlayer(audioUnit: activeAVAudioUnit?.auAudioUnit)
            instrumentPlayer?.play()
        }

        isPlaying = true
    }
    
    func stopPlayingInternal() {
        if isEffect {
            player.stop()
        } else if isInstrument {
            instrumentPlayer?.stop()
        }
        engine.stop()
        isPlaying = false
        setSessionActive(false)
    }
    
    func scheduleEffectLoop() {
        guard let file = file else {
            fatalError("`file` must not be nil in \(#function).")
        }
        
        player.scheduleFile(file, at: nil) {
            self.stateChangeQueue.async {
                if self.isPlaying {
                    self.scheduleEffectLoop()
                }
            }
        }
    }

    func resetAudioLoop() {
        if isEffect {
            // Connect player -> mixer.
            guard let format = file?.processingFormat else { fatalError("No AVAudioFile defined (processing format unavailable).") }
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
    }
}

private extension SimplePlayEngine {

    // MARK: InstrumentPlayer

    /// Simple MIDI note generator that plays a two-octave scale.
    final class InstrumentPlayer {

        private var isPlaying = false
        private var isDone = false
        private var noteBlock: AUScheduleMIDIEventBlock

        init?(audioUnit: AUAudioUnit?) {
            guard let audioUnit = audioUnit else { return nil }
            guard let theNoteBlock = audioUnit.scheduleMIDIEventBlock else { return nil }
            noteBlock = theNoteBlock
        }

        func play() {
            if !isPlaying {
                isDone = false
                scheduleInstrumentLoop()
            }
        }

        @discardableResult
        func stop() -> Bool {
            isPlaying = false
            criticalRegion(isDone) {}
            return isDone
        }

        private func criticalRegion(_ lock: Any, closure: () -> Void) {
            defer { objc_sync_exit(lock) }
            objc_sync_enter(lock)
            closure()
        }

        private func scheduleInstrumentLoop() {
            isPlaying = true
            DispatchQueue.global(qos: .default).async { self.playingThreead() }
        }

        private func playingThreead() {
            let cbytes = UnsafeMutablePointer<UInt8>.allocate(capacity: 3)
            var step = 0

            // The steps arrays define the musical intervals of a scale (w = whole step, h = half step).

            // C Major: w, w, h, w, w, w, h
            let steps = [2, 2, 1, 2, 2, 2, 1]

            // C Minor: w, h, w, w, w, h, w
            // let steps = [2, 1, 2, 2, 2, 1, 2]

            // C Lydian: w, w, w, h, w, w, h
            // let steps = [2, 2, 2, 1, 2, 2, 1]

            cbytes[0] = 0xB0 // status
            cbytes[1] = 60 // note
            cbytes[2] = 0 // velocity
            self.noteBlock(AUEventSampleTimeImmediate, 0, 3, cbytes)

            usleep(useconds_t(0.5))

            var releaseTime: Float = 0.05

            usleep(useconds_t(0.1 * 1e6))

            var note = 0
            self.criticalRegion(self.isDone) {

                while self.isPlaying {
                    // lengthen the releaseTime by 5% each time up to 10 seconds.
                    if releaseTime < 10.0 {
                        releaseTime = min(releaseTime * 1.05, 10.0)
                    }

                    cbytes[0] = 0x90 // note on
                    cbytes[1] = UInt8(60 + note)
                    cbytes[2] = 64
                    self.noteBlock(AUEventSampleTimeImmediate, 0, 3, cbytes)

                    usleep(useconds_t(0.2 * 1e6))

                    cbytes[2] = 0 // note off
                    self.noteBlock(AUEventSampleTimeImmediate, 0, 3, cbytes)

                    // Reset the note and step after a 2-octave run. (12 semi-tones * 2)
                    if note >= 24 {
                        note = 0
                        step = 0
                        continue
                    }

                    // Increment the note interval to the next interval step in the scale
                    note += steps[step]

                    step += 1

                    if step >= steps.count {
                        step = 0
                    }

                } // while isPlaying

                // All notes off
                cbytes[0] = 0xB0
                cbytes[1] = 123
                cbytes[2] = 0
                self.noteBlock(AUEventSampleTimeImmediate, 0, 3, cbytes)
                self.isDone = true

                cbytes.deallocate()
            }
        }
    }
}
