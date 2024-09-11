//
//  CameraViewController.swift
//  AppPlayground
//
//  Created by Michel-André Chirita on 26/08/2024.
//

import Foundation
import UIKit
import AVFoundation
import MetalKit

public enum TorchMode: String {
    case on
    case off
}

public enum CameraDirection: String {
    case front
    case back
}

public enum CaptureMode {
    case photo
    case video(resolution: VideoResolution, frameRate: Double)
}

public enum VideoFilter {
    case none
    case removeBackground
}

public enum VideoResolution {
    case sd
    case hd
    case fullHd
    case uhd4K
    case custom(width: Double, height: Double)
    
    var preset: AVCaptureSession.Preset {
        return switch self {
        case .sd: .vga640x480
        case .hd: .hd1280x720
        case .fullHd: .hd1920x1080
        case .uhd4K: .hd4K3840x2160
        case .custom: .vga640x480
        }
    }
    
    var size: CGSize {
        return switch self {
        case .sd: CGSize(width: 480, height: 640)
        case .hd: CGSize(width: 720, height: 1280)
        case .fullHd: CGSize(width: 1080, height: 1920)
        case .uhd4K: CGSize(width: 2160, height: 3840)
        case .custom(let width, let height): CGSize(width: width, height: height)
        }
    }

}

public final class CameraViewController: UIViewController {
    
    enum State {
        case initializing
        case idle
        case readyToRecord
        case recording
        case saving
    }
    
    private weak var delegate: CameraSessionDelegate?
    private var state: State = .initializing
    private var videoFilter: VideoFilter
    private var cameraService: CameraService
    private var videoRecorder: VideoRecorder?
    private let segmentationService = SegmentationServiceImpl()
    private let captureMode: CaptureMode
    private var context: CIContext?
    private var metalDevice: MTLDevice!
    private var metalCommandQueue: MTLCommandQueue!
    private var cameraView: MTKView?
    private var currentCIImage: CIImage? { didSet { cameraView?.draw() } }
    private var firstFrameImage: CIImage?
    
    // MARK: - View lifecycle
    
    public init(captureMode: CaptureMode, cameraDirection: CameraDirection, isMicEnabled: Bool, videoFilter: VideoFilter = .none, delegate: CameraSessionDelegate) {
        self.videoFilter = videoFilter
        self.delegate = delegate
        self.captureMode = captureMode
        self.cameraService = CameraService(captureMode: captureMode,
                                           cameraDirection: cameraDirection,
                                           isMicEnabled: isMicEnabled)
        super.init(nibName: nil, bundle: nil)
        cameraService.delegate = self
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupCameraView()
        setupMetal()
        do {
            try cameraService.setupCameraSession()
        } catch {
            delegate?.failed(withError: error)
        }
    }
    
    // MARK: UIKit / Metal methods
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cameraView?.frame = view.bounds
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        restartCaptureSession()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        screenNotVisible()
    }
    
    private func setupCameraView() {
        let cameraView = MTKView()
        view.addSubview(cameraView)
        cameraView.frame = view.frame
        self.cameraView = cameraView
        cameraView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        cameraView.colorPixelFormat = .bgra10_xr
        cameraView.layer.isOpaque = false
    }
    
    private func setupMetal() {
        metalDevice = MTLCreateSystemDefaultDevice()
        metalCommandQueue = metalDevice.makeCommandQueue()
        cameraView?.device = metalDevice
        cameraView?.isPaused = true
        cameraView?.enableSetNeedsDisplay = false
        cameraView?.delegate = self
        cameraView?.framebufferOnly = false
        context = CIContext(mtlDevice: metalDevice)
    }
    
    // MARK: - Private functions
    
    private func screenNotVisible() {
        cameraService.stopCaptureSessionIfNeeded()
        if state == .recording {
            Task {
                _ = try? await videoRecorder?.endRecord()
                state = .idle
            }
        }
    }
        
    private func setupWriter() {
        guard let context, case let .video(resolution, _) = captureMode else { return }
        self.setState(to: .initializing)
        let settings = RenderSettings(size: resolution.size,
                                      videoFilename: "Temporary_Camera_Recording")
        videoRecorder = VideoRecorder(renderSettings: settings, context: context)
        videoRecorder?.initialize { [weak self] in
            guard let self else { return }
            self.setState(to: .readyToRecord)
        }
    }
    
    private func setState(to newState: State) {
        self.state = newState
        
        DispatchQueue.main.async {
            switch self.state {
            case .idle, .saving, .initializing: break
            case .readyToRecord: self.delegate?.isReadyToRecord()
            case .recording: self.delegate?.didStartRecording()
            }
        }
    }
}

