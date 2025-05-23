//
//  ChatViewModel.swift
//  gemma
//
//  Created by Tai Hui Wu on 2025/5/22.
//

import Foundation
import SwiftUI
import UIKit

/// 聊天視圖模型
class ChatViewModel: ObservableObject {
    // 聊天消息列表
    @Published var messages: [ChatMessage] = []
    
    // 用戶輸入
    @Published var userInput: String = ""
    
    // 選擇的圖片
    @Published var selectedImage: UIImage?
    
    // 是否顯示圖片選擇器
    @Published var showImagePicker: Bool = false
    
    // 圖片來源（相機或圖庫）
    @Published var imageSource: ImageSource = .photoLibrary
    
    // 是否正在處理請求
    @Published var isProcessing: Bool = false
    
    // 錯誤處理
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    
    // 模型初始化狀態
    @Published var isModelInitialized: Bool = false
    @Published var isInitializing: Bool = false
    
    // 模型管理器
    private let modelManager = GemmaModelManager.shared
    
    // 當前正在生成的消息 ID
    private var currentGeneratingMessageId: UUID?
    
    init() {
        // 檢查模型初始化狀態
        Task {
            await checkModelStatus()
        }
    }
    
    /// 檢查模型狀態
    func checkModelStatus() async {
        await MainActor.run {
            isInitializing = true
        }
        
        // 檢查模型是否已初始化
        let isInitialized = modelManager.isInitialized
        let error = modelManager.initializationError
        
        await MainActor.run {
            isModelInitialized = isInitialized
            isInitializing = false
            
            if !isInitialized, let error = error {
                errorMessage = "模型初始化失敗：\(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    /// 重新初始化模型
    func reinitializeModel() async {
        await MainActor.run {
            isInitializing = true
        }
        
        let success = await modelManager.reinitialize()
        
        await MainActor.run {
            isModelInitialized = success
            isInitializing = false
            
            if !success, let error = modelManager.initializationError {
                errorMessage = "模型初始化失敗：\(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    /// 發送消息
    func sendMessage() async {
        guard !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImage != nil else {
            return
        }
        
        // 確保模型已初始化
        if !isModelInitialized {
            // 如果模型尚未初始化，先檢查狀態
            if !isInitializing {
                await checkModelStatus()
            }
            
            // 如果檢查後仍未初始化，嘗試重新初始化
            if !isModelInitialized && !isInitializing {
                await reinitializeModel()
            }
            
            // 如果重新初始化後仍未成功，顯示錯誤
            if !isModelInitialized {
                await MainActor.run {
                    errorMessage = "模型尚未初始化，無法生成回應。"
                    showError = true
                }
                return
            }
        }
        
        // 創建用戶消息
        var userMessage: ChatMessage
        let userInput = self.userInput // 保存當前輸入
        
        // 根據是否有圖片來創建不同類型的消息
        if let image = selectedImage {
            if userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // 只有圖片
                userMessage = ChatMessage(content: "[圖片]", type: .user, contentType: .image, image: image)
            } else {
                // 圖片和文字
                userMessage = ChatMessage(content: userInput, type: .user, contentType: .textWithImage, image: image)
            }
        } else {
            // 只有文字
            userMessage = ChatMessage(content: userInput, type: .user)
        }
        
        // 在主線程更新 UI
        await MainActor.run {
            messages.append(userMessage)
            self.userInput = ""
            self.selectedImage = nil
            isProcessing = true
        }
        
        // 創建一個空的機器人回應消息
        let botMessage = ChatMessage(content: "", type: .bot)
        currentGeneratingMessageId = botMessage.id
        
        // 在主線程添加空消息
        await MainActor.run {
            messages.append(botMessage)
        }
        
        do {
            // 使用流式回應
            let responseStream: AsyncThrowingStream<String, Error>
            
            if let image = userMessage.image {
                // 如果有圖片，使用帶圖片的生成方法
                responseStream = modelManager.generateResponseStreamWithImage(for: userInput, image: image)
            } else {
                // 如果沒有圖片，使用普通的生成方法
                responseStream = modelManager.generateResponseStream(for: userInput)
            }
            
            // 逐步更新回應
            for try await partialResponse in responseStream {
                await MainActor.run {
                    // 更新最後一條消息的內容
                    if let index = messages.firstIndex(where: { $0.id == botMessage.id }) {
                        messages[index].content += partialResponse
                    }
                }
            }
            
            // 完成生成
            await MainActor.run {
                isProcessing = false
                currentGeneratingMessageId = nil
            }
        } catch {
            // 處理錯誤
            await MainActor.run {
                isProcessing = false
                currentGeneratingMessageId = nil
                
                // 如果生成過程中出錯，更新錯誤消息
                if let index = messages.firstIndex(where: { $0.id == botMessage.id }) {
                    messages[index].content = "生成回應時出錯：\(error.localizedDescription)"
                }
                
                errorMessage = "生成回應時出錯：\(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    /// 使用同步方式發送消息（備用方法）
    func sendMessageSync() async {
        guard !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // 添加用戶消息
        let userMessage = ChatMessage(content: userInput, type: .user)
        
        // 在主線程更新 UI
        await MainActor.run {
            messages.append(userMessage)
            userInput = ""
            isProcessing = true
        }
        
        // 獲取模型回應
        let response = await modelManager.generateResponse(for: userMessage.content)
        
        // 添加機器人回應
        let botMessage = ChatMessage(content: response, type: .bot)
        
        // 在主線程更新 UI
        await MainActor.run {
            messages.append(botMessage)
            isProcessing = false
        }
    }
    
    /// 清空聊天記錄
    func clearChat() {
        messages.removeAll()
    }
    
    /// 顯示圖片選擇器（相機）
    func showCamera() {
        imageSource = .camera
        showImagePicker = true
    }
    
    /// 顯示圖片選擇器（圖庫）
    func showPhotoLibrary() {
        imageSource = .photoLibrary
        showImagePicker = true
    }
    
    /// 清除選擇的圖片
    func clearSelectedImage() {
        selectedImage = nil
    }
}