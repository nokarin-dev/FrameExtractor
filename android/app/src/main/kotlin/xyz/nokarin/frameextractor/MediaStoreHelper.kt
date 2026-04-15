package xyz.nokarin.frameextractor

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.FileInputStream

object MediaStoreHelper {
    fun copyFramesToUri(
        context: Context,
        sourceDir: String,
        targetDirUri: Uri,
        subfolderName: String? = null,
    ): Int {
        return try {
            val srcDir = File(sourceDir)
            val files = srcDir.listFiles { f ->
                f.isFile && f.extension.lowercase() in listOf("jpg", "jpeg", "png", "webp", "bmp")
            }?.sortedBy { it.name } ?: return 0

            var targetDoc = androidx.documentfile.provider.DocumentFile.fromTreeUri(context, targetDirUri)
                ?: return -1

            if (subfolderName != null) {
                targetDoc = targetDoc.findFile(subfolderName)
                    ?: targetDoc.createDirectory(subfolderName)
                    ?: return -1
            }

            var copied = 0
            for (file in files) {
                val mimeType = when (file.extension.lowercase()) {
                    "jpg", "jpeg" -> "image/jpeg"
                    "png" -> "image/png"
                    "webp" -> "image/webp"
                    "bmp" -> "image/bmp"
                    else -> "image/jpeg"
                }

                val newDoc = targetDoc.createFile(mimeType, file.nameWithoutExtension)
                    ?: continue

                context.contentResolver.openOutputStream(newDoc.uri)?.use { out ->
                    FileInputStream(file).use { inp -> inp.copyTo(out) }
                    copied++
                }
            }
            copied
        } catch (e: Exception) {
            e.printStackTrace()
            -1
        }
    }
}