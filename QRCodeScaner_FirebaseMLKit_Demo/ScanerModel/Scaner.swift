//
//  Scaner.swift
//  Test_FirebaseML
//
//  Created by Woody on 2021/3/22.
//

import Foundation
import AVFoundation
import Firebase


class QRCodeScanner: NSObject {
        
    weak var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    var validScanObjectFrame: CGRect?
    
    private lazy var scanOutsideCurrectCGRect: CGRect = {
        return validScanObjectFrame ?? .zero
    }()
        
    let captureVideoDataOutput = AVCaptureVideoDataOutput()
    
    var isCameraReady = false
    
    var scanTimeBetween = 1.0
    
    var startScan: Bool = true
    
    var lastScanTime: TimeInterval = 0
    
    lazy var captureSession: AVCaptureSession = {
        let cs = AVCaptureSession()
        return cs
    }()
    
    lazy var vision = Vision.vision()
    
    lazy var barcodeDetector: VisionBarcodeDetector = {
        let format = VisionBarcodeFormat.qrCode
        let barcodeOptions = VisionBarcodeDetectorOptions(formats: format)
        let barcodeDetector = vision.barcodeDetector(options: barcodeOptions)
        return barcodeDetector
    }()
    
    func setQRCodeScanner() {
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        captureSession.addInput(input)
        
        /// 影片檔像素，提供空值會依照設備預設
        captureVideoDataOutput.videoSettings = [:]
        captureVideoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        captureSession.addOutput(captureVideoDataOutput)
        captureVideoDataOutput.setSampleBufferDelegate(self, queue: .main)
        /// 限制鏡頭 Output 在 videoPreviewLayer bounds 內
        videoPreviewLayer?.videoGravity = .resizeAspectFill
        
        isCameraReady = true
        startCamera()
    }
    
    
    func startCamera() {
        guard isCameraReady else { return }
        if !captureSession.isRunning{
            captureSession.startRunning()
        }
    }
    
    
    func stopCamera() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    
    /// 是否為要的發票qrcode
    /// - Parameter qrcode: qrcode 字串
    private func isValidInvoiceQRCode(qrcode: String) -> Bool {
        
        /// 發票規格為 qrcode 77碼以上
        let limitInt = 77
        
        //  發票規格如不到77碼就return
        guard qrcode.count >= limitInt else {
            return false
        }
        
        //  發票右邊 qrcode 為 ** 開頭
        let rightInvoiceForm = "**"
        
        //  前兩個字如果為**就 return
        if qrcode[qrcode.startIndex..<qrcode.index(qrcode.startIndex, offsetBy: 2)] == rightInvoiceForm {
            return false
        }
        
        return true
    }
    
    
    func timeExpire() -> Bool {
        
        if Date().timeIntervalSince1970 - lastScanTime < scanTimeBetween {
            return false
        }
        
        lastScanTime = Date().timeIntervalSince1970
        
        return true
    }
    
}

