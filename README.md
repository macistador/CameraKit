# CameraKit
Camera framework facilitating capturing photo &amp; video on iOS  

<p align="center">
  <img src="https://github.com/macistador/CameraKit/blob/main/IconCameraKit.png" width="300" height="300"/>
</p>


- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Other packages](#other-packages)
- [Credits](#credits)
- [License](#license)

## Features

- [x] Video capture
- [x] Photo capture
- [x] Supports filters
- [x] Builtin background removal filter with fast preview & accurate recording quality
- [x] Builtin SwiftUI preview view
- [x] Lightweight

<p align="center">
  <img src="https://github.com/macistador/CameraKit/blob/main/demo.gif" />
</p>

## Requirements

- iOS 15.0+
- Xcode 12.0+
- Swift 5.5+

## Installation

### SwiftPackageManager

```swift
dependencies: [
    .package(url: "https://github.com/macistador/CameraKit", from: "0.0.2")
]
```

## Usage

### Preview

With __SwiftUI__
```swift
        VStack {
            CameraPickerView(cameraSessionDelegate: viewModel,
                             captureMode: .video,
                             cameraDirection: .front,
                             captureResolution: .fullHd,
                             videoFilter: .removeBackground) { controller in
                cameraController = controller
            }
            
            Circle()
                .fill(.red)
                .frame(width: 70, height: 70)
                .onTapGesture {
                    cameraController.recordVideoTapped()
                }
        }
```

With __UIKit__
```swift
    func setupCamera() {
        let cameraViewController = CameraViewController(captureMode: .photo,
                                                        cameraDirection: .back,
                                                        captureResolution: .uhd4K, 
                                                        videoFilter: .none,
                                                        delegate: self)
        self.cameraController = cameraViewController
        addChild(cameraViewController)
        cameraViewController.view.frame = view.frame
        view.addSubview(cameraViewController.view)
        cameraViewController.didMove(toParent: self)
    }
```

### Callbacks

Your object needs to conforms __CameraSessionDelegate__
```swift
extension DemoCameraView: CameraSessionDelegate {
    
    func isReadyToRecord() {
        self.state = .readyToRecord
    }
    
    func didStartRecording() {
        self.state = .recording
    }
    
    // Video
    func didCapture(videoURL: URL) {
        self.state = .recorded
        self.videoUrl = videoURL
        presentPreview = true
    }
    
    // Photo
    func didCapture(imageData: Data) {
        self.state = .recorded
        self.photoData = imageData
        presentPreview = true
    }
    
    func failed(withError error: any Error) {
        self.state = .failed
        self.errorMessage = error.localizedDescription
    }
}
```

For more details you may take a look at the sample project.

## Other packages

Meanwhile this library works well alone, it is meant to be complementary to the following app bootstrap packages suite: 

- [CoreKit](https://github.com/macistador/CoreKit)
- [DesignKit](https://github.com/macistador/DesignKit)
- [VisualKit](https://github.com/macistador/VisualKit)
- [MediasKit](https://github.com/macistador/MediasKit)
- [CameraKit](https://github.com/macistador/CameraKit)
- [PermissionsKit](https://github.com/macistador/PermissionsKit)
- [SocialKit](https://github.com/macistador/SocialKit)
- [AnalyzeKit](https://github.com/macistador/AnalyzeKit)
- [IntelligenceKit](https://github.com/macistador/IntelligenceKit)
- [AdsKit](https://github.com/macistador/AdsKit)
- [PayKit](https://github.com/macistador/PayKit)

## Credits

CameraKit is developed and maintained by Michel-André Chirita. You can follow me on Twitter at @Macistador for updates.

## License

CameraKit is released under the MIT license. [See LICENSE](https://github.com/macistador/CameraKit/blob/master/LICENSE) for details.
