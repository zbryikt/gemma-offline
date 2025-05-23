//
//  ChatInputView.swift
//  gemma
//
//  Created by Tai Hui Wu on 2025/5/22.
//

import SwiftUI

/// 聊天輸入視圖
struct ChatInputView: View {
    @Binding var text: String
    @Binding var selectedImage: UIImage?
    let isProcessing: Bool
    let onSend: () -> Void
    let onCameraSelect: () -> Void
    let onPhotoLibrarySelect: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // 如果有選擇的圖片，顯示預覽
            if let image = selectedImage {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60)
                        .cornerRadius(8)
                        .padding(.leading)
                    
                    Spacer()
                    
                    // 清除圖片按鈕
                    Button(action: {
                        selectedImage = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .padding(.trailing)
                    }
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            HStack {
                // 相機按鈕
                Button(action: onCameraSelect) {
                    Image(systemName: "camera")
                        .foregroundColor(.blue)
                        .padding(8)
                }
                .disabled(isProcessing)
                
                // 圖庫按鈕
                Button(action: onPhotoLibrarySelect) {
                    Image(systemName: "photo")
                        .foregroundColor(.blue)
                        .padding(8)
                }
                .disabled(isProcessing)
                
                // 文本輸入框
                TextField("輸入訊息...", text: $text)
                    .padding(10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                    .disabled(isProcessing)
                
                // 發送按鈕
                Button(action: onSend) {
                    Image(systemName: isProcessing ? "hourglass" : "arrow.up.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .foregroundColor(isProcessing || (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImage == nil) ? .gray : .blue)
                }
                .disabled(isProcessing || (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImage == nil))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .top
        )
    }
}

#Preview {
    ChatInputView(
        text: .constant("Hello"),
        selectedImage: .constant(nil),
        isProcessing: false,
        onSend: {},
        onCameraSelect: {},
        onPhotoLibrarySelect: {}
    )
}