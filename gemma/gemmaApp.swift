//
//  gemmaApp.swift
//  gemma
//
//  Created by Tai Hui Wu on 2025/5/22.
//

import SwiftUI

@main
struct gemmaApp: App {
    // 在應用啟動時預加載模型
    init() {
        // 這將觸發 GemmaModelManager 的初始化，從而預加載模型
        print("應用程序啟動，開始初始化 Gemma 模型...")
        _ = GemmaModelManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // 設置更長的背景任務超時時間，以便模型有足夠的時間生成回應
                    UIApplication.shared.beginBackgroundTask(withName: "LLMProcessing") {
                        // 如果超時，這個閉包會被調用
                        print("背景任務超時")
                    }
                }
        }
    }
}
