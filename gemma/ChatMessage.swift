//
//  ChatMessage.swift
//  gemma
//
//  Created by Tai Hui Wu on 2025/5/22.
//

import Foundation

/// 聊天消息類型
enum MessageType {
    case user
    case bot
}

/// 聊天消息模型
struct ChatMessage: Identifiable {
    let id = UUID()
    var content: String
    let type: MessageType
    let timestamp: Date
    
    init(content: String, type: MessageType, timestamp: Date = Date()) {
        self.content = content
        self.type = type
        self.timestamp = timestamp
    }
}