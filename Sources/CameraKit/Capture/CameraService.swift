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
    private var currentCameraDeviceInput: AVCaptureDeviceInput? {
        return captureSession.inputs
            .compactMap { $0 as? AVCaptureDeviceInput }
            .first(where: { $0.device.hasMediaType(.video) })
    }
    private var currentCameraDevice: AVCaptureDevice? {
        return currentCameraDeviceInput?.device
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
        guard let camera = retrieveCamera() else {
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
        if isMicEnabled {
            let micDevice: AVCaptureDevice?
            if #available(iOS 17.0, *) {
                micDevice = AVCaptureDevice.default(.microphone, for: .audio, position: .unspecified)
            } else {
                micDevice = AVCaptureDevice.default(.builtInMicrophone, for: .audio, position: .unspecified)
            }
            guard let micDevice,
                  let micDeviceInput = try? AVCaptureDeviceInput(device: micDevice),
                  captureSession.canAddInput(micDeviceInput) else {
                throw CameraServiceError.initializationError
            }
        }
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
        case .video:
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

    func restartCaptureSession() {
        guard !captureSession.isRunning else { return }
        startSessionIfNeeded()
    }

    func stopCaptureSessionIfNeeded() {
        guard captureSession != nil else { return }
        captureSession.stopRunning()
    }

    @discardableResult
    func zoom(to factor: Double) throws -> Double {
        guard let currentCameraDevice else {
            throw CameraServiceError.currentCameraNotSet
        }
        let factor = min(
            max(factor, currentCameraDevice.minAvailableVideoZoomFactor),
            currentCameraDevice.activeFormat.videoMaxZoomFactor
        )
        try currentCameraDevice.lockForConfiguration()
        defer { currentCameraDevice.unlockForConfiguration() }
        currentCameraDevice.videoZoomFactor = factor

        return factor
    }

    func takePicture() {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        photoOuput.capturePhoto(with: settings, delegate: self)
    }

    func switchCamera() throws {
        cameraDirection = switch cameraDirection {
        case .front:
                .back
        case .back:
                .front
        }
        if captureSession.isRunning {
            guard let currentCameraDeviceInput,
                  let newCameraDevice = retrieveCamera() else {
                throw CameraServiceError.currentCameraNotSet
            }
            captureSession.beginConfiguration()
            defer { captureSession.commitConfiguration() }
            captureSession.removeInput(currentCameraDeviceInput)
            guard let newCameraDeviceInput = try? AVCaptureDeviceInput(device: newCameraDevice),
                  captureSession.canAddInput(newCameraDeviceInput) else {
                throw CameraServiceError.initializationError
            }
            captureSession.addInput(newCameraDeviceInput)
        } else {
            try setupCameraSession()
        }
    }

    func switchTorch() throws {
        guard let device = currentCameraDevice else { throw CameraServiceError.currentCameraNotSet }
        torchMode = torchMode == .off ? .on : .off
        try updateTorch(for: device, torchMode: torchMode)
    }

    // MARK: - Private methods
    private func retrieveCamera() -> AVCaptureDevice? {
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

    private func startSessionIfNeeded() {
        guard captureSession != nil else { return }
        DispatchQueue.global(qos: .userInteractive).async {
            self.captureSession.startRunning()
        }
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
