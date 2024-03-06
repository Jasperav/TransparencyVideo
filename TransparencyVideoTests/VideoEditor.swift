import AppKit
import AVFoundation
import Foundation
import Photos
import QuartzCore
import OSLog

let logger = Logger()

class VideoEditor {
    func export(
        url: URL,
        outputDir: URL
    ) async {
        let asset = AVURLAsset(url: url)
        let extract = try! await extractData(videoAsset: asset)
    
        try! await exportVideo(outputPath: outputDir, asset: asset, videoComposition: extract)
    }

    private func exportVideo(outputPath: URL, asset: AVAsset, videoComposition: AVMutableVideoComposition) async throws {
        let fileExists = FileManager.default.fileExists(atPath: outputPath.path())

        logger.debug("Output dir: \(outputPath), exists: \(fileExists), render size: \(String(describing: videoComposition.renderSize))")

        if fileExists {
            do {
                try FileManager.default.removeItem(atPath: outputPath.path())
            } catch {
                logger.error("remove file failed")
            }
        }

        let dir = outputPath.deletingLastPathComponent().path()

        logger.debug("Will try to create dir: \(dir)")

        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        var isDirectory = ObjCBool(false)

        guard FileManager.default.fileExists(atPath: dir, isDirectory: &isDirectory), isDirectory.boolValue else {
            logger.error("Could not create dir, or dir is a file")

            fatalError()
        }

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHEVCHighestQualityWithAlpha) else {
            logger.error("generate export failed")

            fatalError()
        }

        exporter.outputURL = outputPath
        exporter.outputFileType = .mov
        exporter.shouldOptimizeForNetworkUse = false
        exporter.videoComposition = videoComposition

        await exporter.export()

        logger.debug("Status: \(String(describing: exporter.status)), error: \(exporter.error)")

        if exporter.status != .completed {
            fatalError()
        }
    }

    private func extractData(videoAsset: AVURLAsset) async throws -> AVMutableVideoComposition {
        guard let videoTrack = try await videoAsset.loadTracks(withMediaType: .video).first else {
            fatalError()
        }

        guard let audioTrack = try await videoAsset.loadTracks(withMediaType: .audio).first else {
            fatalError()
        }

        let composition = AVMutableComposition(urlAssetInitializationOptions: nil)

        guard let compositionVideoTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: videoTrack.trackID) else {
            fatalError()
        }
        guard let compostiionAudioTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: audioTrack.trackID) else {
            fatalError()
        }

        let duration = try await videoAsset.load(.duration)

        try compositionVideoTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: duration), of: videoTrack, at: CMTime.zero)
        try compostiionAudioTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: duration), of: audioTrack, at: CMTime.zero)

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let mainInstruction = AVMutableVideoCompositionInstruction()

        mainInstruction.timeRange = CMTimeRange(start: CMTime.zero, end: duration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        let videoComposition = AVMutableVideoComposition()

        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)

        mainInstruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [mainInstruction]
        
        videoComposition.renderSize = naturalSize
        
        // Adds the iPhone image
        let image = NSImage(contentsOf: Bundle(for: VideoEditor.self).url(forResource: "iPhone", withExtension: ".png")!)!
        let imageLayer = CALayer()

        imageLayer.contents = image
        imageLayer.frame = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        
        let overlayLayer = CALayer()

        overlayLayer.frame = CGRect(origin: CGPoint.zero, size: naturalSize)
        overlayLayer.addSublayer(imageLayer)

        let parentLayer = CALayer()
        let videoLayer = CALayer()

        parentLayer.frame = CGRect(origin: CGPoint.zero, size: naturalSize)
        videoLayer.frame = CGRect(origin: CGPoint.zero, size: naturalSize)

        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlayLayer)

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)

        return videoComposition
    }

}
