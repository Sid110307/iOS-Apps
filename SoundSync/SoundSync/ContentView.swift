import AVFoundation
import MultipeerConnectivity
import SwiftUI

class AudioStreamer: NSObject, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate, MCSessionDelegate {
    var browser: MCNearbyServiceBrowser!
    var advertiser: MCNearbyServiceAdvertiser!
    var session: MCSession!
    
    @Published var statusMessage = ""
    private var audioEngine: AVAudioEngine!
    
    override init() {
        super.init()
        configureAudioEngine()
        
        let peerID = MCPeerID(displayName: UIDevice.current.name)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: "sound-sync")
        browser.delegate = self
        
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: "sound-sync")
        advertiser.delegate = self
        
        startBrowsing()
        statusMessage = "Listening for peers..."
    }
    
    private func configureAudioEngine() {
        audioEngine = AVAudioEngine()
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            guard !self!.session.connectedPeers.isEmpty else { return }
            self?.sendAudioBuffer(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error.localizedDescription)")
            statusMessage = "Failed to start audio engine: \(error.localizedDescription)"
        }
    }
    
    func startStreaming() {
        startAdvertising()
        statusMessage = "Advertising..."
    }
    
    func stopStreaming() {
        stopAdvertising()
        statusMessage = "Stopped advertising"
    }
    
    func startBrowsing() { browser.startBrowsingForPeers() }
    func stopBrowsing() { browser.stopBrowsingForPeers() }
    
    func startAdvertising() { advertiser.startAdvertisingPeer() }
    func stopAdvertising() { advertiser.stopAdvertisingPeer() }
    
    func connect(to peer: MCPeerID) { browser.invitePeer(peer, to: session, withContext: nil, timeout: 10) }
    func disconnect() { session.disconnect() }
    
    func sendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let data = bufferToData(buffer) else { return }
        
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("Failed to send audio buffer: \(error.localizedDescription)")
            statusMessage = "Failed to send audio buffer: \(error.localizedDescription)"
        }
    }
    
    private func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data? {
        guard let audioBuffer = buffer.audioBufferList.pointee.mBuffers.mData else { return nil }
        return Data(bytes: audioBuffer, count: Int(buffer.frameLength) * Int(buffer.format.streamDescription.pointee.mBytesPerFrame))
    }
    
    private func dataToBuffer(_ data: Data) -> AVAudioPCMBuffer? {
        let audioFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        let frameCapacity = AVAudioFrameCount(data.count) / audioFormat.streamDescription.pointee.mBytesPerFrame
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCapacity) else { return nil }
        buffer.frameLength = frameCapacity
        
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        
        data.withUnsafeBytes { rawBufferPointer in
            guard let address = rawBufferPointer.baseAddress else { return }
            audioBuffer.mData?.copyMemory(from: address, byteCount: Int(audioBuffer.mDataByteSize))
        }
        
        return buffer
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        statusMessage = "Found peer: \(peerID.displayName)"
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        statusMessage = "Lost peer: \(peerID.displayName)"
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        statusMessage = "Failed to start browsing: \(error.localizedDescription)"
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        statusMessage = "Received invitation from: \(peerID.displayName)"
        invitationHandler(true, session)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        statusMessage = "Failed to start advertising: \(error.localizedDescription)"
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        statusMessage = "Peer \(peerID.displayName) changed state to \(state.rawValue)"
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        statusMessage = "Received data from: \(peerID.displayName)"
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        statusMessage = "Received stream from: \(peerID.displayName)"
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        statusMessage = "Started receiving resource from: \(peerID.displayName)"
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        statusMessage = "Finished receiving resource from: \(peerID.displayName)"
    }
}

class AudioStreamerViewModel: ObservableObject {
    private let audioStreamer = AudioStreamer()
    
    var statusMessage: String {
        audioStreamer.statusMessage
    }
}

struct ContentView: View {
    @State private var isConnected = false
    @State private var connectionText = "Not connected"
    @State private var volume: Float = 0.5
    @State private var isMicrophoneOn = false
    @State private var selectedDevice: MCPeerID?
    
    @StateObject private var audioStreamerViewModel = AudioStreamerViewModel()
    private let audioStreamer = AudioStreamer()
    
    var body: some View {
        VStack {
            HStack {
                Text("SoundSync")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                Spacer()
                
                Button(action: {
                    // TODO:
                }) {
                    Image(systemName: "info.circle")
                        .font(.title)
                }
                .padding()
            }
            Spacer()
            
            List(audioStreamer.session.connectedPeers, id: \.self) { device in
                Button(action: {
                    self.selectedDevice = device
                }) {
                    Text(device.displayName)
                }
            }
            
            HStack {
                Button(action: {
                    if self.isConnected {
                        self.audioStreamer.disconnect()
                        self.connectionText = "Not connected"
                    } else {
                        guard self.selectedDevice != nil else { return }
                        
                        self.audioStreamer.connect(to: self.selectedDevice!)
                        self.connectionText = "Connected to \(self.selectedDevice!.displayName)"
                    }
                    self.isConnected.toggle()
                }) {
                    Text(isConnected ? "Disconnect" : "Connect")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(40)
                        .padding(10)
                }
                
                if isConnected {
                    Button(action: {
                        self.isMicrophoneOn.toggle()
                    
                        if self.isMicrophoneOn {
                            self.audioStreamer.startStreaming()
                        } else {
                            self.audioStreamer.stopStreaming()
                        }
                    }) {
                        Image(systemName: isMicrophoneOn ? "mic" : "mic.slash")
                            .font(.title)
                            .foregroundColor(isMicrophoneOn ? .red : .green)
                            .padding()
                    }
                }
            }

            Text(connectionText)
                .font(.title)
                .foregroundColor(isConnected ? .green : .red)
                .fontWeight(.bold)
                .padding()
            
            Spacer()
            HStack {
                Image(systemName: "speaker.wave.2")
                    .font(.title)
                    .padding()
                    .padding(.trailing, -20)
                Slider(value: $volume, in: 0 ... 1)
                    .padding()
            }
            
            Text(audioStreamerViewModel.statusMessage)
                .font(.subheadline)
                .fontWeight(.bold)
                .padding()
        }
    }
}

struct ContentViewPreviews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
