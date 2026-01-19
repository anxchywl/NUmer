package app.anx.numer

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowInsetsController
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    applyPersistedTheme()
  }

  private fun applyPersistedTheme() {
    // Flutter's shared preferences store values in "FlutterSharedPreferences".
    val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    val stored = prefs.getString("flutter.themeMode", null)
      ?: prefs.getString("themeMode", null)

    val preferredMode = when (stored) {
      "light" -> PreferredMode.LIGHT
      "dark" -> PreferredMode.DARK
      else -> PreferredMode.SYSTEM
    }

    val useDark = when (preferredMode) {
      PreferredMode.DARK -> true
      PreferredMode.LIGHT -> false
      PreferredMode.SYSTEM -> {
        val mask = resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        mask == Configuration.UI_MODE_NIGHT_YES
      }
    }

    val backgroundColor = if (useDark) Color.parseColor("#0F172A") else Color.WHITE

    window.setBackgroundDrawable(ColorDrawable(backgroundColor))
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
      window.statusBarColor = backgroundColor
      window.navigationBarColor = backgroundColor
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      val controller = window.insetsController
      controller?.setSystemBarsAppearance(
        if (!useDark) WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS else 0,
        WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
      )
      controller?.setSystemBarsAppearance(
        if (!useDark) WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS else 0,
        WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
      )
    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      var flags = window.decorView.systemUiVisibility
      flags = if (!useDark) {
        flags or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
      } else {
        flags and View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR.inv()
      }
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        flags = if (!useDark) {
          flags or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
        } else {
          flags and View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR.inv()
        }
      }
      window.decorView.systemUiVisibility = flags
    }
  }

  private enum class PreferredMode { LIGHT, DARK, SYSTEM }
}
