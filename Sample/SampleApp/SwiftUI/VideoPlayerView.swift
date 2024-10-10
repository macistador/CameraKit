//
//  VideoPlayerView.swift
//  AppPlayground
//
//  Created by Michel-André Chirita on 28/08/2024.
//

import SwiftUI
import AVKit

struct VideoPlayerView: UIViewRepresentable {
    
    var player: AVPlayer
    
    func makeUIView(context: Context) -> VideoPlayerUIView {
        return VideoPlayerUIView(player: player)
    }
    
    func updateUIView(_ uiView: VideoPlayerUIView, context: UIViewRepresentableContext<VideoPlayerView>) {
        uiView.playerLayer.player = player
    }
}

final class VideoPlayerUIView: UIView {
        
    let playerLayer = AVPlayerLayer()
        
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(player: AVPlayer) {
        super.init(frame: .zero)
        self.playerSetup(player: player)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
        
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
        
    }
        
    private func playerSetup(player: AVPlayer) {
        playerLayer.player = player
        player.actionAtItemEnd = .none
        layer.addSublayer(playerLayer)
        playerLayer.backgroundColor = UIColor.clear.cgColor
    }
}

//#Preview {
//    VideoPlayerView()
//}
