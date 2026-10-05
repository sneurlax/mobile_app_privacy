package com.cypherstack.mobile_app_privacy

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import org.mockito.Mockito
import kotlin.test.Test

/*
 * This demonstrates a simple unit test of the Kotlin portion of this plugin's implementation.
 *
 * Once you have built the plugin's example app, you can run these tests from the command
 * line by running `./gradlew testDebugUnitTest` in the `example/android/` directory, or
 * you can run them directly from IDEs that support JUnit such as Android Studio.
 */

internal class MobileAppPrivacyPluginTest {
    @Test
    fun onMethodCall_enableOverlay_acceptsBothCodecIntegerWidths() {
        // Match Dart's ARGB values on both sides of the signed 32-bit boundary.
        // No Activity is needed: argument decoding happens before the overlay
        // implementation checks whether an Activity is attached.
        for (color in listOf<Number>(0, 0x7f112233, 0x7fffffff, 0x80000000L, 0xffffffffL)) {
            val codec = StandardMethodCodec.INSTANCE
            val encoded = codec.encodeMethodCall(MethodCall("enableOverlay", mapOf("color" to color)))
            encoded.flip()
            val call = codec.decodeMethodCall(encoded)
            val result = Mockito.mock(MethodChannel.Result::class.java)

            MobileAppPrivacyPlugin().onMethodCall(call, result)

            Mockito.verify(result).success(null)
        }
    }

    @Test
    fun onMethodCall_getPlatformVersion_returnsExpectedValue() {
        val plugin = MobileAppPrivacyPlugin()

        val call = MethodCall("getPlatformVersion", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).success("Android " + android.os.Build.VERSION.RELEASE)
    }
}
