//
//  DemoCameraViewModel.swift
//  AppPlayground
//
//  Created by Michel-André Chirita on 28/08/2024.
//

import Foundation
import UIKit
import CameraKit

@Observable
final class DemoCameraViewModel {
    
    enum State {
        case preparing
        case readyToRecord
        case recording
        case failed
    }
    
    var state: State = .preparing
    var cameraController: CameraSessionController?
    var videoUrl: URL?
    var presentPreview = false
    var countdown: Int = 1
    var errorMessage: String?
    private var timer: Timer?
    
    func startRecording() {
        state = .preparing
        cameraController?.recordVideoTapped()
    }
    
    private func startCountdown() {
        countdown = 1
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard let self else { return }
                self.countdown += 1
                if self.countdown > 3 {
//                    DispatchQueue.main.async {
                        self.stopRecording()
//                    }
                }
            }
        }
    }
    
    func stopRecording() {
        timer?.invalidate()
        timer = nil
        self.state = .preparing
        cameraController?.recordVideoTapped()
    }
}

extension DemoCameraViewModel: CameraSessionDelegate {
    
    func isReadyToRecord() {
        self.state = .readyToRecord
    }
    
    func didStartRecording() {
        self.state = .recording
        self.startCountdown()
    }
    
    func didCapture(videoURL: URL, thumbnailImage: UIImage) {
        self.videoUrl = videoURL
        presentPreview = true
        self.state = .preparing
    }
    
    func didCapture(imageData: Data) {}
    
    func failed(withError error: any Error) {
        self.state = .failed
        self.errorMessage = error.localizedDescription
    }
}
