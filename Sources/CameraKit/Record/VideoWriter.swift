//
//  VideoWriter.swift
//  AppPlayground
//
//  Created by Michel-André Chirita on 24/08/2024.
//

import Foundation
import AVFoundation
import UIKit
import VideoToolbox

final class VideoWriter {
    
    let renderSettings: RenderSettings
    
    var videoWriter: AVAssetWriter!
    var videoWriterInput: AVAssetWriterInput!
    var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    
    var isReadyForData: Bool {
        return videoWriterInput?.isReadyForMoreMediaData ?? false
    }
    
    init(renderSettings: RenderSettings) {
        self.renderSettings = renderSettings
    }
    
    func initialize() throws {
        let avOutputSettings: [String: Any] = [
            AVVideoCodecKey: renderSettings.avCodecKey,
            AVVideoWidthKey: NSNumber(value: Float(renderSettings.size.width)),
            AVVideoHeightKey: NSNumber(value: Float(renderSettings.size.height)),
        ]
        
        func createPixelBufferAdaptor() {
            let sourcePixelBufferAttributesDictionary = [
                kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA), // _32ARGB
                kCVPixelBufferWidthKey as String: NSNumber(value: Float(renderSettings.size.width)),
                kCVPixelBufferHeightKey as String: NSNumber(value: Float(renderSettings.size.height))
            ]
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput,
                                                                      sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
        }
        
        func createAssetWriter(outputURL: URL) throws -> AVAssetWriter {
            do {
                let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mov)
                guard assetWriter.canApply(outputSettings: avOutputSettings, forMediaType: AVMediaType.video) else {
                    throw VideoWriterError.initializationFailed(nil)
                }
                return assetWriter
            }
            catch {
                throw VideoWriterError.initializationFailed(error)
            }
        }
        
        videoWriter = try createAssetWriter(outputURL: renderSettings.outputURL)
        videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: avOutputSettings)
        videoWriterInput.expectsMediaDataInRealTime = true
        
        if videoWriter.canAdd(videoWriterInput) {
            videoWriter.add(videoWriterInput)
        }
        else {
            throw VideoWriterError.initializationFailed(nil)
        }
        
        // The pixel buffer adaptor must be created before we start writing.
        createPixelBufferAdaptor()
        
        if videoWriter.startWriting() == false {
            throw VideoWriterError.initializationFailed(videoWriter.error)
        }
    }
    
    func start(sourceTime: CMTime) throws {
        videoWriter.startSession(atSourceTime: sourceTime)
        guard pixelBufferAdaptor.pixelBufferPool != nil else { throw VideoWriterError.initializationFailed(nil) }
    }
    
    func render(image: CIImage, time: CMTime, context: CIContext, applyFilter: ((CIImage)throws->CIImage)?) async throws {
        precondition(videoWriter != nil, "Call start() to initialze the writer")
        try appendPixelBuffers(image: image, presentationTime: time, context: context, applyFilter: applyFilter)
    }
    
    private func appendPixelBuffers(image: CIImage, presentationTime: CMTime, context: CIContext, applyFilter: ((CIImage)throws->CIImage)?) throws {
        
        if isReadyForData == false {
            print("WRITER not ready > skiping frame")
            return
        }
        
        if let applyFilter {
            let filteredImage = try applyFilter(image)
            try addImage(image: filteredImage, withPresentationTime: presentationTime, context: context)
        } else {
            try addImage(image: image, withPresentationTime: presentationTime, context: context)
        }
    }
    
    func finish() async {
        precondition(videoWriter != nil, "Call start() to initialze the writer")
        self.videoWriterInput.markAsFinished()
        await self.videoWriter.finishWriting()
    }
    
    func addImage(image: CIImage, withPresentationTime presentationTime: CMTime, context: CIContext) throws {
        precondition(pixelBufferAdaptor != nil, "Call start() to initialze the writer")
        guard let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool else { return }
        let pixelBuffer = try pixelBuffer(from: image, pixelBufferPool: pixelBufferPool, context: context)
        pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
    }
    
    private func pixelBuffer(from image: CIImage, pixelBufferPool: CVPixelBufferPool, context: CIContext) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBuffer)
        guard let pixelBuffer, status == kCVReturnSuccess else {
            print("CVPixelBufferPoolCreatePixelBuffer() failed")
            throw VideoWriterError.initializationFailed(nil)
        }
        context.render(image, to: pixelBuffer)
        return pixelBuffer
    }
}

enum VideoWriterError: Error {
    case initializationFailed(Error?)
}
