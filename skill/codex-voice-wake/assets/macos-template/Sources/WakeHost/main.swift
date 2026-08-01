import AppKit
import AVFoundation
import ApplicationServices
import Foundation

struct HotkeyConfig: Decodable {
    let keyCode: UInt16
    let modifiers: [String]
}

struct WakeConfig: Decodable {
    let wakePhrases: [String]
    let exitPhrases: [String]
    let exitArmDelaySeconds: Double
    let postExitSuppressSeconds: Double
    let acknowledgementEnabled: Bool?
    let acknowledgementText: String?
    let acknowledgementVoice: String?
    let acknowledgementRate: Int?
    let codexBundleIdentifier: String
    let activationDelayMilliseconds: Int
    let sendVoiceHotkey: Bool
    let voiceHotkey: HotkeyConfig
    let logTranscripts: Bool
}

final class FileLogger {
    private let queue = DispatchQueue(label: "io.github.codex-voice-wake.log")
    private let url: URL

    init() {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/CodexVoiceWake", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent("wake.log")
    }

    func write(_ message: String) {
        queue.async {
            let formatter = ISO8601DateFormatter()
            let line = "\(formatter.string(from: Date())) \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            if !FileManager.default.fileExists(atPath: self.url.path) {
                FileManager.default.createFile(atPath: self.url.path, contents: data)
                return
            }
            guard let handle = try? FileHandle(forWritingTo: self.url) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        }
    }
}

final class WakeHost {
    private let logger = FileLogger()
    private let engine = AVAudioEngine()
    private let audioQueue = DispatchQueue(label: "io.github.codex-voice-wake.audio")
    private var worker: Process?
    private var workerInput: FileHandle?
    private var outputBuffer = Data()
    private var testSignalSource: DispatchSourceSignal?
    private var acknowledgementProcess: Process?
    private let config: WakeConfig
    private let configURL: URL
    private let resources: URL

