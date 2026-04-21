package com.example.bamm

import android.content.ComponentName
import android.content.Context
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.DeadObjectException
import android.os.IBinder
import android.os.RemoteException
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
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
    ).daemon(false).processNameSuffix("file_service").debuggable(BuildConfig.DEBUG).version(2)

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
                if (path == null) {
                    result.error("INVALID", "Path null or service not bound", null)
                    return
                }
                withFileService(result) { service ->
                    service.fileExists(path)
                }
            }

            "readFile" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID", "Path null or service not bound", null)
                    return
                }
                withFileService(result) { service ->
                    readFileCompat(service, path)
                }
            }

            "writeFile" -> {
                val path = call.argument<String>("path")
                val data = call.argument<ByteArray>("data")
                if (path == null || data == null) {
                    result.error("INVALID", "Args null or service not bound", null)
                    return
                }
                withFileService(result) { service ->
                    writeFileCompat(service, path, data)
                }
            }

            "copyFile" -> {
                val source = call.argument<String>("source")
                val dest = call.argument<String>("dest")
                if (source == null || dest == null) {
                    result.error("INVALID", "Args null or service not bound", null)
                    return
                }
                withFileService(result) { service ->
                    service.copyFile(source, dest)
                }
            }

            "deleteFile" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID", "Path null or service not bound", null)
                    return
                }
                withFileService(result) { service ->
                    service.deleteFile(path)
                }
            }

            "listFiles" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID", "Path null or service not bound", null)
                    return
                }
                withFileService(result) { service ->
                    service.listFiles(path)
                }
            }

            "listFilesPage" -> {
                val path = call.argument<String>("path")
                val offset = call.argument<Int>("offset")
                val limit = call.argument<Int>("limit")
                if (path == null || offset == null || limit == null) {
                    result.error("INVALID", "Args null or service not bound", null)
                    return
                }
                withFileService(result) { service ->
                    service.listFilesPage(path, offset, limit)
                }
            }

            "createDirectory" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID", "Path null or service not bound", null)
                    return
                }
                withFileService(result) { service ->
                    service.createDirectory(path)
                }
            }

            "isDirectory" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID", "Path null or service not bound", null)
                    return
                }
                withFileService(result) { service ->
                    service.isDirectory(path)
                }
            }

            "getFileSize" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID", "Path null or service not bound", null)
                    return
                }
                withFileService(result) { service ->
                    service.getFileSize(path)
                }
            }

            "getFileMd5" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID", "Path null or service not bound", null)
                    return
                }
                withFileService(result) { service ->
                    service.getFileMd5(path)
                }
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

            "getPackageVersionCode" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName == null) {
                    result.error("INVALID", "packageName required", null)
                    return
                }
                result.success(getPackageVersionCode(packageName))
            }

            "getPackageVersionName" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName == null) {
                    result.error("INVALID", "packageName required", null)
                    return
                }
                result.success(getPackageVersionName(packageName))
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

    private fun getPackageVersionName(packageName: String): String? {
        val ctx = applicationContext ?: return null
        return try {
            ctx.packageManager.getPackageInfo(packageName, 0).versionName
        } catch (e: PackageManager.NameNotFoundException) {
            null
        }
    }

    private fun getPackageVersionCode(packageName: String): Long {
        val ctx = applicationContext ?: return -1L
        return try {
            val info = ctx.packageManager.getPackageInfo(packageName, 0)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                info.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                info.versionCode.toLong()
            }
        } catch (e: PackageManager.NameNotFoundException) {
            -1L
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

    private fun readFileCompat(service: IFileService, path: String): ByteArray? {
        val size = service.getFileSize(path)
        if (size < 0) {
            return null
        }

        if (size <= FILE_TRANSFER_CHUNK_BYTES) {
            return service.readFile(path)
        }

        Log.i(TAG, "Reading $path in $FILE_TRANSFER_CHUNK_BYTES-byte chunks (size=$size)")
        val output = if (size in 1..Int.MAX_VALUE.toLong()) {
            ByteArrayOutputStream(size.toInt())
        } else {
            ByteArrayOutputStream()
        }
        var offset = 0L

        while (offset < size) {
            val chunkLength = minOf(FILE_TRANSFER_CHUNK_BYTES.toLong(), size - offset).toInt()
            val chunk = service.readFileChunk(path, offset, chunkLength)
            if (chunk == null) {
                Log.e(TAG, "readFileChunk returned null for $path at offset=$offset")
                return null
            }
            if (chunk.isEmpty()) {
                Log.e(TAG, "readFileChunk returned empty data before EOF for $path at offset=$offset")
                return null
            }

            output.write(chunk)
            offset += chunk.size.toLong()
        }

        return output.toByteArray()
    }

    private fun writeFileCompat(service: IFileService, path: String, data: ByteArray): Boolean {
        if (data.size <= FILE_TRANSFER_CHUNK_BYTES) {
            return service.writeFile(path, data)
        }

        Log.i(TAG, "Writing $path in $FILE_TRANSFER_CHUNK_BYTES-byte chunks (size=${data.size})")
        var offset = 0
        var truncate = true

        while (offset < data.size) {
            val endExclusive = minOf(offset + FILE_TRANSFER_CHUNK_BYTES, data.size)
            val chunk = data.copyOfRange(offset, endExclusive)
            if (!service.writeFileChunk(path, chunk, offset.toLong(), truncate)) {
                Log.e(TAG, "writeFileChunk failed for $path at offset=$offset")
                return false
            }

            truncate = false
            offset = endExclusive
        }

        return true
    }

    private inline fun <T> withFileService(
        result: MethodChannel.Result,
        block: (IFileService) -> T
    ) {
        val service = fileService
        if (service == null) {
            result.error("INVALID", "Service not bound", null)
            return
        }

        try {
            result.success(block(service))
        } catch (e: DeadObjectException) {
            fileService = null
            isServiceBound = false
            Log.e(TAG, "UserService died: ${e.message}", e)
            result.error("SERVICE_DEAD", "Shizuku file service died", null)
        } catch (e: RemoteException) {
            Log.e(TAG, "RemoteException: ${e.message}", e)
            result.error("REMOTE_ERROR", e.message, null)
        } catch (e: Exception) {
            Log.e(TAG, "Service call failed: ${e.message}", e)
            result.error("SERVICE_ERROR", e.message, null)
        }
    }

    companion object {
        private const val TAG = "ShizukuBridgePlugin"
        private const val FILE_TRANSFER_CHUNK_BYTES = 256 * 1024
    }
}
