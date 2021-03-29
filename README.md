# Firebase-ML Kit

近期收到PM通知，發票 QRCode 有時候會掃不到，同一張發票Android掃得到，但是公司另一個專案的 iOS 版的可以掃 。
這問題可大可小，經過幾次試驗以後，掃不到的那張發票用 Swift metaDataOutput 回傳的都是 nil，
上網查也查不出原因，有看到swift 開發者上有人發問，也不了了之。

為此特地請PM去問出另一個專案用的是 Firebase ML Kit.............

- 結論

    MLKit 比較厲害，Apple 的 Vision真的比較爛Q_Q

[Recognize text in images with ML Kit on iOS | Google Developers](https://developers.google.com/ml-kit/vision/text-recognition/ios)

---

需求：

- [x]  QRCode 掃瞄器
很簡單，Firebase SDK 包得很完整
- [x]  發票號碼驗證
不需要更改，原本寫得可通用
- [ ]  掃瞄框範圍限制
整個需要重寫，captureOutput 輸出的是 sampleBuffer ，要實作很多東西Q_Q

### 動工

> 原本使用的是原生 metaOutput，只要簡單的將 metaData object 的 bounds 轉換後去比較即可，沒有難度。
但是改成 captureOutput 就比較複雜了。

```swift
func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
```

- 第一步：取得 sampleBuffer  imageSize

    ```swift
    let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
    let imgWidth = CVPixelBufferGetWidth(imageBuffer)
    let imgHeight = CVPixelBufferGetHeight(imageBuffer)
    let imgSize = CGSize(width: imgWidth, height: imgHeight)
    ```

- 第二步：取出 解析出的QRCode 的Frame 在轉換在 sampleBuffer 上的比例座標

    ```swift
    // size: inSampleBufferSize 
    // barcode: VisionBarcode
    let frame = barcode.frame
    // 比例座標 
    let normalizedRect = CGRect(x: frame.origin.x / size.width, y: frame.origin.y / size.height, width: frame.size.width / size.width, height: frame.size.height / size.height)
    ```

- 第三部：將比例座標轉換成 videoPreviewLayer UIKit 的座標

    ```swift
    // videoPreviewLayer: AVCaptureVideoPreviewLayer
    videoPreviewLayer.layerRectConverted(fromMetadataOutputRect: normalizedRect)
    ```

完工，拿到的的座標可以套用任何你想做的事情了。

> 小提醒：使用VideoCapture 要記得處理鏡頭方向。
