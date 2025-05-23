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
    let isProcessing: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack {
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
                    .foregroundColor(isProcessing || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
            }
            .disabled(isProcessing || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
    ChatInputView(text: .constant("Hello"), isProcessing: false, onSend: {})
}