extension CameraViewController: CameraSessionController {
    
    public func switchCamera() {
        do {
            try cameraService.switchCamera()
        } catch {
            delegate?.failed(withError: error)
        }
    }
    
    public func switchTorch() {
        do {
            try cameraService.switchTorch()
        } catch {
            delegate?.failed(withError: error)
        }
    }
    
    public func restartCaptureSession() {
        cameraService.restartCaptureSession()
        setupWriter()
    }
    
    public func takePictureTapped() {
        cameraService.takePicture()
    }
    
    public func recordVideoTapped() {
        if state == .readyToRecord {
            startRecording()
        }
        else if state == .recording {
            stopRecording()
        }
    }
    
    private func startRecording() {
        guard let time = cameraService.captureSession?.synchronizationClock?.time else { return }
        state = .initializing
        firstFrameImage = nil
        Task.detached(priority: .background) { [self, videoRecorder] in
            videoRecorder?.startRecord(sourceTime: time) {
                Task {
                    await self.setState(to: .recording)
                }
            }
        }
    }
    
    private func stopRecording(completion: (()->Void)? = nil) {
        state = .saving
        Task.detached(priority: .userInitiated) { [videoRecorder, delegate, firstFrameImage] in
            guard let videoUrl = try await videoRecorder?.endRecord(),
                  let firstFrameImage
            else {
                DispatchQueue.main.async {
                    delegate?.failed(withError: CameraControllerError.recordFailed)
                }
                await self.setState(to: .idle)
                return
            }
            let thumbnailImage = UIImage(ciImage: firstFrameImage)
            DispatchQueue.main.async {
                delegate?.didCapture(videoURL: videoUrl, thumbnailImage: thumbnailImage)
            }
        }
    }
}

extension CameraViewController: CameraServiceDelegate {
    
    func photoCaptureOutput(imageData: Data) {
        delegate?.didCapture(imageData: imageData)
    }

    func videoCaptureOutput(sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = sampleBuffer.imageBuffer, case let .video(resolution, _) = captureMode else { return }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            .cropped(to: CGRect(origin: .zero,
                                size: resolution.size))

        // Preview image
        let filteredImage = filterIfNeeded(image: ciImage, forPreview: true)
        self.currentCIImage = filteredImage ?? ciImage

        // Record if started
        guard state == .recording else { return }
        Task {
            guard let filteredImage = filterIfNeeded(image: ciImage, forPreview: false)
            else { return }
            videoRecorder?.addToRecord(image: filteredImage,
                                       presentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
                                       applyFilter: nil)
            if firstFrameImage == nil {
                self.firstFrameImage = filteredImage
            }
        }
    }
    
    func filterIfNeeded(image: CIImage, forPreview isPreview: Bool) -> CIImage? {
        if videoFilter == .removeBackground,
            let resultImage = try? segmentationService.segmentPerson(in: image, isPreview: isPreview) {
            return resultImage
        } else {
            return image
        }
    }
}

extension CameraViewController: MTKViewDelegate {
    
    public func draw(in view: MTKView) {
        guard let commandBuffer = metalCommandQueue.makeCommandBuffer() else { return }
        guard let ciImage = currentCIImage, let cameraView else { return }
        guard let currentDrawable = view.currentDrawable else { return }
        let drawSize = cameraView.drawableSize
//        let imageRatio = ciImage.extent.width / ciImage.extent.height
        let scaleX = drawSize.width / ciImage.extent.width
        let scaleY = scaleX //scaleX * imageRatio //drawSize.height / ciImage.extent.height
                
        let newImage = ciImage.transformed(by: .init(scaleX: scaleX, y: scaleY))
        self.context?.render(newImage,
                             to: currentDrawable.texture,
                             commandBuffer: commandBuffer,
                             bounds: newImage.extent,
                             colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!)

        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}

enum CameraControllerError: Error {
    case initializationFailed
    case recordFailed
}
