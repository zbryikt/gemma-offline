//
//  MessageBubble.swift
//  gemma
//
//  Created by Tai Hui Wu on 2025/5/22.
//

import SwiftUI

/// 消息氣泡視圖
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.type == .user {
                Spacer()
            }
            
            VStack(alignment: message.type == .user ? .trailing : .leading) {
                Text(message.content)
                    .padding(12)
                    .background(message.type == .user ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.type == .user ? .white : .primary)
                    .cornerRadius(16)
                
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
    }
}