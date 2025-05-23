//
//  GemmaModelManager.swift
//  gemma
//
//  Created by Tai Hui Wu on 2025/5/22.
//

import Foundation
import MediaPipeTasksGenAI

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
}

// MARK: - 錯誤定義
enum LLMError: Error, LocalizedError {
    case modelNotFound
    case initializationFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "找不到模型檔案。請確保模型文件已添加到項目資源中。"
        case .initializationFailed:
            return "LLM 初始化失敗"
        }
    }
}
