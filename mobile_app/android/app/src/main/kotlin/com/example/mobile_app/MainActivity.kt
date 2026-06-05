package com.example.mobile_app

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "codex_mobile/pdf_renderer"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "renderPdf" -> {
                    try {
                        val bytes = call.argument<ByteArray>("bytes")
                        val maxWidth = call.argument<Int>("maxWidth") ?: 1440
                        if (bytes == null || bytes.isEmpty()) {
                            result.success(emptyList<ByteArray>())
                            return@setMethodCallHandler
                        }
                        result.success(renderPdf(bytes, maxWidth))
                    } catch (error: Throwable) {
                        result.error("pdf_render_failed", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun renderPdf(bytes: ByteArray, maxWidth: Int): List<ByteArray> {
        val pdfFile = File.createTempFile("codex-mobile-preview", ".pdf", cacheDir)
        pdfFile.writeBytes(bytes)
        val descriptor = ParcelFileDescriptor.open(
            pdfFile,
            ParcelFileDescriptor.MODE_READ_ONLY
        )
        try {
            PdfRenderer(descriptor).use { renderer ->
                val pages = ArrayList<ByteArray>(renderer.pageCount)
                for (index in 0 until renderer.pageCount) {
                    renderer.openPage(index).use { page ->
                        val safePageWidth = page.width.coerceAtLeast(1).toFloat()
                        val safeMaxWidth = maxWidth.coerceAtLeast(320).toFloat()
                        val scale = (safeMaxWidth / safePageWidth).coerceIn(0.25f, 3f)
                        val width = (page.width * scale).toInt().coerceAtLeast(1)
                        val height = (page.height * scale).toInt().coerceAtLeast(1)
                        val bitmap = Bitmap.createBitmap(
                            width,
                            height,
                            Bitmap.Config.ARGB_8888
                        )
                        bitmap.eraseColor(Color.WHITE)
                        page.render(
                            bitmap,
                            null,
                            null,
                            PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY
                        )
                        val output = ByteArrayOutputStream()
                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
                        bitmap.recycle()
                        pages.add(output.toByteArray())
                    }
                }
                return pages
            }
        } finally {
            descriptor.close()
            pdfFile.delete()
        }
    }
}
