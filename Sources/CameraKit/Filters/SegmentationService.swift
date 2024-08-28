//
//  SegmentationService.swift
//  AppPlayground
//
//  Created by Michel-André Chirita on 26/08/2024.
//

import Foundation
import Vision
import CoreImage.CIFilterBuiltins
import AVFoundation

protocol SegmentationService {
//    func segmentPerson(in image: CGImage) throws -> CGImage
}

enum SegmentationServiceError: Error {
    case noResult
}

final class SegmentationServiceImpl: SegmentationService {
    private lazy var personSegmentationRequest: VNGeneratePersonSegmentationRequest = {
        let request = VNGeneratePersonSegmentationRequest()
//        request.outputPixelFormat = kCVPixelFormatType_OneComponent32Float
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        request.qualityLevel = .balanced // .accurate // .balanced
        request.revision = VNGeneratePersonSegmentationRequestRevision1
        return request
    }()
    
    private lazy var personSegmentationRequestHD: VNGeneratePersonSegmentationRequest = {
        let request = VNGeneratePersonSegmentationRequest()
//        request.outputPixelFormat = kCVPixelFormatType_OneComponent32Float
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        request.qualityLevel = .accurate // .accurate // .balanced
        request.revision = VNGeneratePersonSegmentationRequestRevision1
        return request
    }()
    
    // MARK: Image
    
    private lazy var facePoseRequest: VNDetectFaceRectanglesRequest = {
        let request = VNDetectFaceRectanglesRequest { [weak self] request, _ in
            guard let face = request.results?.first as? VNFaceObservation else { return }
            // Generate RGB color intensity values for the face rectangle angles.
            //            self?.colors = AngleColors(roll: face.roll, pitch: face.pitch, yaw: face.yaw)
        }
        request.revision = VNDetectFaceRectanglesRequestRevision3
        return request
    }()
    
    private func blend(originalImage: CIImage, maskImage: CIImage) -> CIImage? {
        let maskImage = scale(originalImage: originalImage, maskImage: maskImage)
        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = originalImage
        blendFilter.maskImage = maskImage
        blendFilter.backgroundImage = maskImage.settingAlphaOne(in: .zero)
        return blendFilter.outputImage//?.oriented(.leftMirrored)
    }
    
    private func scale(originalImage: CIImage, maskImage: CIImage) -> CIImage {
        let scaleX = originalImage.extent.width / maskImage.extent.width
        let scaleY = originalImage.extent.height / maskImage.extent.height
        return maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    }
    
    private func createCGImage(from image: CIImage) -> CGImage? {
        return CIContext().createCGImage(image, from: image.extent)
    }
    
    // MARK: Video
    
    private lazy var requestHandler = VNSequenceRequestHandler()
    
//    func truc(sampleBuffer: CMSampleBuffer) throws -> CGImage {
//        let requestHandler2 = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, options: [:])
//        try requestHandler2.perform([personSegmentationRequest])
//        guard let result = personSegmentationRequest.results?.first,
//              let imageBuffer = sampleBuffer.imageBuffer,
//              let blendedImage = blend(originalImage: CIImage(cvImageBuffer: imageBuffer), maskImage: CIImage(cvImageBuffer: result.pixelBuffer)),
//              let cgBlendedImage = createCGImage(from: blendedImage)
//        else { throw SegmentationServiceError.noResult }
//
//        CMSampleBuffer(imageBuffer:  CVImageBuffer(blendedImage), formatDescription: "", sampleTiming: sampleBuffer.)
//        return cgBlendedImage
//    }
    
//    func segmentPerson(in asset: AVAsset) throws -> AVVideoComposition {
//        let filter = CIFilter(name: "CIGaussianBlur")!
//        let composition = AVVideoComposition(asset: asset, applyingCIFiltersWithHandler: { [weak self] request in
//
//            // Clamp to avoid blurring transparent pixels at the image edges
//            //            let source = request.sourceImage.clampedToExtent()
//            //            filter.setValue(source, forKey: kCIInputImageKey)
//            //
//            //            // Vary filter parameters based on video timing
//            //            let seconds = CMTimeGetSeconds(request.compositionTime)
//            //            filter.setValue(seconds * 10.0, forKey: kCIInputRadiusKey)
//            //
//            //            // Crop the blurred output to the bounds of the original image
//            //            let output = filter.outputImage!.cropped(to: request.sourceImage.extent)
//
//            guard let self,
//                  let inputImage = request.sourceImage.cgImage,
//                  let outputImage = try? self.segmentPerson(in: inputImage)
//            else {
//                request.finish(with: SegmentationServiceError.noResult)
//                return
//            }
//            let output = CIImage(cgImage: outputImage)
//
//            // Provide the filter output to the composition
//            request.finish(with: output, context: nil)
//        })
//
//        return composition
//    }
    
