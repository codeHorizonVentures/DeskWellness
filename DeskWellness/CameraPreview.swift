//
//  CameraPreview.swift
//  DeskWellness
//
//  Created by Petro Kulakov on 1/11/26.
//

import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.videoPreviewLayer?.session = session
        view.videoPreviewLayer?.videoGravity = .resizeAspectFill
        view.videoPreviewLayer?.connection?.videoOrientation = .portrait
        return view
    }

    func updateUIView(_ uiView: VideoPreviewView, context: Context) { }

    // Minimal UIKit View wrapper with safe layer access
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            return AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer? {
            return layer as? AVCaptureVideoPreviewLayer
        }
    }
}
