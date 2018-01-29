//
//  VideoPreviewView.swift
//  Cmd+F
//
//  Created by John Feusi on 1/28/18.
//  Copyright © 2018 Feusi's Appworks. All rights reserved.
//

import UIKit
import AVFoundation

class PreviewView: UIView {
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check PreviewView.layerClass implementation.")
        }

        layer.videoGravity = AVLayerVideoGravityResizeAspect

        return layer
    }

    var session: AVCaptureSession? {
        get {
            return videoPreviewLayer.session
        }
        set {
            videoPreviewLayer.session = newValue
        }
    }

    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    private var orientationMap: [UIDeviceOrientation : AVCaptureVideoOrientation] = [
        .portrait           : .portrait,
        .portraitUpsideDown : .portraitUpsideDown,
        .landscapeLeft      : .landscapeRight,
        .landscapeRight     : .landscapeLeft,
    ]
    
    func updateVideoOrientationForDeviceOrientation() {
        if let videoPreviewLayerConnection = videoPreviewLayer.connection {
            let deviceOrientation = UIDevice.current.orientation
            guard let newVideoOrientation = orientationMap[deviceOrientation],
                deviceOrientation.isPortrait || deviceOrientation.isLandscape
                else { return }
            videoPreviewLayerConnection.videoOrientation = newVideoOrientation
        }
    }
}

