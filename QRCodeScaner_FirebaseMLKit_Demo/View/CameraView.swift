//
//  CameraView.swift
//  Test_FirebaseML
//
//  Created by Woody on 2021/3/22.
//

import UIKit
import AVFoundation


class CameraView: UIView {
    
    lazy var videoPreviewLayer: AVCaptureVideoPreviewLayer = {
        let vpl = AVCaptureVideoPreviewLayer()
         vpl.videoGravity = .resizeAspectFill
         return vpl
     }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        videoPreviewLayer.frame = frame
     
        layer.addSublayer(videoPreviewLayer)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        videoPreviewLayer.frame = frame
     
        layer.addSublayer(videoPreviewLayer)
    }

}
