//
//  GemmaModelManager.swift
//  gemma
//
//  Created by Tai Hui Wu on 2025/5/22.
//

import Foundation
import MediaPipeTasksGenAI
import UIKit

/// 管理 Gemma 模型的類
class GemmaModelManager {
    // 單例模式
    static let shared = GemmaModelManager()
    
    // 模型文件名（使用 .task 檔案格式）
    private let modelFileName = "gemma-3n-E4B-it-int4"
    private let modelFileExtension = "task"  // 使用 .task 副檔名來匹配實際檔案
    
    // MediaPipe LLM 推理引擎 - 使用正確的類型名稱
    private var llmInference: LlmInference?
    
    // 當前活動的 Session
    private var activeSession: LlmInference.Session?
    
    // 用於同步的鎖
    private let sessionLock = NSLock()
    
    // 初始化狀態
    private(set) var isInitialized = false
    private(set) var initializationError: Error?
    
    // 視覺模態是否可用
    private(set) var isVisionModalityAvailable = false
    
    // 初始化方法
    private init() {
        // 在初始化時自動載入模型
        Task {
            await loadModel()
        }
    }
    
    /// 重新初始化模型 - 當初始化失敗時可以調用此方法重試
    func reinitialize() async -> Bool {
        // 重置狀態
        isInitialized = false
        initializationError = nil
        llmInference = nil
        
        // 重新載入模型
        await loadModel()
        
        // 返回初始化狀態
        return isInitialized
    }
    
    /// 載入 Gemma 模型
    private func loadModel() async {
        // 使用原始的路徑獲取方式
        guard let modelPath = Bundle.main.path(forResource: modelFileName, ofType: modelFileExtension) else {
            let error = LLMError.modelNotFound
            print("無法找到模型文件：\(modelFileName).\(modelFileExtension) - \(error.localizedDescription)")
            initializationError = error
            return
        }
        
        print("找到模型文件：\(modelPath)")
        
        do {
            // 創建 LLM 推理選項 - 使用正確的API
            let options = LlmInference.Options(modelPath: modelPath)
            // 設置選項
            options.maxTokens = 1000
            options.maxTopk = 40
            options.maxImages = 1  // 設置最大圖片數量
            
            // 明確啟用視覺模態支持
            isVisionModalityAvailable = true
            print("已啟用 Gemma 模型的視覺模態支持")
            
            // 檢查是否有視覺編碼器和適配器路徑
            if let visionEncoderPath = Bundle.main.path(forResource: "vision_encoder", ofType: "task") {
                options.visionEncoderPath = visionEncoderPath
                print("找到視覺編碼器：\(visionEncoderPath)")
            }
            
            if let visionAdapterPath = Bundle.main.path(forResource: "vision_adapter", ofType: "task") {
                options.visionAdapterPath = visionAdapterPath
                print("找到視覺適配器：\(visionAdapterPath)")
            }
            
            // 注意：temperature 和 randomSeed 屬性在 LlmInference.Session.Options 中設置
            // 我們將在創建 Session 時設置這些參數
            
            // 初始化 LLM 推理引擎 - 使用正確的類型名稱
            print("開始初始化 LlmInference...")
            llmInference = try LlmInference(options: options)
            isInitialized = true
            print("Gemma 模型載入成功")
        } catch {
            print("載入 Gemma 模型時出錯：\(error.localizedDescription)")
            initializationError = error
        }
    }
    
    /// 生成回應（同步版本）
    /// - Parameter prompt: 用戶輸入的提示
    /// - Returns: 模型生成的回應
    func generateResponse(for prompt: String) async -> String {
        guard let llmInference = llmInference, isInitialized else {
            if let error = initializationError {
                return "模型初始化失敗：\(error.localizedDescription)"
            }
            return "模型尚未載入，請稍後再試。"
        }
        
        do {
            // 為每次請求創建一個新的 Session
            let sessionOptions = LlmInference.Session.Options()
            sessionOptions.topk = 40
            sessionOptions.temperature = 0.7
            sessionOptions.randomSeed = 101
            
            // 如果視覺模態可用，啟用它
            if isVisionModalityAvailable {
                sessionOptions.enableVisionModality = true
                print("會話已啟用視覺模態")
            }
            
            let session = try LlmInference.Session(llmInference: llmInference, options: sessionOptions)
            
            // 添加查詢
            try session.addQueryChunk(inputText: prompt)
            
            // 生成回應
            let result = try session.generateResponse()
            return result
        } catch {
            print("生成回應時出錯：\(error)")
            return "生成回應時出錯，請稍後再試。"
        }
    }
    