    init() throws {
        guard let resources = Bundle.main.resourceURL else {
            throw NSError(domain: "CodexVoiceWake", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing app resources"])
        }
        self.resources = resources
        let userConfig = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CodexVoiceWake/config.json")
        let bundledConfig = resources.appendingPathComponent("config.json")
        configURL = FileManager.default.fileExists(atPath: userConfig.path) ? userConfig : bundledConfig
        config = try JSONDecoder().decode(WakeConfig.self, from: Data(contentsOf: configURL))
    }

    func start() {
        logger.write("START version=2 state_machine=idle recognizer=vosk-constrained-grammar voice_state_sync=codex-local-events audio_saved=false transcripts=\(config.logTranscripts) acknowledgement=\(config.acknowledgementEnabled ?? true)")
        let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let axTrusted = AXIsProcessTrustedWithOptions(promptOptions)
        logger.write("PERMISSION accessibility=\(axTrusted)")

        signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler { [weak self] in
            self?.logger.write("TEST_TRIGGER action_path=true")
            self?.activateCodex()
        }
        source.resume()
        testSignalSource = source

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startAudio()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                self?.logger.write("PERMISSION microphone=\(granted)")
                if granted { self?.startAudio() }
            }
        default:
            logger.write("ERROR microphone_permission_denied=true")
        }
    }

    private func launchWorker() throws {
        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [
            resources.appendingPathComponent("wake_listener.py").path,
            "--model", resources.appendingPathComponent("model").path,
            "--config", configURL.path
        ]
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONPATH"] = resources.appendingPathComponent("python").path
        environment["PYTHONUNBUFFERED"] = "1"
        process.environment = environment
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.consumeWorkerOutput(handle.availableData)
        }
        process.terminationHandler = { [weak self] process in
            self?.logger.write("ERROR worker_exited=\(process.terminationStatus)")
        }
        try process.run()
        worker = process
        workerInput = inputPipe.fileHandleForWriting
        logger.write("WORKER running=true pid=\(process.processIdentifier)")
    }

    private func startAudio() {
        audioQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.launchWorker()
                let input = self.engine.inputNode
                let sourceFormat = input.outputFormat(forBus: 0)
                guard let targetFormat = AVAudioFormat(
                    commonFormat: .pcmFormatInt16,
                    sampleRate: 16000,
                    channels: 1,
                    interleaved: true
                ), let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
                    throw NSError(domain: "CodexVoiceWake", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot initialize 16 kHz converter"])
                }
                input.installTap(onBus: 0, bufferSize: 2048, format: sourceFormat) { [weak self] buffer, _ in
                    self?.convertAndSend(buffer, converter: converter, targetFormat: targetFormat)
                }
                try self.engine.start()
                self.logger.write("AUDIO listening=true source_rate=\(Int(sourceFormat.sampleRate))")
            } catch {
                self.logger.write("ERROR audio_start=\(error.localizedDescription)")
            }
        }
    }

    private func convertAndSend(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) {
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 32)
        guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }
        var supplied = false
        var conversionError: NSError?
        let status = converter.convert(to: converted, error: &conversionError) { _, outStatus in
            if supplied {
                outStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, let samples = converted.int16ChannelData?[0], converted.frameLength > 0 else {
            if let conversionError { logger.write("ERROR convert=\(conversionError.localizedDescription)") }
            return
        }
        let data = Data(bytes: samples, count: Int(converted.frameLength) * MemoryLayout<Int16>.size)
        audioQueue.async { [weak self] in
            try? self?.workerInput?.write(contentsOf: data)
        }
    }

    private func consumeWorkerOutput(_ data: Data) {
        guard !data.isEmpty else { return }
        outputBuffer.append(data)
        while let newline = outputBuffer.firstIndex(of: 0x0A) {
            let lineData = outputBuffer.prefix(upTo: newline)
            outputBuffer.removeSubrange(...newline)
            guard
                let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                let event = object["event"] as? String
            else { continue }
            if event == "wake" {
                let recovered = object["recovered"] as? Bool ?? false
                logger.write("WAKE detected=true state=waiting_exit recovered=\(recovered)")
                speakAcknowledgement()
                activateCodex()
            } else if event == "exit" {
                logger.write("EXIT detected=true state=idle")
                exitCodexVoice()
            } else if event == "voice_state" {
                logger.write("STATE voice_active=\(object["active"] ?? false) state=waiting_exit")
            } else if event == "state_reset" {
                logger.write("STATE sync_reset=true reason=\(object["reason"] ?? "unknown") state=idle")
            } else if event == "transcript", config.logTranscripts {
                logger.write("TRANSCRIPT \(object["text"] ?? "")")
            }
        }
    }

    private func speakAcknowledgement() {
        guard config.acknowledgementEnabled ?? true else {
            logger.write("ACTION acknowledgement=disabled")
            return
        }
        let text = config.acknowledgementText ?? "在呢"
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.write("ERROR acknowledgement_empty=true")
            return
        }
        DispatchQueue.main.async {
            if self.acknowledgementProcess?.isRunning == true {
                self.logger.write("ACTION acknowledgement_skipped=already_speaking")
                return
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            let voice = self.config.acknowledgementVoice ?? "Tingting"
            let rate = self.config.acknowledgementRate ?? 185
            process.arguments = ["-v", voice, "-r", String(rate), text]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { [weak self, weak process] finished in
                self?.logger.write("ACTION acknowledgement_finished=true status=\(finished.terminationStatus)")
                DispatchQueue.main.async {
                    if let process, self?.acknowledgementProcess === process {
                        self?.acknowledgementProcess = nil
                    }
                }
            }
            do {
                try process.run()
                self.acknowledgementProcess = process
                self.logger.write("ACTION acknowledgement_started=true voice=\(voice) rate=\(rate) characters=\(text.count)")
            } catch {
                self.logger.write("ERROR acknowledgement_start=\(error.localizedDescription)")
            }
        }
    }

    private func activateCodex() {
        DispatchQueue.main.async {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            let candidates = NSRunningApplication.runningApplications(withBundleIdentifier: self.config.codexBundleIdentifier)
            if let running = candidates.first {
                let activated = running.activate(options: [.activateAllWindows])
                self.logger.write("ACTION codex_activated=\(activated) already_running=true")
                if activated { self.scheduleHotkey() }
                return
            }
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: self.config.codexBundleIdentifier) else {
                self.logger.write("ERROR codex_not_found=\(self.config.codexBundleIdentifier)")
                return
            }
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, error in
                self.logger.write("ACTION codex_launched=\(error == nil)")
                if error == nil {
                    let activated = app?.activate(options: [.activateAllWindows]) ?? false
                    self.logger.write("ACTION codex_activated=\(activated) already_running=false")
                    if activated { self.scheduleHotkey() }
                }
            }
        }
    }

    private func scheduleHotkey() {
        guard config.sendVoiceHotkey else {
            logger.write("ACTION voice_hotkey=disabled")
            return
        }
        let delay = Double(config.activationDelayMilliseconds) / 1000.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.sendHotkey() }
    }

    private func sendHotkey() {
        var flags = CGEventFlags()
        for modifier in config.voiceHotkey.modifiers {
            switch modifier.lowercased() {
            case "command": flags.insert(.maskCommand)
            case "control": flags.insert(.maskControl)
            case "option": flags.insert(.maskAlternate)
            case "shift": flags.insert(.maskShift)
            default: break
            }
        }
        guard
            let down = CGEvent(keyboardEventSource: nil, virtualKey: config.voiceHotkey.keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: nil, virtualKey: config.voiceHotkey.keyCode, keyDown: false)
        else {
            logger.write("ERROR hotkey_event_creation=true")
            return
        }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        logger.write("ACTION voice_hotkey_sent=true accessibility=\(AXIsProcessTrusted())")
    }

    private func exitCodexVoice() {
        DispatchQueue.main.async {
            guard let running = NSRunningApplication.runningApplications(
                withBundleIdentifier: self.config.codexBundleIdentifier
            ).first else {
                self.logger.write("ERROR voice_exit_codex_not_running=true")
                return
            }
            let activated = running.activate(options: [.activateAllWindows])
            self.logger.write("ACTION voice_exit_codex_activated=\(activated)")
            guard activated else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                guard
                    let down = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true),
                    let up = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: false)
                else {
                    self.logger.write("ERROR voice_exit_escape_creation=true")
                    return
                }
                down.post(tap: .cghidEventTap)
                up.post(tap: .cghidEventTap)
                self.logger.write("ACTION voice_exit_escape_sent=true accessibility=\(AXIsProcessTrusted())")
            }
        }
    }
}

do {
    let host = try WakeHost()
    host.start()
    RunLoop.main.run()
} catch {
    fputs("CodexVoiceWake fatal: \(error.localizedDescription)\n", stderr)
    exit(1)
}
