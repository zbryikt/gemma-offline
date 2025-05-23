//
//  ContentView.swift
//  gemma
//
//  Created by Tai Hui Wu on 2025/5/22.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showImagePicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 導航欄
            HStack {
                Text("Gemma 聊天")
                    .font(.title)
                    .bold()
                
                Spacer()
                
                // 模型狀態指示器
                if viewModel.isInitializing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 8)
                } else if viewModel.isModelInitialized {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .padding(.trailing, 8)
                } else {
                    Button(action: {
                        Task {
                            await viewModel.reinitializeModel()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise.circle")
                            .foregroundColor(.blue)
                    }
                    .padding(.trailing, 8)
                }
                
                Button(action: {
                    viewModel.clearChat()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            .padding()
            
            // 模型初始化狀態提示
            if !viewModel.isModelInitialized {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(viewModel.isInitializing ? "正在初始化模型..." : "模型尚未初始化，請點擊右上角重新初始化按鈕")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            // 聊天消息列表
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                // 當最後一條消息的內容變化時，也滾動到底部
                .onChange(of: viewModel.messages.last?.content) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color.gray.opacity(0.05))
            
            // 處理中指示器
            if viewModel.isProcessing {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 8)
                    Text("生成中...")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Spacer()
                }
            }
            
            // 輸入區域
            ChatInputView(
                text: $viewModel.userInput,
                selectedImage: $viewModel.selectedImage,
                isProcessing: viewModel.isProcessing,
                onSend: {
                    Task {
                        await viewModel.sendMessage()
                    }
                },
                onCameraSelect: {
                    viewModel.showCamera()
                },
                onPhotoLibrarySelect: {
                    viewModel.showPhotoLibrary()
                }
            )
        }
        .alert("錯誤", isPresented: $viewModel.showError) {
            Button("確定", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onAppear {
            // 檢查模型狀態
            Task {
                await viewModel.checkModelStatus()
            }
        }
        .sheet(isPresented: $viewModel.showImagePicker) {
            // 圖片選擇器
            ImagePickerView(selectedImage: $viewModel.selectedImage, source: viewModel.imageSource)
        }
    }
}

#Preview {
    ContentView()
}
