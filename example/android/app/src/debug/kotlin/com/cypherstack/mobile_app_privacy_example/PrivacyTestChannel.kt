package com.cypherstack.mobile_app_privacy_example

import android.app.Activity
import android.graphics.drawable.ColorDrawable
import android.os.Build
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.ImageView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

internal fun FlutterEngine.registerPrivacyTestChannel(activity: Activity) {
    MethodChannel(dartExecutor.binaryMessenger, "mobile_app_privacy_example/test")
        .setMethodCallHandler { call, result ->
            when (call.method) {
                "clearEvents" -> {
                    ToolProbeService.instance?.events?.clear()
                    NonToolProbeService.instance?.events?.clear()
                    result.success(null)
                }
                "snapshot" -> {
                    val root = activity.window.decorView as ViewGroup
                    val last = root.getChildAt(root.childCount - 1) as? ViewGroup
                    val images = (0 until (last?.childCount ?: 0))
                        .mapNotNull { last?.getChildAt(it) as? ImageView }
                        .filter { it.drawable != null }
                    result.success(mapOf(
                        "sdkInt" to Build.VERSION.SDK_INT,
                        "secure" to (activity.window.attributes.flags and
                            WindowManager.LayoutParams.FLAG_SECURE != 0),
                        "decorChildren" to root.childCount,
                        "overlayColor" to ((last?.getChildAt(0)?.background as? ColorDrawable)?.color),
                        "overlayImages" to images.size,
                        "imageWidth" to images.firstOrNull()?.layoutParams?.width,
                        "imageHeight" to images.firstOrNull()?.layoutParams?.height,
                        "density" to activity.resources.displayMetrics.density.toDouble(),
                        "toolConnected" to (ToolProbeService.instance != null),
                        "nonToolConnected" to (NonToolProbeService.instance != null),
                        "toolTree" to ToolProbeService.instance?.tree(),
                        "nonToolTree" to NonToolProbeService.instance?.tree(),
                        "toolEvents" to ToolProbeService.instance?.events?.toList(),
                        "nonToolEvents" to NonToolProbeService.instance?.events?.toList()
                    ))
                }
                else -> result.notImplemented()
            }
        }
}
