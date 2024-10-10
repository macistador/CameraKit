//
//  DemoCameraViewController.swift
//  SampleApp
//
//  Created by Michel-André Chirita on 29/08/2024.
//

import UIKit
import CameraKit

class DemoCameraViewController: UIViewController {

    private var cameraController: CameraViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    private func setupCamera() {
        let cameraViewController = CameraViewController(
            captureMode: .photo,
            cameraDirection: .back,
            isMicEnabled: false,
            delegate: self
        )
        self.cameraController = cameraViewController
        addChild(cameraViewController)
        cameraViewController.view.frame = view.frame
        view.addSubview(cameraViewController.view)
        cameraViewController.didMove(toParent: self)
    }
}

extension DemoCameraViewController: CameraSessionDelegate {

    func isReadyToRecord() {}

    func didStartRecording() {}

    func didCapture(imageData: Data) {}

    func didCapture(videoURL: URL, thumbnailImage: UIImage) {}

    func failed(withError error: Error) {}
}
