import AVFoundation
import SwiftUI

class AudioPlayerDelegate: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
    
    func audioPlayerBeginInterruption(_ player: AVAudioPlayer) {
        player.pause()
        isPlaying = false
    }
    
    func audioPlayerEndInterruption(_ player: AVAudioPlayer, withOptions flags: Int) {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            player.play()
            isPlaying = true
        } catch {
            print("Failed to resume audio playback: \(error.localizedDescription)")
        }
    }
}

class SessionManager: ObservableObject {
    @Published var receivedData: Data?
}

struct ContentView: View {
    @ObservedObject var sessionManager = SessionManager()
    @ObservedObject var audioPlayerDelegate = AudioPlayerDelegate()
    @State private var audioPlayer: AVAudioPlayer?
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(alignment: .center) {
            Text("VoiceLink")
                .font(.title)
                .foregroundColor(.red)
                .padding(.top, 20)
            
            Image(systemName: audioPlayerDelegate.isPlaying ? "speaker.wave.3.fill" : "speaker.wave.3")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 75, height: 75)
                .foregroundColor(.red)
                .onTapGesture {
                    guard let data = self.sessionManager.receivedData else {
                        alertMessage = "No audio data has been received.\nHas the iPhone sent audio?"
                        showAlert.toggle()
                        
                        print("No audio data received")
                        return
                    }
                    
                    if self.audioPlayerDelegate.isPlaying {
                        self.stopPlaying()
                    } else {
                        self.startPlaying(data: data)
                    }
                }
                .alert(isPresented: $showAlert) {
                    Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                }
            
            Text(audioPlayerDelegate.isPlaying ? "Playing..." : "Tap to play")
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text("[© 2023 Siddharth Praveen Bharadwaj](https://sid110307.github.io/Sid110307)")
                .font(.footnote)
                .foregroundColor(.gray)
                .accentColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .padding()
        }
        .onDisappear {
            self.stopPlaying()
        }
    }
    
    func startPlaying(data: Data) {
        do {
            let fileUrl = try FileManager.default
                .url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("voicelink.wav")
            
            try data.write(to: fileUrl)
            
            audioPlayer = try AVAudioPlayer(contentsOf: fileUrl)
            audioPlayer?.delegate = audioPlayerDelegate
            
            guard let audioPlayer = audioPlayer else {
                alertMessage = "Failed to create audio player."
                showAlert.toggle()
                
                print("Failed to create audio player.")
                return
            }
            
            audioPlayer.play()
            audioPlayerDelegate.isPlaying = true
        } catch {
            alertMessage = "Failed to play audio: \(error.localizedDescription)"
            showAlert.toggle()
            
            print("Failed to play audio: \(error.localizedDescription)")
            return
        }
    }
    
    func stopPlaying() {
        audioPlayer?.stop()
        audioPlayerDelegate.isPlaying = false
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
