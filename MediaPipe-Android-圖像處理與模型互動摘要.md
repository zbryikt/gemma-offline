# MediaPipe 圖像處理與模型互動摘要

本文檔摘要了 Google AI Edge Gallery Android 應用中使用 MediaPipe 處理圖像並與模型互動的關鍵代碼片段。

## 1. 圖像生成 (Image Generation)

在 `ImageGenerationModelHelper.kt` 中，應用使用 MediaPipe 的 ImageGenerator 任務來生成圖像：

```kotlin
// 初始化 MediaPipe ImageGenerator
fun initialize(context: Context, model: Model, onDone: (String) -> Unit) {
  try {
    val options = ImageGenerator.ImageGeneratorOptions.builder()
      .setImageGeneratorModelDirectory(model.getPath(context = context))
      .build()
    model.instance = ImageGenerator.createFromOptions(context, options)
  } catch (e: Exception) {
    onDone(cleanUpMediapipeTaskErrorMessage(e.message ?: "Unknown error"))
    return
  }
  onDone("")
}

// 執行推理生成圖像
fun runInference(
  model: Model,
  input: String,
  onStep: (curIteration: Int, totalIterations: Int, ImageGenerationInferenceResult, isLast: Boolean) -> Unit
) {
  val start = System.currentTimeMillis()
  val instance = model.instance as ImageGenerator
  val iterations = model.getIntConfigValue(ConfigKey.ITERATIONS)
  instance.setInputs(input, iterations, Random.nextInt())
  for (i in 0..<iterations) {
    val result = ImageGenerationInferenceResult(
      bitmap = BitmapExtractor.extract(
        instance.execute(true)?.generatedImage(),
      ),
      latencyMs = (System.currentTimeMillis() - start).toFloat(),
    )
    onStep(i, iterations, result, i == iterations - 1)
  }
}
```

## 2. LLM 聊天與圖像處理 (LLM Chat with Image)

在 `LlmChatModelHelper.kt` 中，應用使用 MediaPipe 的 LlmInference 任務來處理文本和圖像輸入：

```kotlin
// 初始化 MediaPipe LLM 推理引擎
fun initialize(context: Context, model: Model, onDone: (String) -> Unit) {
  // 設置選項
  val options = LlmInference.LlmInferenceOptions.builder()
    .setModelPath(model.getPath(context = context))
    .setMaxTokens(maxTokens)
    .setPreferredBackend(preferredBackend)
    .setMaxNumImages(if (model.llmSupportImage) 1 else 0)
    .build()

  // 創建 LLM 推理任務和會話
  try {
    val llmInference = LlmInference.createFromOptions(context, options)
    val session = LlmInferenceSession.createFromOptions(
      llmInference,
      LlmInferenceSession.LlmInferenceSessionOptions.builder()
        .setTopK(topK)
        .setTopP(topP)
        .setTemperature(temperature)
        .setGraphOptions(
          GraphOptions.builder()
            .setEnableVisionModality(model.llmSupportImage)
            .build()
        )
        .build()
    )
    model.instance = LlmModelInstance(engine = llmInference, session = session)
  } catch (e: Exception) {
    onDone(cleanUpMediapipeTaskErrorMessage(e.message ?: "Unknown error"))
    return
  }
  onDone("")
}

// 執行推理處理文本和圖像
fun runInference(
  model: Model,
  input: String,
  resultListener: ResultListener,
  cleanUpListener: CleanUpListener,
  image: Bitmap? = null,
) {
  val instance = model.instance as LlmModelInstance
  
  // 設置監聽器
  if (!cleanUpListeners.containsKey(model.name)) {
    cleanUpListeners[model.name] = cleanUpListener
  }
  
  // 開始異步推理
  // 對於支持圖像模態的模型，需要在添加圖像之前添加文本查詢塊
  val session = instance.session
  session.addQueryChunk(input)
  if (image != null) {
    session.addImage(BitmapImageBuilder(image).build())
  }
  session.generateResponseAsync(resultListener)
}
```

## 3. 圖像輸入處理 (Image Input Processing)

