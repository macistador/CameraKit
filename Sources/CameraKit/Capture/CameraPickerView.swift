//
//  CameraPickerView.swift
//  AppPlayground
//
//  Created by Michel-André Chirita on 26/08/2024.
//

import SwiftUI
import UIKit

public protocol CameraSessionDelegate: AnyObject {
    func isReadyToRecord()
    func didStartRecording()
    func didCapture(imageData: Data)
    func didCapture(videoURL: URL, thumbnailImage: UIImage)
    func failed(withError error: Error)
}

public protocol CameraSessionController: AnyObject {
    func recordVideoTapped()
    func takePictureTapped()
    func switchCamera()
    func switchTorch()
    func restartCaptureSession()
}

public struct CameraPickerView: UIViewControllerRepresentable {
    
    let cameraSessionDelegate: CameraSessionDelegate
    let captureMode: CaptureMode
    let cameraDirection: CameraDirection
    let captureResolution: CaptureResolution
    let videoFilter: VideoFilter
    let cameraSessionController: (CameraSessionController) -> Void
    
    public init(cameraSessionDelegate: CameraSessionDelegate, captureMode: CaptureMode, cameraDirection: CameraDirection, captureResolution: CaptureResolution, videoFilter: VideoFilter = VideoFilter.none, cameraSessionController: @escaping (CameraSessionController) -> Void) {
        self.cameraSessionDelegate = cameraSessionDelegate
        self.captureMode = captureMode
        self.cameraDirection = cameraDirection
        self.captureResolution = captureResolution
        self.videoFilter = videoFilter
        self.cameraSessionController = cameraSessionController
    }
    
    public func makeUIViewController(context: Context) -> CameraViewController {
        let viewController = CameraViewController(captureMode: captureMode,
                                                  cameraDirection: cameraDirection,
                                                  captureResolution: captureResolution,
                                                  videoFilter: videoFilter,
                                                  delegate: cameraSessionDelegate)
        cameraSessionController(viewController)
        return viewController
    }
    
    public func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

//#Preview {
//    CameraPickerView(cameraSessionController: { _ in }, cameraSessionDelegate: any CameraSessionDelegate)
//}
