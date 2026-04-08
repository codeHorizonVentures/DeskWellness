import SwiftUI
import AVFoundation
import AVKit

private final class LoopingVideoPlayerModel: ObservableObject {
    let player = AVQueuePlayer()

    private var looper: AVPlayerLooper?

    init(videoName: String) {
        player.isMuted = true
        player.actionAtItemEnd = .none
        player.preventsDisplaySleepDuringVideoPlayback = false
        configure(videoName: videoName)
    }

    deinit {
        player.pause()
        player.removeAllItems()
        looper?.disableLooping()
        looper = nil
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    private func configure(videoName: String) {
        guard let url = Self.cachedVideoURL(named: videoName) else { return }

        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: item)
    }

    private static func cachedVideoURL(named videoName: String) -> URL? {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ResetMinuteVideos",
            isDirectory: true
        )

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            #if DEBUG
            print("Error creating temp video directory: \(error)")
            #endif
            return nil
        }

        let fileURL = directory.appendingPathComponent("\(videoName).mp4")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        guard let dataAsset = NSDataAsset(name: videoName) else {
            #if DEBUG
            print("Video asset not found: \(videoName)")
            #endif
            return nil
        }

        do {
            try dataAsset.data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            #if DEBUG
            print("Error writing video data: \(error)")
            #endif
            return nil
        }
    }
}

struct LoopingVideoPlayer: View {
    let videoName: String

    @StateObject private var model: LoopingVideoPlayerModel

    init(videoName: String) {
        self.videoName = videoName
        _model = StateObject(wrappedValue: LoopingVideoPlayerModel(videoName: videoName))
    }

    var body: some View {
        VideoPlayer(player: model.player)
            .aspectRatio(contentMode: .fill)
            .allowsHitTesting(false)
            .onAppear {
                model.play()
            }
            .onDisappear {
                model.pause()
            }
    }
}