    /// 生成回應（流式版本）
    /// - Parameter prompt: 用戶輸入的提示
    /// - Returns: 模型生成的回應流
    func generateResponseStream(for prompt: String) -> AsyncThrowingStream<String, Error> {
        guard let llmInference = llmInference, isInitialized else {
            return AsyncThrowingStream { continuation in
                if let error = initializationError {
                    continuation.finish(throwing: error)
                } else {
                    continuation.finish(throwing: LLMError.initializationFailed)
                }
            }
        }
        
        return AsyncThrowingStream { continuation in
            // 使用鎖來確保同一時間只有一個活動的 Session
            sessionLock.lock()
            
            // 如果有活動的 Session，先關閉它
            if let activeSession = self.activeSession {
                print("關閉之前的 Session")
                self.activeSession = nil
            }
            
            do {
                // 為每次請求創建一個新的 Session
                let sessionOptions = LlmInference.Session.Options()
                sessionOptions.topk = 40
                sessionOptions.temperature = 0.7
                sessionOptions.randomSeed = 101
                
                // 如果視覺模態可用，啟用它
                if isVisionModalityAvailable {
                    sessionOptions.enableVisionModality = true
                    print("流式會話已啟用視覺模態")
                }
                
                print("創建新的 Session")
                let session = try LlmInference.Session(llmInference: llmInference, options: sessionOptions)
                self.activeSession = session
                
                // 解鎖，允許其他操作
                sessionLock.unlock()
                
                // 添加查詢
                try session.addQueryChunk(inputText: prompt)
                
                // 使用 Session 的流式 API 生成回應
                let resultStream = try session.generateResponseAsync()
                Task {
                    do {
                        for try await partialResult in resultStream {
                            continuation.yield(partialResult)
                        }
                        
                        // 完成後，清除活動的 Session
                        sessionLock.lock()
                        if self.activeSession === session {
                            self.activeSession = nil
                        }
                        sessionLock.unlock()
                        
                        continuation.finish()
                    } catch {
                        // 發生錯誤時，也清除活動的 Session
                        sessionLock.lock()
                        if self.activeSession === session {
                            self.activeSession = nil
                        }
                        sessionLock.unlock()
                        
                        continuation.finish(throwing: error)
                    }
                }
            } catch {
                // 解鎖並返回錯誤
                sessionLock.unlock()
                continuation.finish(throwing: error)
            }
        }
    }
    
    /// 將 UIImage 轉換為 CVPixelBuffer
    /// - Parameters:
    ///   - image: 原始圖片
    ///   - size: 目標尺寸（默認為 224x224，這是許多視覺模型的標準輸入尺寸）
    /// - Returns: 轉換後的 CVPixelBuffer，如果轉換失敗則返回 nil
    private func pixelBuffer(from image: UIImage, size: CGSize = CGSize(width: 224, height: 224)) -> CVPixelBuffer? {
        // 首先調整圖片大小
        let resizedImage = resizeImage(image: image, size: size)
        guard let cgImage = resizedImage?.cgImage else {
            print("無法獲取 CGImage")
            return nil
        }
        
        // 創建 CVPixelBuffer 的屬性
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            print("創建 CVPixelBuffer 失敗: \(status)")
            return nil
        }
        
        // 鎖定 buffer 的基地址以進行寫入
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        // 創建 CGContext 並繪製圖片
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
        
        guard let ctx = context else {
            print("無法創建 CGContext")
            return nil
        }
        
