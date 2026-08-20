package com.example.lilyforreddit.data.models

import kotlinx.serialization.Serializable

enum class PostType {
    SELF, IMAGE, VIDEO, GIF, GALLERY, LINK
}

enum class PostSort(val path: String, val label: String) {
    BEST("best", "Best"),
    HOT("hot", "Hot"),
    NEWEST("new", "New"),
    TOP("top", "Top"),
    RISING("rising", "Rising");

    val needsTime: Boolean get() = this == TOP
}

enum class TopTime(val param: String, val label: String) {
    HOUR("hour", "Now"),
    DAY("day", "Today"),
    WEEK("week", "This week"),
    MONTH("month", "This month"),
    YEAR("year", "This year"),
    ALL("all", "All time")
}

enum class PostDisplay(val label: String) {
    CARD("Card"),
    COMPACT("Compact"),
    MEDIA_FOCUSED("Media Focused")
}

@Serializable
data class GalleryItem(
    val url: String,
    val width: Int? = null,
    val height: Int? = null,
    val caption: String? = null
)

@Serializable
data class Post(
    val id: String,
    val fullname: String,
    val title: String,
    val subreddit: String,
    val subredditPrefixed: String = "r/$subreddit",
    val author: String,
    val score: Int = 0,
    val numComments: Int = 0,
    val upvoteRatio: Double = 1.0,
    val createdUtc: Long = System.currentTimeMillis() / 1000,
    val permalink: String = "",
    val url: String = "",
    val domain: String = "",
    val type: PostType = PostType.SELF,
    val isSelf: Boolean = false,
    val selftext: String = "",
    val over18: Boolean = false,
    val spoiler: Boolean = false,
    val stickied: Boolean = false,
    val locked: Boolean = false,
    val saved: Boolean = false,
    val canModPost: Boolean = false,
    val linkFlairText: String? = null,
    val distinguished: String? = null,
    val feedReason: String? = null,
    val crosspostFrom: String? = null,
    val pollOptions: List<String> = emptyList(),
    val thumbnailUrl: String? = null,
    val previewUrl: String? = null,
    val previewWidth: Int? = null,
    val previewHeight: Int? = null,
    val hlsUrl: String? = null,
    val fallbackVideoUrl: String? = null,
    val gallery: List<GalleryItem> = emptyList(),
    val likes: Boolean? = null // true = up, false = down, null = none
) {
    val hasMedia: Boolean get() = previewUrl != null || gallery.isNotEmpty() || type == PostType.VIDEO || type == PostType.IMAGE || type == PostType.GIF
}
