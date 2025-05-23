# Info.plist 權限設定說明

為了讓圖片判讀功能正常運作，您需要在 Info.plist 文件中添加以下權限描述：

## 相機權限

添加以下鍵值對：

```xml
<key>NSCameraUsageDescription</key>
<string>需要使用相機拍攝照片以進行圖片判讀</string>
```

## 照片庫權限

添加以下鍵值對：

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>需要訪問照片庫以選擇圖片進行判讀</string>
```

## 如何添加

1. 在 Xcode 中打開您的專案
2. 找到 Info.plist 文件並點擊打開
3. 點擊 "+" 按鈕添加新的鍵值對
4. 輸入上述的鍵名和值
5. 保存文件

這些權限描述將在應用程序首次嘗試訪問相機或照片庫時顯示給用戶，以請求他們的許可。