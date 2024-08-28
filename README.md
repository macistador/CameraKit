# CameraKit
Camera framework facilitating capturing photo &amp; video on iOS  

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Credits](#credits)
- [License](#license)

## Features

- [x] Video capture
- [x] Photo capture
- [x] Supports filters
- [x] Builtin background removal filter with fast preview & accurate recording quality
- [x] Builtin SwiftUI preview view
- [x] Lightweight

## Requirements

- iOS 15.0+
- Xcode 12.0+
- Swift 5.5+

## Installation

### SwiftPackageManager

```swift
dependencies: [
    .package(url: "https://github.com/macistador/CameraKit", from: "0.0.1")
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

## Credits

CameraKit is developed and maintained by Michel-André Chirita. You can follow me on Twitter at @Macistador for updates.

## License

AChain is released under the MIT license. [See LICENSE](https://github.com/macistador/achain/blob/master/LICENSE) for details.
