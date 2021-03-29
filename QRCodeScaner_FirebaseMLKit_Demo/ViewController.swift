//
//  ViewController.swift
//  QRCodeScaner_FirebaseMLKit_Demo
//
//  Created by Woody on 2021/3/23.
//


/*
 Demo 沒有實裝 GoogleService-Info.plist
 要實際測試需要自行上 firebase 下載 plist
 */



import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var cameraView: CameraView! {
        didSet {
            cameraView.videoPreviewLayer.session = qrcodeScanner.captureSession
            qrcodeScanner.videoPreviewLayer = cameraView.videoPreviewLayer
        }
    }
    
    
    private lazy var qrcodeScanner: QRCodeScanner = {
        let scanner = QRCodeScanner()
        return scanner
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        qrcodeScanner.setQRCodeScanner()
    }


}
