package com.cypherstack.mobile_app_privacy

import android.app.Activity
import android.graphics.Color
import android.graphics.drawable.Drawable
import android.view.View
import android.view.WindowManager.LayoutParams
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import com.caverock.androidsvg.SVG
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** MobileAppPrivacyPlugin */
class MobileAppPrivacyPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding
    private var activity: Activity? = null
    private var overlayView: View? = null
    private val accessibilityPrivacy = AccessibilityPrivacy()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "mobile_app_privacy")
        channel.setMethodCallHandler(this)
        binding = flutterPluginBinding
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "setAccessibilityDataSensitive" -> {
                val enabled = call.argument<Any>("enable") as? Boolean
                if (enabled == null) {
                    result.error("invalid_argument", "enable must be a boolean", null)
                } else {
                    result.success(accessibilityPrivacy.setEnabled(enabled))
                }
            }
            "isAccessibilityDataSensitive" -> result.success(accessibilityPrivacy.isEnabled())
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "enableOverlay" -> {
                val iconAsset = call.argument<Map<String, Any>>("iconAsset")
                // The codec decodes ARGB values as Integer or Long depending on their size.
                val color = call.argument<Number>("color")?.toInt() ?: Color.argb(255, 0, 255, 0)
                enableOverlay(color, iconAsset)
                result.success(null)
            }

            "disableOverlay" -> {
                disableOverlay()
                result.success(null)
            }

            "setFlagSecure" -> {
                val enable = call.argument<Boolean>("enable") == true
                activity?.window?.let { window ->
                    if (enable) {
                        window.setFlags(
                            LayoutParams.FLAG_SECURE, LayoutParams.FLAG_SECURE
                        )
                    } else {
                        window.clearFlags(LayoutParams.FLAG_SECURE)
                    }
                }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        accessibilityPrivacy.detach()
    }

    private fun enableOverlay(color: Int, iconAsset: Map<String, Any>?) {
        val act = activity ?: return
        if (overlayView != null) return // already added

        val root = act.window?.decorView as? ViewGroup ?: return

        // Container for background + icon
        val container = FrameLayout(act).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT
            )
            isClickable = true
            isFocusable = true
        }

        // Fullscreen background
        val colorView = View(act).apply {
            setBackgroundColor(color)
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        container.addView(colorView)

        // Try to load Flutter asset if provided
        if (iconAsset != null) {
            val path = iconAsset["assetPath"] as? String
            val widthDp = (iconAsset["width"] as? Number)?.toFloat()
            val heightDp = (iconAsset["height"] as? Number)?.toFloat()

            val binding = this.binding
            if (path != null && widthDp != null && heightDp != null) {
                try {
                    val flutterAssets = binding.flutterAssets
                    val assetPath = flutterAssets.getAssetFilePathBySubpath(path)

                    // Try SVG first, fallback to raster
                    val drawable: Drawable? = try {
                        binding.applicationContext.assets.open(assetPath).use { svgInput ->
                            val svg = SVG.getFromInputStream(svgInput)
                            android.graphics.drawable.PictureDrawable(svg.renderToPicture())
                        }
                    } catch (svgEx: Exception) {
                        Log.w("Overlay", "SVG parse failed, fallback to raster.", svgEx)
                        try {
                            binding.applicationContext.assets.open(assetPath).use { rasterInput ->
                                Drawable.createFromStream(rasterInput, null)
                            }
                        } catch (rasterEx: Exception) {
                            Log.e(
                                "Overlay",
                                "Failed to parse as raster: ${rasterEx.message}",
                                rasterEx
                            )
                            null
                        }
                    }

                    drawable?.let { d ->
                        val density = act.resources.displayMetrics.density
                        val widthPx = (widthDp * density).toInt()
                        val heightPx = (heightDp * density).toInt()

                        val iconView = ImageView(act).apply {
                            layoutParams = FrameLayout.LayoutParams(widthPx, heightPx).apply {
                                gravity = android.view.Gravity.CENTER
                            }
                            setImageDrawable(d)
                            scaleType = ImageView.ScaleType.FIT_CENTER
                        }
                        container.addView(iconView)
                    }
                } catch (e: Exception) {
                    Log.e("Overlay", "Failed to load icon asset: ${e.message}", e)
                }
            }
        }

        root.addView(container)
        overlayView = container
    }

    private fun disableOverlay() {
        val act = activity ?: return
        val root = act.window?.decorView as? ViewGroup ?: return
        overlayView?.let { root.removeView(it) }
        overlayView = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        accessibilityPrivacy.attach(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        accessibilityPrivacy.detach()
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        accessibilityPrivacy.attach(binding.activity)
    }

    override fun onDetachedFromActivity() {
        accessibilityPrivacy.detach()
        activity = null
    }
}
