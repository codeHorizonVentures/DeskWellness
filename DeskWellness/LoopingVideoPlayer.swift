
import SwiftUI
import AVKit
import CoreMedia

// MARK: - Video Player

struct LoopingVideoPlayer: View {
    let videoName: String
    @State private var player: AVPlayer?
    
    var body: some View {
        VideoPlayer(player: player)
            .aspectRatio(contentMode: .fill) // Fill the frame
            .onAppear {
                setupPlayer()
            }
            .onDisappear {
                player?.pause()
            }
    }
    
    private func setupPlayer() {
        // Load video from Asset Catalog
        guard let dataAsset = NSDataAsset(name: videoName) else {
            print("Video asset not found: \(videoName)")
            return
        }
        
        // Write data to a temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(videoName).mp4")
        do {
            try dataAsset.data.write(to: tempURL)
        } catch {
            print("Error writing video data: \(error)")
            return
        }
        
        let item = AVPlayerItem(url: tempURL)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true // Mute by default
        player.actionAtItemEnd = .none // Prevent pausing at end
        
        // Loop logic
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main) { _ in
                player.seek(to: .zero)
                player.play()
            }
        
        player.play()
        self.player = player
    }
}
