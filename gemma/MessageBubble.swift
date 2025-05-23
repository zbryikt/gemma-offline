//
//  MessageBubble.swift
//  gemma
//
//  Created by Tai Hui Wu on 2025/5/22.
//

import SwiftUI
import UIKit

/// 消息氣泡視圖
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.type == .user {
                Spacer()
            }
            
            VStack(alignment: message.type == .user ? .trailing : .leading) {
                // 根據消息內容類型顯示不同的視圖
                switch message.contentType {
                case .text:
                    // 純文字消息
                    Text(message.content)
                        .padding(12)
                        .background(message.type == .user ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(message.type == .user ? .white : .primary)
                        .cornerRadius(16)
                    
                case .image:
                    // 純圖片消息
                    if let image = message.image {
                        VStack(alignment: message.type == .user ? .trailing : .leading) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 240)
                                .cornerRadius(16)
                                .padding(4)
                                .background(message.type == .user ? Color.blue : Color.gray.opacity(0.2))
                                .cornerRadius(20)
                        }
                    } else {
                        Text("圖片無法顯示")
                            .padding(12)
                            .background(message.type == .user ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(message.type == .user ? .white : .primary)
                            .cornerRadius(16)
                    }
                    
                case .textWithImage:
                    // 圖片和文字消息
                    VStack(alignment: message.type == .user ? .trailing : .leading, spacing: 4) {
                        if let image = message.image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 240)
                                .cornerRadius(16)
                                .padding(4)
                                .background(message.type == .user ? Color.blue : Color.gray.opacity(0.2))
                                .cornerRadius(20)
                        }
                        
                        Text(message.content)
                            .padding(12)
                            .background(message.type == .user ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(message.type == .user ? .white : .primary)
                            .cornerRadius(16)
                    }
                }
                
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if message.type == .bot {
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    /// 格式化時間戳
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    VStack {
        MessageBubble(message: ChatMessage(content: "你好，我是用戶", type: .user))
        MessageBubble(message: ChatMessage(content: "你好，我是 Gemma，有什麼我可以幫助你的嗎？", type: .bot))
        MessageBubble(message: ChatMessage(content: "[圖片]", type: .user, contentType: .image, image: UIImage(systemName: "photo")))
        MessageBubble(message: ChatMessage(content: "這是一張圖片和文字", type: .user, contentType: .textWithImage, image: UIImage(systemName: "photo")))
    }
}