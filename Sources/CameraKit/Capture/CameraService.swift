//
//  CameraService.swift
//  AppPlayground
//
//  Created by Michel-André Chirita on 28/08/2024.
//

import Foundation
import AVFoundation
import MetalKit

protocol CameraServiceDelegate: AnyObject {
    func photoCaptureOutput(imageData: Data)
    func videoCaptureOutput(sampleBuffer: CMSampleBuffer)
}

final class CameraService: NSObject {
    
    weak var delegate: CameraServiceDelegate?
    private var captureMode: CaptureMode
    /*private*/ let captureResolution: CaptureResolution
    private var torchMode: TorchMode = .off
    private var cameraDirection: CameraDirection = .front
//    private var cameraOrientation: CameraOrientation = .portrait // TODO: to implement

    /*private*/ var cameraCaptureSession: AVCaptureSession!
    private var cameraCaptureInput: AVCaptureInput!
    private var cameraCapturePhotoOutput: AVCapturePhotoOutput!
    private var cameraCaptureVideoOutput: AVCaptureVideoDataOutput!
    private var currentCamera: AVCaptureDevice?
    
    init(captureMode: CaptureMode, cameraDirection: CameraDirection, captureResolution: CaptureResolution) {
        self.captureMode = captureMode
        self.cameraDirection = cameraDirection
        self.captureResolution = captureResolution
        super.init()
    }
    
    // MARK: - Public methods
    
    func setupCameraSession() throws {
        cameraCaptureSession = AVCaptureSession()
        cameraCaptureSession.beginConfiguration()
        
        if cameraCaptureSession.canSetSessionPreset(captureResolution.preset) {
            cameraCaptureSession.sessionPreset = captureResolution.preset
        } else {
            cameraCaptureSession.sessionPreset = .photo
        }
        
        guard let camera = getCamera(for: cameraDirection) else {
            throw CameraServiceError.cantAccessCameraDevice
        }
        currentCamera = camera
        
        do {
            cameraCaptureInput = try AVCaptureDeviceInput(device: camera)
            cameraCaptureSession.addInputWithNoConnections(cameraCaptureInput)
            
            switch captureMode {
            case .photo:
                cameraCapturePhotoOutput = AVCapturePhotoOutput()
                if #available(iOS 17.0, *) {
                    cameraCapturePhotoOutput.isAutoDeferredPhotoDeliveryEnabled = cameraCapturePhotoOutput.isAutoDeferredPhotoDeliverySupported
                }
                if cameraCaptureSession.canAddOutput(cameraCapturePhotoOutput) {
                    cameraCaptureSession.addOutput(cameraCapturePhotoOutput)
                }
                
            case .video:
                cameraCaptureVideoOutput = AVCaptureVideoDataOutput()
    //            cameraCaptureVideoOutput.alwaysDiscardsLateVideoFrames = true
                cameraCaptureVideoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .default))
                if cameraCaptureSession.canAddOutput(cameraCaptureVideoOutput) {
                    cameraCaptureSession.addOutput(cameraCaptureVideoOutput)
                    cameraCaptureVideoOutput.connection(with: .video)?.videoOrientation = .portrait
                    cameraCaptureVideoOutput.connection(with: .video)?.isVideoMirrored = cameraDirection == .front
                }
            }
        } catch {
            throw CameraServiceError.initializationError(error)
        }
        
        cameraCaptureSession.commitConfiguration()
        currentCamera?.set(frameRate: 24)

        startSessionIfNeeded()
    }
    
    private func startSessionIfNeeded() {
        guard cameraCaptureSession != nil else { return }
        DispatchQueue.global(qos: .userInteractive).async {
            self.cameraCaptureSession.startRunning()
        }
    }
    
    func restartCaptureSession() {
        guard !cameraCaptureSession.isRunning else { return }
        startSessionIfNeeded()
    }
    
    func stopCaptureSessionIfNeeded() {
        guard cameraCaptureSession != nil else { return }
        cameraCaptureSession.stopRunning()
    }
    
    func takePicture() {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        cameraCapturePhotoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func switchCamera() throws {
        cameraDirection = cameraDirection == .front ? .back : .front
        try setupCameraSession()
    }
    
    func switchTorch() throws {
        guard let device = currentCamera else { throw CameraServiceError.currentCameraNotSet }
        torchMode = torchMode == .off ? .on : .off
        try updateTorch(for: device, torchMode: torchMode)
    }
    
    // MARK: - Private methods
    
    private func getCamera(for cameraDirection: CameraDirection) -> AVCaptureDevice? {
        let position: AVCaptureDevice.Position
        switch cameraDirection {
        case .front: position = .front
        case .back: position = .back
        }
        
        let builtInDualCamera = AVCaptureDevice.default(.builtInDualCamera,
                                                        for: .video,
                                                        position: position)
        
        let builtInWideAngleCamera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                             for: .video,
                                                             position: position)
        
        return builtInDualCamera ?? builtInWideAngleCamera ?? nil
    }
    
    // FIXME: doesn't work ??
    private func updateTorch(for device: AVCaptureDevice, torchMode: TorchMode) throws {
        do {
            try device.lockForConfiguration()
            if (device.torchMode == AVCaptureDevice.TorchMode.on && torchMode == .off) {
                device.torchMode = AVCaptureDevice.TorchMode.off
            } else {
                guard device.isTorchModeSupported(.on) else { return }
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            }
            device.unlockForConfiguration()
        } catch {
            throw CameraServiceError.torchFailed(error)
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard output == cameraCapturePhotoOutput,
              let photoData = photo.fileDataRepresentation()
        else { return }
        delegate?.photoCaptureOutput(imageData: photoData)
        cameraCaptureSession.stopRunning()
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        delegate?.videoCaptureOutput(sampleBuffer: sampleBuffer)
    }
}

private extension AVCaptureDevice {
    func set(frameRate: Double) {
        guard let range = activeFormat.videoSupportedFrameRateRanges.first,
              range.minFrameRate...range.maxFrameRate ~= frameRate
        else {
//            print("Requested FPS is not supported by the device's activeFormat !")
            return
        }
        
        do { try lockForConfiguration()
            activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
            activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
            unlockForConfiguration()
        } catch {
//            print("LockForConfiguration failed with error: \(error.localizedDescription)")
        }
    }
}

enum CameraServiceError: Error {
    case cantAccessCameraDevice
    case initializationError(Error)
    case currentCameraNotSet
    case torchFailed(Error)
}