在 `MessageInputImage.kt` 中，應用提供了多種方式獲取圖像輸入：

```kotlin
// 處理選擇的圖像
private fun handleImageSelected(
  context: Context,
  uri: Uri,
  onImageSelected: (Bitmap) -> Unit,
  rotateForPortrait: Boolean = false,
) {
  val bitmap: Bitmap? = try {
    val inputStream = context.contentResolver.openInputStream(uri)
    val tmpBitmap = BitmapFactory.decodeStream(inputStream)
    if (rotateForPortrait && tmpBitmap.width > tmpBitmap.height) {
      val matrix = Matrix()
      matrix.postRotate(90f)
      Bitmap.createBitmap(tmpBitmap, 0, 0, tmpBitmap.width, tmpBitmap.height, matrix, true)
    } else {
      tmpBitmap
    }
  } catch (e: Exception) {
    e.printStackTrace()
    null
  }
  if (bitmap != null) {
    onImageSelected(bitmap)
  }
}
```

## 4. 實時相機處理 (Live Camera Processing)

在 `LiveCameraDialog.kt` 中，應用使用 CameraX 捕獲實時相機畫面並處理：

```kotlin
// 啟動相機並處理圖像
private suspend fun startCamera(
  context: android.content.Context,
  lifecycleOwner: androidx.lifecycle.LifecycleOwner,
  onBitmap: (Bitmap) -> Unit,
  onImageBitmap: (ImageBitmap) -> Unit
): ProcessCameraProvider? = suspendCoroutine { continuation ->
  // 設置圖像分析器
  val imageAnalysis = ImageAnalysis.Builder()
    .setResolutionSelector(resolutionSelector)
    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
    .build()
    .also {
      it.setAnalyzer(Executors.newSingleThreadExecutor()) { imageProxy ->
        var bitmap = imageProxy.toBitmap()
        val rotation = imageProxy.imageInfo.rotationDegrees
        bitmap = if (rotation != 0) {
          val matrix = Matrix().apply {
            postRotate(rotation.toFloat())
          }
          Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        } else bitmap
        onBitmap(bitmap)
        onImageBitmap(bitmap.asImageBitmap())
        imageProxy.close()
      }
    }
}
```

## 5. LLM 聊天視圖模型 (LLM Chat ViewModel)

在 `LlmChatViewModel.kt` 中，應用協調圖像處理和模型響應：

```kotlin
// 生成響應（支持圖像輸入）
fun generateResponse(model: Model, input: String, image: Bitmap? = null, onError: () -> Unit) {
  viewModelScope.launch(Dispatchers.Default) {
    // 等待模型初始化
    while (model.instance == null) {
      delay(100)
    }
    
    // 運行推理
    val instance = model.instance as LlmModelInstance
    var prefillTokens = instance.session.sizeInTokens(input)
    if (image != null) {
      prefillTokens += 257  // 圖像令牌數
    }
    
    try {
      LlmChatModelHelper.runInference(
        model = model,
        input = input,
        image = image,
        resultListener = { partialResult, done ->
          // 處理部分結果和完成狀態
        },
        cleanUpListener = {
          // 清理資源
        }
      )
    } catch (e: Exception) {
      Log.e(TAG, "Error occurred while running inference", e)
      onError()
    }
  }
}
```

## 總結

Google AI Edge Gallery Android 應用使用 MediaPipe 框架處理圖像並與模型互動的主要方式包括：

1. **圖像生成**：使用 MediaPipe ImageGenerator 任務從文本提示生成圖像
2. **多模態 LLM**：使用 MediaPipe LlmInference 任務處理文本和圖像輸入，支持視覺語言模型
3. **圖像輸入處理**：提供從相冊選擇、拍照和實時相機流三種方式獲取圖像
4. **實時相機處理**：使用 CameraX 和自定義圖像分析器處理實時相機畫面
5. **視圖模型協調**：使用 ViewModel 協調圖像處理和模型響應的整個流程

這些代碼片段展示了如何在 Android 應用中使用 MediaPipe 框架處理圖像並與 Gemma 等本地模型互動，實現高效的邊緣 AI 應用。