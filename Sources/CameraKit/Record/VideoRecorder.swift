//
//  ImageAnimator.swift
//  AppPlayground
//
//  Created by Michel-André Chirita on 24/08/2024.
//

import Foundation
@preconcurrency import UIKit
import Photos
import Queue

final class VideoRecorder {
    
    private let settings: RenderSettings
    private let videoWriter: VideoWriter
    private let queue = AsyncQueue() //attributes: [.concurrent])
    private var context: CIContext

    init(renderSettings: RenderSettings, context: CIContext) {
        self.settings = renderSettings
        self.context = context
        self.videoWriter = VideoWriter(renderSettings: settings)
    }
    
    func initialize(completion: @escaping ()->Void) {
        queue.addBarrierOperation { [settings, videoWriter] in
            VideoRecorder.removeFileAtURL(fileURL: settings.outputURL)
            try videoWriter.initialize()
            completion()
        }
    }
    
    func startRecord(sourceTime: CMTime, completion: @escaping ()->Void) {
        queue.addBarrierOperation { [weak self] in
            guard let self else { return }
            try videoWriter.start(sourceTime: sourceTime)
            completion()
        }
    }
    
    func addToRecord(image: CIImage, presentationTime: CMTime, applyFilter: ((CIImage)throws->CIImage)?) {
        queue.addOperation { [weak self] in
            guard let self else { return }
            do {
                try await videoWriter.render(image: image,
                                             time: presentationTime,
                                             context: context,
                                             applyFilter: applyFilter)
            } catch {
                print("ERROR: \(error)")
            }
        }
    }
    
    func endRecord() async throws -> URL {
        let task = queue.addBarrierOperation { [weak self] in
            guard let self else { return false }
            await videoWriter.finish()
            return true
        }
        if await task.value {
            return settings.outputURL
        } else {
            throw VideoRecorderError.unknown
        }
    }
    
    // MARK: - Utilities (move elsewhere ?)
    
    static func saveToLibrary(videoURL: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else { return }
        
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        }
    }
    
    static func removeFileAtURL(fileURL: URL) {
        try? FileManager.default.removeItem(atPath: fileURL.path)
    }
    
    enum VideoRecorderError: Error {
        case unknown
    }
}