extension QRCodeScanner: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        /// 鏡頭掃描控制閥
        guard startScan else { return }
        startScan = false
        
        /// Firebase ML kit meata
        let metadata = VisionImageMetadata()
        metadata.orientation = imageOrientation()
        let image = VisionImage(buffer: sampleBuffer)
        image.metadata = metadata
        
        /// 取出數據分析結果
        barcodeDetector.detect(in: image) { [weak self]
            barcodes, error in
            guard let self = self else { return }
            /// 如果分析有錯誤，或是 barcodes 不存在，開啟掃瞄器
            guard error == nil, let barcodes = barcodes, !barcodes.isEmpty else {
                self.startScan = true
                return
            }
            
            /// 篩選 qrcodes
            self.selectBarcodes(barcodes: barcodes, sampleBuffer: sampleBuffer)
        
        }
    }
    
    
    /// 篩選掃進的 qrcode
    /// - Parameters:
    ///   - barcodes: qrcode 元數就
    ///   - sampleBuffer: 此次畫面媜。用來解析該媜的畫面size
    private func selectBarcodes(barcodes: [VisionBarcode], sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            startScan = true
            return
        }
        /// 相機讀取到的畫面完整尺寸
        let imgSize = sampleBufferSize(imageBuffer)
        
        /// 判斷Qrcode  是否在限制的掃描框內
        guard checkObjectBoundsForTwoObjects(barcodes, sampleBufferSize: imgSize) else {
            self.startScan = true
            /// 埋點使用，判斷是否非發票
            self.checkQRCodeIsNotInvoice(barcodes[0], sampleBufferSize: imgSize)
            return
        }
        
                
        // 此區塊確定 metadataObjects 數量為2
        for index in 0...1 {
            guard let qrcodeString = barcodes[0].displayValue,
                  self.isValidInvoiceQRCode(qrcode: qrcodeString)
            else {
                // 避免兩個物件都非qr code 物件，造成startScan無法開啟
                if index == 1 {
                    self.startScan = true
                }
                continue }
            guard self.timeExpire() else {
                self.startScan = true
                return }
            
            // do something you want
            break
        }
        
    }
    
    
    /// 檢查QRCode是否在中間方框內
    /// 必須兩個QRCode都在限制框框內
    func checkObjectBoundsForTwoObjects(_ barcodes: [VisionBarcode], sampleBufferSize size: CGSize) ->Bool {
        
        // 超過兩個物件就不是發票
        guard barcodes.count < 3 else {
            return false
        }
        guard barcodes.indices.contains(1) else { return false }
        /// 發票左邊QRCode
        let barcodeLeft = barcodes[0]
        /// 發票右邊QRCode
        let barcodesRight = barcodes[1]

        
        // 計算左邊物件的 bounds
        guard var objectRectLeft = convertedRectOfBarcodeFrame(frame: barcodeLeft.frame, inSampleBufferSize: size) else {
            return false
        }
        // 計算右邊邊物件的 bounds
        guard var objectRectRight = convertedRectOfBarcodeFrame(frame: barcodesRight.frame, inSampleBufferSize: size) else {
            return false
        }
        
        /// 縮小 bounds 為原本 0.9 倍
        objectRectLeft = objectRectLeft.insetBy(dx: objectRectLeft.width * 0.90, dy: objectRectLeft.height * 0.90)
        /// 縮小 bounds 為原本 0.9 倍
        objectRectRight = objectRectRight.insetBy(dx: objectRectRight.width * 0.90, dy: objectRectRight.height * 0.90)

        
        // 檢查是否包含在掃描框內
        let leftCheckBool = scanOutsideCurrectCGRect.contains(objectRectLeft)
        
        let rightCheckBool = scanOutsideCurrectCGRect.contains(objectRectRight)
        
        return leftCheckBool && rightCheckBool
    }
    
    /// 將 sampleBufferSize 轉換為 UIImage Size
    private func sampleBufferSize(_ imageBuffer: CVImageBuffer)-> CGSize {
        let imgWidth = CVPixelBufferGetWidth(imageBuffer)
        let imgHeight = CVPixelBufferGetHeight(imageBuffer)
        return CGSize(width: imgWidth, height: imgHeight)
    }
    
    /// 將qrcode 元數據的frame 轉乘 iphone UIKit 在 videoPreviewLayer 座標
    private func convertedRectOfBarcodeFrame(frame: CGRect, inSampleBufferSize size: CGSize)-> CGRect? {
        /// 將 掃到的QRCode.frame 轉為 imgSize 的比例
        let normalizedRect = CGRect(x: frame.origin.x / size.width, y: frame.origin.y / size.height, width: frame.size.width / size.width, height: frame.size.height / size.height)
        /// 將比例轉成 UIkit 座標
        return videoPreviewLayer?.layerRectConverted(fromMetadataOutputRect: normalizedRect)
    }
    
    
    /// 判斷是否為發票
    private func checkQRCodeIsNotInvoice(_ barcode: VisionBarcode, sampleBufferSize size: CGSize) {
        guard let qrcodeQtring = barcode.displayValue else { return }
    
        guard let objectRect = convertedRectOfBarcodeFrame(frame: barcode.frame, inSampleBufferSize: size), scanOutsideCurrectCGRect.contains(objectRect) else { return }
    
        if !isValidInvoiceQRCode(qrcode: qrcodeQtring) {
            NSLog("It is not invoice")
        }
    }
    
    
    private func imageOrientation(deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation, cameraPosition: AVCaptureDevice.Position = .front) -> VisionDetectorImageOrientation {
        var deviceOrientation = deviceOrientation
        
        if deviceOrientation == .faceDown || deviceOrientation == .faceUp || deviceOrientation == .unknown {
            deviceOrientation = currectDeviceOrientation()
        }
        
        switch deviceOrientation {
        
        case .portrait:
            return cameraPosition == .front ? .leftTop : .rightTop
        case .landscapeLeft:
            return cameraPosition == .front ? .bottomLeft : .topLeft
        case .portraitUpsideDown:
            return cameraPosition == .front ? .rightBottom : .leftBottom
        case .landscapeRight:
            return cameraPosition == .front ? .topRight : .bottomRight
        case .faceUp, .faceDown, .unknown:
            return .topLeft
        @unknown default:
            return cameraPosition == .front ? .leftTop : .rightTop
        }
    }
    
    
    private func currectDeviceOrientation()-> UIDeviceOrientation {
         
            let status: UIInterfaceOrientation
            
            if #available(iOS 13, *) {
                status =  UIApplication.shared.windows.filter { $0.isKeyWindow }.first?.windowScene?.interfaceOrientation ?? .unknown
            } else {
                status = UIApplication.shared.statusBarOrientation
            }
            
            
            switch status {
            case .portrait, .unknown:
                return .portrait
            case .portraitUpsideDown:
                return .portraitUpsideDown
            case .landscapeLeft:
                return .landscapeRight
            case .landscapeRight:
                return .landscapeLeft
            @unknown default:
                return .portrait
            }
        }
    
    
}