        // 繪製圖片到 context
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        print("成功創建 \(size.width)x\(size.height) 的 CVPixelBuffer")
        return buffer
    }
    
    /// 調整圖片大小
    /// - Parameters:
    ///   - image: 原始圖片
    ///   - size: 目標尺寸
    /// - Returns: 調整大小後的 UIImage
    private func resizeImage(image: UIImage, size: CGSize) -> UIImage? {
        // 確保圖片方向正確
        let imageWithCorrectOrientation = fixOrientation(image)
        
        // 使用高質量的縮放方法
        UIGraphicsBeginImageContextWithOptions(size, true, 2.0)
        defer { UIGraphicsEndImageContext() }
        
        // 填充白色背景
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        // 計算保持縱橫比的繪製區域
        let aspectRatio = imageWithCorrectOrientation.size.width / imageWithCorrectOrientation.size.height
        var drawRect = CGRect(origin: .zero, size: size)
        
        if aspectRatio > 1 {
            // 寬圖片
            let newHeight = size.width / aspectRatio
            let yOffset = (size.height - newHeight) / 2
            drawRect = CGRect(x: 0, y: yOffset, width: size.width, height: newHeight)
        } else if aspectRatio < 1 {
            // 高圖片
            let newWidth = size.height * aspectRatio
            let xOffset = (size.width - newWidth) / 2
            drawRect = CGRect(x: xOffset, y: 0, width: newWidth, height: size.height)
        }
        
        // 繪製圖片到指定區域，保持縱橫比
        imageWithCorrectOrientation.draw(in: drawRect)
        
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        print("圖片已調整為 \(size.width)x\(size.height)，保持縱橫比")
        
        return resizedImage
    }
    
    /// 從 CVPixelBuffer 創建 CGImage
    /// - Parameter pixelBuffer: 輸入的 CVPixelBuffer
    /// - Returns: 轉換後的 CGImage
    private func cgImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("無法從 CVPixelBuffer 創建 CGImage")
            return nil
        }
        print("成功從 CVPixelBuffer 創建 CGImage")
        return cgImage
    }
    
    /// 修正圖片方向
    private func fixOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        
        print("已修正圖片方向")
        return normalizedImage
    }
    
    /// 生成包含圖片的回應（流式版本）
    /// - Parameters:
    ///   - prompt: 用戶輸入的提示
    ///   - image: 用戶提供的圖片
    /// - Returns: 模型生成的回應流
    func generateResponseStreamWithImage(for prompt: String, image: UIImage) -> AsyncThrowingStream<String, Error> {
        guard let llmInference = llmInference, isInitialized else {
            return AsyncThrowingStream { continuation in
                if let error = initializationError {
                    continuation.finish(throwing: error)
                } else {
                    continuation.finish(throwing: LLMError.initializationFailed)
                }
            }
        }
        
        // 檢查視覺模態是否可用
        guard isVisionModalityAvailable else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: LLMError.visionModalityNotAvailable)
            }
        }
        
        return AsyncThrowingStream { continuation in
            // 使用鎖來確保同一時間只有一個活動的 Session
            sessionLock.lock()
            
            // 如果有活動的 Session，先關閉它
            if let activeSession = self.activeSession {
                print("關閉之前的 Session")
                self.activeSession = nil
            }
            
            do {
                // 為每次請求創建一個新的 Session，確保視覺模態正確啟用
                let sessionOptions = LlmInference.Session.Options()
                sessionOptions.topk = 40
                sessionOptions.temperature = 0.7
                sessionOptions.randomSeed = 101
                
                // 明確啟用視覺模態，並確保設置正確
                sessionOptions.enableVisionModality = true
                print("視覺模態已啟用：\(sessionOptions.enableVisionModality)")
                
                print("創建新的 Session（帶圖片）")
                let session = try LlmInference.Session(llmInference: llmInference, options: sessionOptions)
                self.activeSession = session
                
                // 解鎖，允許其他操作
                sessionLock.unlock()
                
                // 參考 Android 實現，先添加查詢文本，再添加圖片
                // 添加查詢
                try session.addQueryChunk(inputText: prompt)
                print("已添加查詢文本到 Session")
                
                // 參考 MediaPipe 圖像處理指南，正確處理圖片
                
                // 1. 先將 UIImage 轉換為 CVPixelBuffer
                guard let pixBuffer = pixelBuffer(from: image) else {
                    print("無法將圖片轉換為 CVPixelBuffer")
                    throw LLMError.imageProcessingFailed
                }
                
                // 2. 從 CVPixelBuffer 創建 CGImage
                guard let processedCGImage = cgImage(from: pixBuffer) else {
                    print("無法從 CVPixelBuffer 創建 CGImage")
                    throw LLMError.imageProcessingFailed
                }
                
                // 3. 添加處理後的圖片到 Session
                try session.addImage(image: processedCGImage)
                print("已添加處理後的圖片到 Session，尺寸：\(processedCGImage.width)x\(processedCGImage.height)")
                
                // 使用 Session 的流式 API 生成回應
                let resultStream = try session.generateResponseAsync()
                Task {
                    do {
                        for try await partialResult in resultStream {
                            continuation.yield(partialResult)
                        }
                        
                        // 完成後，清除活動的 Session
                        sessionLock.lock()
                        if self.activeSession === session {
                            self.activeSession = nil
                        }
                        sessionLock.unlock()
                        
                        continuation.finish()
                    } catch {
                        // 發生錯誤時，也清除活動的 Session
                        sessionLock.lock()
                        if self.activeSession === session {
                            self.activeSession = nil
                        }
                        sessionLock.unlock()
                        
                        continuation.finish(throwing: error)
                    }
                }
            } catch {
                // 解鎖並返回錯誤
                sessionLock.unlock()
                continuation.finish(throwing: error)
            }
        }
    }
}

// MARK: - 錯誤定義
enum LLMError: Error, LocalizedError {
    case modelNotFound
    case initializationFailed
    case visionModalityNotAvailable
    case invalidImage
    case imageProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "找不到模型檔案。請確保模型文件已添加到項目資源中。"
        case .initializationFailed:
            return "LLM 初始化失敗"
        case .visionModalityNotAvailable:
            return "視覺模態不可用。請確保模型支援視覺功能。"
        case .invalidImage:
            return "無效的圖片格式"
        case .imageProcessingFailed:
            return "圖片處理失敗。無法將圖片轉換為正方形 CGImage。"
        }
    }
}
