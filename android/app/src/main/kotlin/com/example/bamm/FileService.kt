package com.example.bamm

import android.content.Context
import android.os.RemoteException
import android.system.Os
import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest
import kotlin.math.min

class FileService : IFileService.Stub {
    companion object {
        private const val TAG = "FileService"
    }

    constructor() {
        Log.i(TAG, "constructor (no context)")
    }

    constructor(context: Context) {
        Log.i(TAG, "constructor with context: pid=${Os.getpid()}, uid=${Os.getuid()}")
    }

    override fun fileExists(path: String): Boolean {
        return try {
            File(path).exists()
        } catch (e: Exception) {
            Log.e(TAG, "fileExists error: ${e.message}")
            false
        }
    }

    override fun readFile(path: String): ByteArray? {
        return try {
            File(path).readBytes()
        } catch (e: Exception) {
            Log.e(TAG, "readFile error: ${e.message}")
            null
        }
    }

    override fun writeFile(path: String, data: ByteArray): Boolean {
        return try {
            File(path).writeBytes(data)
            true
        } catch (e: Exception) {
            Log.e(TAG, "writeFile error: ${e.message}")
            false
        }
    }

    override fun copyFile(sourcePath: String, destPath: String): Boolean {
        return try {
            File(sourcePath).copyTo(File(destPath), overwrite = true)
            true
        } catch (e: Exception) {
            Log.e(TAG, "copyFile error: ${e.message}")
            false
        }
    }

    override fun deleteFile(path: String): Boolean {
        return try {
            File(path).delete()
        } catch (e: Exception) {
            Log.e(TAG, "deleteFile error: ${e.message}")
            false
        }
    }

    override fun listFiles(directoryPath: String): List<String> {
        return try {
            File(directoryPath).listFiles()?.map { it.absolutePath } ?: emptyList()
        } catch (e: Exception) {
            Log.e(TAG, "listFiles error: ${e.message}")
            emptyList()
        }
    }

    override fun listFilesPage(directoryPath: String, offset: Int, limit: Int): List<String> {
        return try {
            if (limit <= 0 || offset < 0) {
                emptyList()
            } else {
                val children = File(directoryPath)
                    .listFiles()
                    ?.map { it.name }
                    ?.sorted()
                    ?: emptyList()
                if (offset >= children.size) {
                    emptyList()
                } else {
                    children.subList(offset, min(offset + limit, children.size))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "listFilesPage error: ${e.message}")
            emptyList()
        }
    }

    override fun createDirectory(path: String): Boolean {
        return try {
            File(path).mkdirs()
        } catch (e: Exception) {
            Log.e(TAG, "createDirectory error: ${e.message}")
            false
        }
    }

    override fun isDirectory(path: String): Boolean {
        return try {
            File(path).isDirectory
        } catch (e: Exception) {
            Log.e(TAG, "isDirectory error: ${e.message}")
            false
        }
    }

    override fun getFileSize(path: String): Long {
        return try {
            File(path).length()
        } catch (e: Exception) {
            Log.e(TAG, "getFileSize error: ${e.message}")
            -1
        }
    }

    override fun getFileMd5(path: String): String? {
        return try {
            val digest = MessageDigest.getInstance("MD5")
            FileInputStream(File(path)).use { input ->
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                while (true) {
                    val read = input.read(buffer)
                    if (read <= 0) {
                        break
                    }
                    digest.update(buffer, 0, read)
                }
            }
            digest.digest().joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            Log.e(TAG, "getFileMd5 error: ${e.message}")
            null
        }
    }

    override fun destroy() {
        Log.i(TAG, "destroy")
        System.exit(0)
    }

    override fun exit() {
        destroy()
    }
}
