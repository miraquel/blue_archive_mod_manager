package com.example.bamm

import android.content.ComponentName
import android.content.Context
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.IBinder
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku

class ShizukuBridgePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null
    private var fileService: IFileService? = null
    private var isServiceBound = false

    private val binderReceivedListener = Shizuku.OnBinderReceivedListener {
        Log.d(TAG, "Binder received")
        channel.invokeMethod("onBinderReceived", null)
    }

    private val binderDeadListener = Shizuku.OnBinderDeadListener {
        Log.d(TAG, "Binder dead")
        fileService = null
        isServiceBound = false
        channel.invokeMethod("onBinderDead", null)
    }

    private val requestPermissionResultListener =
        Shizuku.OnRequestPermissionResultListener { _, _ -> }

    private val userServiceArgs = Shizuku.UserServiceArgs(
        ComponentName(BuildConfig.APPLICATION_ID, FileService::class.java.name)
    ).daemon(false).processNameSuffix("file_service").debuggable(BuildConfig.DEBUG).version(1)

    private val userServiceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            if (service?.pingBinder() == true) {
                fileService = IFileService.Stub.asInterface(service)
                isServiceBound = true
                Log.d(TAG, "FileService connected")
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            fileService = null
            isServiceBound = false
            Log.d(TAG, "FileService disconnected")
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.example.bamm/shizuku")
        channel.setMethodCallHandler(this)

        Shizuku.addBinderReceivedListenerSticky(binderReceivedListener)
        Shizuku.addBinderDeadListener(binderDeadListener)
        Shizuku.addRequestPermissionResultListener(requestPermissionResultListener)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        Shizuku.removeBinderReceivedListener(binderReceivedListener)
        Shizuku.removeBinderDeadListener(binderDeadListener)
        Shizuku.removeRequestPermissionResultListener(requestPermissionResultListener)
        applicationContext = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pingBinder" -> result.success(Shizuku.pingBinder())

            "checkPermission" -> {
                val granted = try {
                    Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
                } catch (e: Exception) {
                    false
                }
                result.success(granted)
            }

            "requestPermission" -> {
                try {
                    if (Shizuku.isPreV11()) {
                        result.success(false)
                        return
                    }
                    if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                        return
                    }
                    val code = 42
                    Shizuku.addRequestPermissionResultListener(object :
                        Shizuku.OnRequestPermissionResultListener {
                        override fun onRequestPermissionResult(
                            requestCode: Int,
                            grantResult: Int
                        ) {
                            if (requestCode == code) {
                                Shizuku.removeRequestPermissionResultListener(this)
                                result.success(grantResult == PackageManager.PERMISSION_GRANTED)
                            }
                        }
                    })
                    Shizuku.requestPermission(code)
                } catch (e: Exception) {
                    result.error("PERMISSION_ERROR", e.message, null)
                }
            }

            "getVersion" -> {
                result.success(try {
                    Shizuku.getVersion()
                } catch (e: Exception) {
                    -1
                })
            }

            "bindService" -> {
                try {
                    Shizuku.bindUserService(userServiceArgs, userServiceConnection)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("BIND_ERROR", e.message, null)
                }
            }

            "unbindService" -> {
                try {
                    Shizuku.unbindUserService(userServiceArgs, userServiceConnection, true)
                    fileService = null
                    isServiceBound = false
                    result.success(true)
                } catch (e: Exception) {
                    result.error("UNBIND_ERROR", e.message, null)
                }
            }

            "isServiceBound" -> result.success(isServiceBound)

            "fileExists" -> {
                val path = call.argument<String>("path")
                val service = fileService
                if (path == null || service == null) {
                    result.error("INVALID", "Path null or service not bound", null)
                    return
                }
                result.success(service.fileExists(path))
            }

            "readFile" -> {
                val path = call.argument<String>("path")
                val service = fileService
                if (path == null || service == null) {
                    result.error("INVALID", "Path null or service not bound", null)
                    return
                }
                result.success(service.readFile(path))
            }

            "writeFile" -> {
                val path = call.argument<String>("path")
                val data = call.argument<ByteArray>("data")
                val service = fileService
                if (path == null || data == null || service == null) {
                    result.error("INVALID", "Args null or service not bound", null)
                    return
                }
                result.success(service.writeFile(path, data))
            }

            "copyFile" -> {
                val source = call.argument<String>("source")
                val dest = call.argument<String>("dest")
                val service = fileService
                if (source == null || dest == null || service == null) {
                    result.error("INVALID", "Args null or service not bound", null)
                    return
                }
                result.success(service.copyFile(source, dest))
            }

            "deleteFile" -> {
                val path = call.argument<String>("path")
                val service = fileService
                if (path == null || service == null) {
                    result.error("INVALID", "Path null or service not bound", null)
                    return
                }
                result.success(service.deleteFile(path))
            }

            "listFiles" -> {
                val path = call.argument<String>("path")
                val service = fileService
                if (path == null || service == null) {
                    result.error("INVALID", "Path null or service not bound", null)
                    return
                }
                result.success(service.listFiles(path))
            }

            "createDirectory" -> {
                val path = call.argument<String>("path")
                val service = fileService
                if (path == null || service == null) {
                    result.error("INVALID", "Path null or service not bound", null)
                    return
                }
                result.success(service.createDirectory(path))
            }

            "isDirectory" -> {
                val path = call.argument<String>("path")
                val service = fileService
                if (path == null || service == null) {
                    result.error("INVALID", "Path null or service not bound", null)
                    return
                }
                result.success(service.isDirectory(path))
            }

            "getFileSize" -> {
                val path = call.argument<String>("path")
                val service = fileService
                if (path == null || service == null) {
                    result.error("INVALID", "Path null or service not bound", null)
                    return
                }
                result.success(service.getFileSize(path))
            }

            "isPackageInstalled" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName == null) {
                    result.error("INVALID", "packageName required", null)
                    return
                }
                result.success(isPackageInstalled(packageName))
            }

            "launchPackage" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName == null) {
                    result.error("INVALID", "packageName required", null)
                    return
                }
                result.success(launchPackage(packageName))
            }

            else -> result.notImplemented()
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        val ctx = applicationContext ?: return false
        return try {
            ctx.packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun launchPackage(packageName: String): Boolean {
        val ctx = applicationContext ?: return false
        return try {
            val intent = ctx.packageManager.getLaunchIntentForPackage(packageName) ?: return false
            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "launchPackage error: ${e.message}")
            false
        }
    }

    companion object {
        private const val TAG = "ShizukuBridgePlugin"
    }
}
