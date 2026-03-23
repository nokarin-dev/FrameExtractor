package com.nokarin.frameextractor

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.os.Environment

object UriHelper {
    fun getPathFromUri(context: Context, uri: Uri): String? {
        val scheme = uri.scheme ?: return null

        if (scheme == "file") return uri.path

        if (scheme != "content") return null

        if (DocumentsContract.isTreeUri(uri)) {
            return getTreeUriPath(context, uri)
        }

        if (DocumentsContract.isDocumentUri(context, uri)) {
            return getDocumentUriPath(context, uri)
        }

        return queryContentPath(context, uri)
    }

    private fun getTreeUriPath(context: Context, treeUri: Uri): String? {
        return try {
            val docId = DocumentsContract.getTreeDocumentId(treeUri)
            val parts = docId.split(":")
            if (parts.size < 2) return null

            val type = parts[0]
            val relativePath = parts[1]

            when {
                type.equals("primary", ignoreCase = true) -> {
                    "${Environment.getExternalStorageDirectory()}/$relativePath"
                }
                type.equals("home", ignoreCase = true) -> {
                    "${Environment.getExternalStorageDirectory()}/Documents/$relativePath"
                }
                else -> {
                    val storageDir = context.getExternalFilesDirs(null)
                        .firstOrNull { it?.absolutePath?.contains(type) == true }
                        ?.absolutePath
                        ?.substringBefore("/Android") ?: return null
                    "$storageDir/$relativePath"
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun getDocumentUriPath(context: Context, uri: Uri): String? {
        return try {
            val docId = DocumentsContract.getDocumentId(uri)
            val parts = docId.split(":")
            if (parts.size < 2) return queryContentPath(context, uri)

            val type = parts[0]
            val relativePath = parts[1]

            when {
                type.equals("primary", ignoreCase = true) ->
                    "${Environment.getExternalStorageDirectory()}/$relativePath"
                else -> queryContentPath(context, uri)
            }
        } catch (_: Exception) {
            queryContentPath(context, uri)
        }
    }

    private fun queryContentPath(context: Context, uri: Uri): String? {
        return try {
            context.contentResolver.query(
                uri, arrayOf(MediaStore.MediaColumns.DATA),
                null, null, null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
                    if (idx >= 0) cursor.getString(idx) else null
                } else null
            }
        } catch (_: Exception) {
            null
        }
    }
}