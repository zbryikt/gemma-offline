//
//  ChatMessage.swift
//  gemma
//
//  Created by Tai Hui Wu on 2025/5/22.
//

import Foundation
import SwiftUI
import UIKit

/// 聊天消息類型
enum MessageType {
    case user
    case bot
}

/// 聊天消息內容類型
enum MessageContentType {
    case text
    case image
    case textWithImage
}

/// 聊天消息模型
struct ChatMessage: Identifiable {
    let id = UUID()
    var content: String
    let type: MessageType
    let timestamp: Date
    var contentType: MessageContentType = .text
    var image: UIImage?
    
    init(content: String, type: MessageType, timestamp: Date = Date(), contentType: MessageContentType = .text, image: UIImage? = nil) {
        self.content = content
        self.type = type
        self.timestamp = timestamp
        self.contentType = contentType
        self.image = image
    }
}