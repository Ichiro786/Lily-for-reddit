package com.example.lilyforreddit.data.repository

import android.content.Context
import android.content.SharedPreferences
import com.example.lilyforreddit.data.models.PostDisplay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class ThemeMode {
    SYSTEM, LIGHT, DARK
}

enum class TopBarMode {
    FULL, EXPANDABLE, COMPACT
}

data class AppSettings(
    val themeMode: ThemeMode = ThemeMode.SYSTEM,
    val dynamicColor: Boolean = true,
    val forYouFeed: Boolean = true,
    val postDisplay: PostDisplay = PostDisplay.CARD,
    val autoplayMedia: Boolean = true,
    val blurNsfw: Boolean = true,
    val blurSpoiler: Boolean = true,
    val showApiUsage: Boolean = false,
    val topBarMode: TopBarMode = TopBarMode.FULL,
    val currentUsername: String = "redditor"
)

class SettingsRepository(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("lily_settings", Context.MODE_PRIVATE)

    private val _settings = MutableStateFlow(loadSettings())
    val settings: StateFlow<AppSettings> = _settings.asStateFlow()

    private fun loadSettings(): AppSettings {
        val themeOrdinal = prefs.getInt("theme_mode", ThemeMode.SYSTEM.ordinal)
        val dynamicColor = prefs.getBoolean("dynamic_color", true)
        val forYouFeed = prefs.getBoolean("for_you_feed", true)
        val postDisplayOrdinal = prefs.getInt("post_display", PostDisplay.CARD.ordinal)
        val autoplay = prefs.getBoolean("autoplay_media", true)
        val blurNsfw = prefs.getBoolean("blur_nsfw", true)
        val blurSpoiler = prefs.getBoolean("blur_spoiler", true)
        val showApiUsage = prefs.getBoolean("show_api_usage", false)
        val topBarOrdinal = prefs.getInt("top_bar_mode", TopBarMode.FULL.ordinal)
        val username = prefs.getString("current_username", "redditor") ?: "redditor"

        return AppSettings(
            themeMode = ThemeMode.entries.getOrElse(themeOrdinal) { ThemeMode.SYSTEM },
            dynamicColor = dynamicColor,
            forYouFeed = forYouFeed,
            postDisplay = PostDisplay.entries.getOrElse(postDisplayOrdinal) { PostDisplay.CARD },
            autoplayMedia = autoplay,
            blurNsfw = blurNsfw,
            blurSpoiler = blurSpoiler,
            showApiUsage = showApiUsage,
            topBarMode = TopBarMode.entries.getOrElse(topBarOrdinal) { TopBarMode.FULL },
            currentUsername = username
        )
    }

    fun setThemeMode(mode: ThemeMode) {
        prefs.edit().putInt("theme_mode", mode.ordinal).apply()
        _settings.value = _settings.value.copy(themeMode = mode)
    }

    fun setDynamicColor(enabled: Boolean) {
        prefs.edit().putBoolean("dynamic_color", enabled).apply()
        _settings.value = _settings.value.copy(dynamicColor = enabled)
    }

    fun setForYouFeed(enabled: Boolean) {
        prefs.edit().putBoolean("for_you_feed", enabled).apply()
        _settings.value = _settings.value.copy(forYouFeed = enabled)
    }

    fun setPostDisplay(display: PostDisplay) {
        prefs.edit().putInt("post_display", display.ordinal).apply()
        _settings.value = _settings.value.copy(postDisplay = display)
    }

    fun setAutoplayMedia(enabled: Boolean) {
        prefs.edit().putBoolean("autoplay_media", enabled).apply()
        _settings.value = _settings.value.copy(autoplayMedia = enabled)
    }

    fun setBlurNsfw(enabled: Boolean) {
        prefs.edit().putBoolean("blur_nsfw", enabled).apply()
        _settings.value = _settings.value.copy(blurNsfw = enabled)
    }

    fun setBlurSpoiler(enabled: Boolean) {
        prefs.edit().putBoolean("blur_spoiler", enabled).apply()
        _settings.value = _settings.value.copy(blurSpoiler = enabled)
    }

    fun setTopBarMode(mode: TopBarMode) {
        prefs.edit().putInt("top_bar_mode", mode.ordinal).apply()
        _settings.value = _settings.value.copy(topBarMode = mode)
    }

    fun setUsername(name: String) {
        prefs.edit().putString("current_username", name).apply()
        _settings.value = _settings.value.copy(currentUsername = name)
    }
}
