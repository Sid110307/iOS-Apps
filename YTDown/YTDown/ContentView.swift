import SwiftUI
import YouTubePlayerKit

enum YouTubePlayerHelper {
    static func extractVideoId(from url: String) -> String? {
        let pattern = "^(?:https?:\\/\\/)?(?:www\\.|m\\.)?youtu(?:\\.be\\/|be\\.com\\/watch\\?v=|be\\.com\\/embed\\/|be\\.com\\/v\\/|be\\.com\\/watch\\?feature=player_embedded&v=)([\\w-]{11})(?:(?:\\?t=[\\dhms]+s)?|(?:&amp;t=[\\dhms]+s)?)?$"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(location: 0, length: url.count)
        guard let match = regex.firstMatch(in: url, options: [], range: range) else {
            return nil
        }
        
        return (url as NSString).substring(with: match.range(at: 1))
    }
    
    static func videoURL(for videoID: String, completion: @escaping (Result<String, YouTubePlayer.APIError>) -> Void) {
        let player = YouTubePlayer(source: YouTubePlayer.Source.video(id: videoID))
        player.play()
        
        player.getVideoURL(completion: completion)
    }
}

struct ContentView: View {
    @State private var youtubeURL: String = ""
    @State var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        VStack {
            Text("YTDown")
                .font(.largeTitle)
                .padding()
            Spacer()
            
            TextField("Enter YouTube URL", text: $youtubeURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding()
            
            Button(action: downloadVideo) {
                Text("Download Video")
                    .font(.title)
                    .foregroundColor(showAlert ? Color.red : Color.blue)
                    .padding()
            }
            .clipShape(Capsule())
            .overlay(Capsule().stroke(showAlert ? Color.red : Color.blue, lineWidth: 2))
            .padding()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertMessage))
        }
    }
    
    func downloadVideo() {
        guard !youtubeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(message: "Please enter a YouTube URL")
            return
        }
        guard let videoID = YouTubePlayerHelper.extractVideoId(from: youtubeURL) else {
            showAlert(message: "Invalid YouTube URL")
            return
        }
        
        YouTubePlayerHelper.videoURL(for: videoID) { result in
            switch result {
                case .success(let videoURL):
                    guard let videoURL = URL(string: videoURL) else {
                        showAlert(message: "Invalid video URL")
                        return
                    }

                    let task = URLSession.shared.downloadTask(with: videoURL) { localURL, _, error in
                        guard let localURL = localURL, error == nil else {
                            showAlert(message: "Error downloading video: \(error?.localizedDescription ?? "")")
                            return
                        }
                            
                        do {
                            let documentsURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                            let fileURL = documentsURL.appendingPathComponent("\(videoID).mp4")
                                
                            try FileManager.default.moveItem(at: localURL, to: fileURL)
                            showAlert(message: "Video downloaded to: \(fileURL.absoluteString)")
                        } catch {
                            showAlert(message: "Error saving video: \(error.localizedDescription)")
                        }
                    }
                        
                    task.resume()
                case .failure(let error):
                    showAlert(message: "Error retrieving video URL: \(error.localizedDescription)")
            }
        }
    }
    
    func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
}

struct ContentViewPreviews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
