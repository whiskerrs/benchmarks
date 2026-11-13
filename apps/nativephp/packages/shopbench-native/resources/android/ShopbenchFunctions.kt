package dev.whiskerrs.shopbench.plugin

import androidx.fragment.app.FragmentActivity
import com.nativephp.mobile.bridge.BridgeFunction
import com.nativephp.mobile.bridge.BridgeResponse

object ShopbenchFunctions {
    /** Shopbench.Log — writes `message` to logcat. */
    class Log(@Suppress("unused") private val activity: FragmentActivity) : BridgeFunction {
        override fun execute(parameters: Map<String, Any>): Map<String, Any> {
            val message = parameters["message"] as? String ?: ""
            android.util.Log.i("SHOPBENCH", message)
            return BridgeResponse.success(mapOf())
        }
    }
}
