
# MediaPipe 圖像輸入與預處理指南（Swift iOS App）

本文件說明如何在使用 MediaPipe 的 iOS App 中正確處理圖像輸入，以避免模型出現只輸出重複文字等問題。

---

## ✅ 支援的圖像格式與資料類型（根據官方說明）

MediaPipe 的模型通常使用 `mp.Image` 作為輸入，支援以下格式與資料：

- **圖像格式（ImageFormat）**
  - `SRGB`：標準 RGB 色彩格式
  - `GRAY8`：8 位元灰階圖像

- **資料類型**
  - `uint8`：8 位元整數
  - `float32`：32 位元浮點數（通常需要做 0~1 的正規化）

---

## 🛠 圖像處理步驟（Swift 範例）

### 1. 載入與縮放圖像
```swift
func resizeImage(image: UIImage, size: CGSize) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, true, 2.0)
    image.draw(in: CGRect(origin: .zero, size: size))
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return newImage
}
```

### 2. 轉換為 CVPixelBuffer
```swift
func pixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
    guard let resizedImage = resizeImage(image: image, size: size),
          let cgImage = resizedImage.cgImage else { return nil }

    let attrs: [CFString: Any] = [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true
    ]
    var pixelBuffer: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height),
                        kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pixelBuffer)

    guard let buffer = pixelBuffer else { return nil }

    CVPixelBufferLockBaseAddress(buffer, [])
    let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                            width: Int(size.width),
                            height: Int(size.height),
                            bitsPerComponent: 8,
                            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)

    context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
    CVPixelBufferUnlockBaseAddress(buffer, [])

    return buffer
}
```

### 3. 傳給模型的步驟
MediaPipe 模型通常有一個 `Image` 輸入端，你需要確認是否使用了 `Image` 封裝類別，或是模型要求的是 `CVPixelBuffer` / `MLFeatureValue`。

```swift
// 傳入模型的步驟（視 MediaPipe API 而定）
if let pixelBuffer = pixelBuffer(from: yourUIImage, size: CGSize(width: 224, height: 224)) {
    // 傳入模型推理
    model.predict(pixelBuffer: pixelBuffer)
}
```

---

## ⚠️ 注意事項

- 請勿直接將 `UIImage.pngData()` 或 `jpegData()` 傳給模型，那是壓縮過的二進位格式，並非圖像矩陣。
- 確保像素資料是連續記憶體（contiguous memory），否則可能導致推理錯誤。
- 若模型輸入為浮點數類型，請在轉換後手動正規化（除以 255）。

---

## 🔗 官方參考連結

- [MediaPipe mp.Image API 說明](https://ai.google.dev/edge/api/mediapipe/python/mp/Image)
- [MediaPipe 圖像處理範例](https://ai.google.dev/edge/mediapipe/solutions/vision/image_embedder)

