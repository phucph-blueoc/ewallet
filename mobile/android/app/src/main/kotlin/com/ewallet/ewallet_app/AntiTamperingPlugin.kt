package com.ewallet.ewallet_app

import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class AntiTamperingPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.ewallet.ewallet_app/anti_tampering")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getAppSignature" -> {
                try {
                    val signatureHash = getAppSignatureHash()
                    result.success(signatureHash)
                } catch (e: Exception) {
                    Log.e("AntiTampering", "Error getting app signature", e)
                    result.error("SIGNATURE_ERROR", "Failed to get app signature: ${e.message}", null)
                }
            }
            "getPackageName" -> {
                try {
                    val packageName = context.packageName
                    result.success(packageName)
                } catch (e: Exception) {
                    Log.e("AntiTampering", "Error getting package name", e)
                    result.error("PACKAGE_ERROR", "Failed to get package name: ${e.message}", null)
                }
            }
            "isInstalledFromPlayStore" -> {
                try {
                    val isPlayStore = isInstalledFromPlayStore()
                    result.success(isPlayStore)
                } catch (e: Exception) {
                    Log.e("AntiTampering", "Error checking installation source", e)
                    result.error("INSTALL_ERROR", "Failed to check installation source: ${e.message}", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun getAppSignatureHash(): String? {
        return try {
            val packageManager = context.packageManager
            val packageName = context.packageName
            
            // Try new API first (API 28+)
            val packageInfo = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNATURES
                )
            }
            
            val signatures = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                packageInfo.signingInfo?.apkContentsSigners?.toList() ?: emptyList()
            } else {
                @Suppress("DEPRECATION")
                packageInfo.signatures?.toList() ?: emptyList()
            }
            
            if (signatures.isNotEmpty()) {
                val signature = signatures[0]
                val md = MessageDigest.getInstance("SHA-256")
                val digest = md.digest(signature.toByteArray())
                digest.joinToString("") { "%02x".format(it) }
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e("AntiTampering", "Error computing signature hash", e)
            null
        }
    }

    private fun isInstalledFromPlayStore(): Boolean {
        return try {
            val installer = context.packageManager.getInstallerPackageName(context.packageName)
            installer == "com.android.vending" || installer == "com.google.android.feedback"
        } catch (e: Exception) {
            Log.e("AntiTampering", "Error checking installation source", e)
            false
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}

