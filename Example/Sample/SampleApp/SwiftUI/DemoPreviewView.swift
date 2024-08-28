//
//  DemoPreviewView.swift
//  AppPlayground
//
//  Created by Michel-André Chirita on 26/08/2024.
//

import SwiftUI
import AVKit
import CameraKit
import Photos

struct DemoPreviewView: View {
    var url: URL
    private let player: AVPlayer
    @State var hasBeenExported: Bool = false
    
    init(url: URL) {
        self.url = url
        self.player = AVPlayer(url: url)
    }
    
    var body: some View {
        VStack {
            Spacer()
            Circle()
                .fill(.clear)
                .stroke(.black, lineWidth: 3)
                .overlay {
                    VideoPlayerView(player: player)
                        .clipShape(.circle)
                }
                .padding(.bottom)
            
            HStack {
                Spacer()
                
                Button {
                    player.pause()
                    player.seek(to: .zero)
                    player.play()
                } label: {
                    Text("Play again")
                }
                .buttonStyle(BorderedButtonStyle())
                .padding()

                Button {
                    exportVideo()
                } label: {
                    Text("Export")
                }
                .buttonStyle(BorderedButtonStyle())
                .disabled(hasBeenExported)
                .padding()
                
                Spacer()
            }
            
            Spacer()
        }
        .padding(.horizontal, 10)
        .onAppear {
            player.play()
        }
    }
    
    private func exportVideo() {
        hasBeenExported = true
        Task {
            try? await saveToLibrary(videoURL: url)
        }
    }
    
    private func saveToLibrary(videoURL: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else { return }
        
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        }
    }
}

//#Preview {
//    DemoPreviewView()
//}