    func processVideoFrame(_ framePixelBuffer: CVPixelBuffer) throws -> CIImage {
        try? requestHandler.perform([facePoseRequest, personSegmentationRequest],
                                    on: framePixelBuffer,
                                    orientation: .right)
        guard let maskPixelBuffer =
                personSegmentationRequest.results?.first?.pixelBuffer,
              let blendedImage = blend(original: framePixelBuffer, mask: maskPixelBuffer)
        else { throw SegmentationServiceError.noResult }
        return blendedImage
    }
    
    func segmentPerson(in image: CIImage, isPreview: Bool) throws -> CIImage {
        let requestHandler = VNImageRequestHandler(ciImage: image)
        try requestHandler.perform([isPreview ? personSegmentationRequest : personSegmentationRequestHD])
        guard let result = (isPreview ? personSegmentationRequest : personSegmentationRequestHD).results?.first,
                let blendedImage = blend(originalImage: image, maskImage: CIImage(cvImageBuffer: result.pixelBuffer))
        else { throw SegmentationServiceError.noResult }
        return blendedImage
    }
    
//    func segmentPerson(in image: CGImage) throws -> CGImage {
//        let requestHandler = VNImageRequestHandler(cgImage: image)
//        try requestHandler.perform([personSegmentationRequest])
//        guard let result = personSegmentationRequest.results?.first,
//              let blendedImage = blend(originalImage: CIImage(cgImage: image), maskImage: CIImage(cvImageBuffer: result.pixelBuffer)),
//              let cgBlendedImage = createCGImage(from: blendedImage)
//        else { throw SegmentationServiceError.noResult }
//        
//        return cgBlendedImage
//    }
    
    func generateThumbnailFromPlayerItem(item: AVPlayerItem) throws -> CGImage? {
        let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)])
        item.add(videoOutput)
        guard let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: item.currentTime(), itemTimeForDisplay: nil),
            let blendedImage = processVideoFrame(pixelBuffer),
              let cgBlendedImage = createCGImage(from: blendedImage)
        else { throw SegmentationServiceError.noResult }

        return cgBlendedImage
    }
    
    private func processVideoFrame(_ framePixelBuffer: CVPixelBuffer) -> CIImage? {
        // Perform the requests on the pixel buffer that contains the video frame.
        try? requestHandler.perform([facePoseRequest, personSegmentationRequest],
                                    on: framePixelBuffer,
                                    orientation: .right)
        
        // Get the pixel buffer that contains the mask image.
        guard let maskPixelBuffer =
                personSegmentationRequest.results?.first?.pixelBuffer else { return nil }
        
        // Process the images.
        return blend(original: framePixelBuffer, mask: maskPixelBuffer)
    }
    
    private func blend(original framePixelBuffer: CVPixelBuffer,
                       mask maskPixelBuffer: CVPixelBuffer) -> CIImage? {
        
        // Remove the optionality from generated color intensities or exit early.
//        guard let colors = colors else { return }
        
        // Create CIImage objects for the video frame and the segmentation mask.
        let originalImage = CIImage(cvPixelBuffer: framePixelBuffer).oriented(.right)
        var maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
        
        // Scale the mask image to fit the bounds of the video frame.
        let scaleX = originalImage.extent.width / maskImage.extent.width
        let scaleY = originalImage.extent.height / maskImage.extent.height
        maskImage = maskImage.transformed(by: .init(scaleX: scaleX, y: scaleY))
        
        // Define RGB vectors for CIColorMatrix filter.
//        let vectors = [
//            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: colors.red),
//            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: colors.green),
//            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: colors.blue)
//        ]
//
//        // Create a colored background image.
//        let backgroundImage = maskImage.applyingFilter("CIColorMatrix",
//                                                       parameters: vectors)
        
        // Blend the original, background, and mask images.
        let blendFilter = CIFilter.blendWithMask() // blendWithRedMask()
        blendFilter.inputImage = originalImage
        blendFilter.backgroundImage = maskImage.settingAlphaOne(in: .zero) //backgroundImage
        blendFilter.maskImage = maskImage
        
        // Set the new, blended image as current.
        return blendFilter.outputImage?.oriented(.left)
    }
}
