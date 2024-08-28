//
//  RecordP.swift
//  AppPlayground
//
//  Created by Michel-André Chirita on 24/08/2024.
//

import AVFoundation
import UIKit
import Photos

struct RenderSettings {
    
    var size : CGSize = .zero
    var fps: Int32 = 24   // frames per second
    var avCodecKey = AVVideoCodecType.hevcWithAlpha // or h264 when no filter ?
    var videoFilename = "render"
    var videoFilenameExt = "mp4"
    
    var outputURL: URL {
        let fileManager = FileManager.default
        if let tmpDirURL = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            return tmpDirURL.appendingPathComponent(videoFilename).appendingPathExtension(videoFilenameExt)
        }
        fatalError("URLForDirectory() failed")
    }
    
}
