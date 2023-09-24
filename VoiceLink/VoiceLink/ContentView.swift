import Accelerate
import AVFoundation
import SwiftUI
import WatchConnectivity

struct BulletedText: View {
    let text: String
    let bullet: String
    
    init(_ text: String, bullet: String = "•") {
        self.text = text
        self.bullet = bullet
    }
    
    var body: some View {
        let items = self.text.components(separatedBy: "\n")
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        
        return VStack(alignment: .leading, spacing: 5) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 5) {
                    Text(timestamp)
                    Text(self.bullet)
                    Text(item)
                }
            }
        }
    }
}

class WatchSessionManager: NSObject, WCSessionDelegate {
    var session: WCSession
    
    init(session: WCSession = .default) {
        self.session = session
        super.init()
        self.session.delegate = self
        self.session.activate()
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WatchSessionManager: session activation failed with error: \(error.localizedDescription)")
        } else {
            print("WatchSessionManager: session activated with state: \(activationState.rawValue)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        print("WatchSessionManager: received message data from watch")
        print("WatchSessionManager: message data: \(messageData)")
        
        let audioPlayer = try? AVAudioPlayer(data: messageData)
        audioPlayer?.play()
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WatchSessionManager: session inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WatchSessionManager: session deactivated")
    }
    
    func sendAudioData(_ data: Data, messageLog: inout [String]) {
        guard WCSession.isSupported() else {
            messageLog.append("WatchConnectivity is not supported on this device")
            print("WatchConnectivity is not supported on this device")
            
            return
        }
        
        let session = WCSession.default
        
        if !session.isPaired {
            messageLog.append("Watch is not paired")
            print("Watch is not paired")
            
            return
        }
        
        var log = messageLog
        
        if session.isReachable {
            session.sendMessageData(data, replyHandler: nil, errorHandler: { error in
                log.append("Failed to send audio data to watch: \(error.localizedDescription)")
                print("Failed to send audio data to watch: \(error.localizedDescription)")
            })
        } else {
            log.append("Watch is not reachable")
            print("Watch is not reachable")
        }
        
        messageLog = log
    }
}
    
struct ContentView: View {
    @State private var isRecording = false
    @State private var messageLog = [String]()
    @State private var volumeLevel: Float = 1.0

    private var watchSessionManager = WatchSessionManager(session: WCSession.default)
    
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Text("VoiceLink")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Spacer()
            
            if self.isRecording {
                Image(systemName: "mic.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
                    .foregroundColor(.red)
                    .overlay(
                        Circle()
                            .stroke(Color.red, lineWidth: 5)
                            .scaleEffect(CGFloat(self.volumeLevel))
                            .opacity(Double(2 - self.volumeLevel))
                            .animation(Animation.easeOut(duration: 1), value: self.volumeLevel)
                    )
                    .onTapGesture {
                        self.stopRecording()
                    }
                
                Text("Recording...")
                    .font(.title2)
                    .foregroundColor(.gray)
            } else {
                Image(systemName: "mic.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
                    .foregroundColor(.red)
                    .onTapGesture {
                        self.startRecording()
                    }
                
                Text("Tap to start recording")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            if self.messageLog.count > 0 {
                Text("Message Log")
                    .font(.title2)
                    .foregroundColor(.gray)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(self.messageLog, id: \.self) { message in
                            BulletedText(message)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .frame(height: 100)
            }
            
            Spacer()
            
            Text("[© 2023 Siddharth Praveen Bharadwaj](https://sid110307.github.io/Sid110307)")
                .font(.footnote)
                .font(.system(size: 8))
                .foregroundColor(.gray)
                .accentColor(.gray)
                .multilineTextAlignment(.center)
        }
    }
    
    func sendAudioData(_ data: Data) {
        guard WCSession.isSupported() else {
            self.messageLog.append("WatchConnectivity is not supported on this device")
            print("WatchConnectivity is not supported on this device")
            return
        }
        
        let session = WCSession.default
        self.messageLog.append("Watch connectivity is supported")
        
        if !session.isPaired {
            self.messageLog.append("Watch is not paired")
            print("Watch is not paired")
            
            return
        }
        
        if session.isReachable {
            session.sendMessageData(data, replyHandler: nil, errorHandler: { error in
                self.messageLog.append("Failed to send audio data to watch: \(error.localizedDescription)")
                print("Failed to send audio data to watch: \(error.localizedDescription)")
            })
        } else {
            self.messageLog.append("Watch is not reachable")
            print("Watch is not reachable")
        }
    }
    
    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        self.isRecording = true
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true, options: [])
        } catch {
            self.messageLog.append("Failed to set up audio recording: \(error.localizedDescription)")
            print("Failed to set up audio recording: \(error.localizedDescription)")
        }
        
        let audioRecorder = try! AVAudioRecorder(url: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("recording.wav"), settings: [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 16,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ])
        
        audioRecorder.prepareToRecord()
        audioRecorder.record()
        
        audioRecorder.isMeteringEnabled = true
        let updateInterval: TimeInterval = 0.1
        Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            audioRecorder.updateMeters()
            let averagePower = audioRecorder.averagePower(forChannel: 0)
            let percentage = pow(10, 0.05 * averagePower) * 100
            self.volumeLevel = Float(percentage / 100)
        }
        
        guard let audioData = FileManager.default.contents(atPath: audioRecorder.url.path) else {
            self.messageLog.append("Failed to get audio data from recording")
            print("Failed to get audio data from recording")
            return
        }
        
        self.watchSessionManager.sendAudioData(audioData, messageLog: &self.messageLog)
    }
    
    func stopRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false)
            DispatchQueue.main.async {
                self.isRecording = false
            }
        } catch {
            self.messageLog.append("Failed to stop audio session: \(error.localizedDescription)")
            print("Failed to stop audio session: \(error.localizedDescription)")
            
            return
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
