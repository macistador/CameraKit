//
//  CameraService.swift
//  AppPlayground
//
//  Created by Michel-André Chirita on 28/08/2024.
//

import AVFoundation

protocol CameraServiceDelegate: AnyObject {
    func photoCaptureOutput(imageData: Data)
    func videoCaptureOutput(sampleBuffer: CMSampleBuffer)
}

enum CameraServiceError: Error {
    case cantAccessCameraDevice
    case initializationError
    case currentCameraNotSet
    case torchFailed(Error)
}

final class CameraService: NSObject {
    weak var delegate: CameraServiceDelegate?
    /*private*/ var captureSession: AVCaptureSession!
    private let captureMode: CaptureMode
    private let isMicEnabled: Bool
    private var torchMode: TorchMode = .off
    private var cameraDirection: CameraDirection = .front
    private var photoOuput: AVCapturePhotoOutput!
    private var videoDataOutput: AVCaptureVideoDataOutput!
    // private var cameraOrientation: CameraOrientation = .portrait // TODO: to implement
    private var currentCamera: AVCaptureDevice? {
        return captureSession.inputs
            .compactMap { $0 as? AVCaptureDeviceInput }
            .first(where: { $0.device.hasMediaType(.video) })?.device
    }

    init(captureMode: CaptureMode, cameraDirection: CameraDirection, isMicEnabled: Bool) {
        self.isMicEnabled = isMicEnabled
        self.captureMode = captureMode
        self.cameraDirection = cameraDirection
        super.init()
    }

    // MARK: - Public methods
    func setupCameraSession() throws {
        captureSession = AVCaptureSession()
        captureSession.beginConfiguration()
        switch captureMode {
        case .photo where captureSession.canSetSessionPreset(.photo):
            captureSession.sessionPreset = .photo
        case let .video(videoResolution, _) where captureSession.canSetSessionPreset(videoResolution.preset):
            captureSession.sessionPreset = videoResolution.preset
        default:
            throw CameraServiceError.initializationError
        }
        guard let camera = retrieveCamera(for: cameraDirection) else {
            throw CameraServiceError.cantAccessCameraDevice // FIXME: Could we merge it this error with initializationError? => Only 1 guard would be cleaner
        }
        if case let .video(_, frameRate) = captureMode, let _ = try? camera.set(frameRate: frameRate) {
            throw CameraServiceError.initializationError
        }
        guard let cameraCaptureInput = try? AVCaptureDeviceInput(device: camera),
              captureSession.canAddInput(cameraCaptureInput) else {
            throw CameraServiceError.initializationError
        }
        captureSession.addInput(cameraCaptureInput)
        switch captureMode {
        case .photo:
            photoOuput = AVCapturePhotoOutput()
            // TODO: check if we should do it once the ouput has been added to the session
            if #available(iOS 17.0, *) {
                photoOuput.isAutoDeferredPhotoDeliveryEnabled = photoOuput.isAutoDeferredPhotoDeliverySupported
            }
            guard captureSession.canAddOutput(photoOuput) else {
                throw CameraServiceError.initializationError
            }
            captureSession.addOutput(photoOuput)
        case let .video(videoResolution, _):
            videoDataOutput = AVCaptureVideoDataOutput()
            guard captureSession.canAddOutput(videoDataOutput) else {
                throw CameraServiceError.initializationError
            }
            // cameraCaptureVideoOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .default))
            captureSession.addOutput(videoDataOutput)
            videoDataOutput.connection(with: .video)?.videoOrientation = .portrait
            videoDataOutput.connection(with: .video)?.isVideoMirrored = cameraDirection == .front
        }
        captureSession.commitConfiguration()
        startSessionIfNeeded()
    }

    private func startSessionIfNeeded() {
        guard captureSession != nil else { return }
        DispatchQueue.global(qos: .userInteractive).async {
            self.captureSession.startRunning()
        }
    }

    func restartCaptureSession() {
        guard !captureSession.isRunning else { return }
        startSessionIfNeeded()
    }

    func stopCaptureSessionIfNeeded() {
        guard captureSession != nil else { return }
        captureSession.stopRunning()
    }

    func takePicture() {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        photoOuput.capturePhoto(with: settings, delegate: self)
    }

    func switchCamera() throws {
        // TODO: do it when the session is runnning
        cameraDirection = cameraDirection == .front ? .back : .front
        try setupCameraSession()
    }

    func switchTorch() throws {
        guard let device = currentCamera else { throw CameraServiceError.currentCameraNotSet }
        torchMode = torchMode == .off ? .on : .off
        try updateTorch(for: device, torchMode: torchMode)
    }

    // MARK: - Private methods

    private func retrieveCamera(for cameraDirection: CameraDirection) -> AVCaptureDevice? {
        let position: AVCaptureDevice.Position = switch cameraDirection {
        case .back:
                .back
        case .front:
                .front
        }
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: position
        ).devices.first
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
        guard output == photoOuput,
              let photoData = photo.fileDataRepresentation()
        else { return }
        delegate?.photoCaptureOutput(imageData: photoData)
        captureSession.stopRunning()
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        delegate?.videoCaptureOutput(sampleBuffer: sampleBuffer)
    }
}

private extension AVCaptureDevice {

    func set(frameRate: Double) throws {
        if let range = activeFormat.videoSupportedFrameRateRanges.first,
           range.minFrameRate...range.maxFrameRate ~= frameRate {
            try lockForConfiguration()
            activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
            activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
            unlockForConfiguration()
        } else {
            // TODO: find the closest supported FPS rate
            return
        }
    }
}
