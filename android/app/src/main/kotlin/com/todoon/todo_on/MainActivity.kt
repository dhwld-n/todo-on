package com.todoon.todo_on

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Its own subclass so it can't clash with a plugin's FileProvider entry. */
class UpdateFileProvider : FileProvider()

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // In-app update: Dart downloads the apk to [apkPath], then
        // [installApk] hands it to the system installer - no browser, so no
        // hunting for the file in Downloads.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "todo_on/update")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "apkPath" -> {
                        val dir = File(cacheDir, "updates").apply { mkdirs() }
                        result.success(File(dir, "TODOon-update.apk").absolutePath)
                    }
                    "installApk" -> {
                        val file = File(call.argument<String>("path")!!)
                        val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
                        startActivity(Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_ACTIVITY_NEW_TASK
                            )
                        })
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
