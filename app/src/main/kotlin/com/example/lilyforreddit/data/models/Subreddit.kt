package com.example.lilyforreddit.data.models

import kotlinx.serialization.Serializable

@Serializable
data class Subreddit(
    val name: String,
    val displayName: String = name,
    val title: String = name,
    val publicDescription: String = "",
    val subscribers: Long = 0,
    val activeAccounts: Long = 0,
    val iconImg: String? = null,
    val bannerImg: String? = null,
    val primaryColor: String? = null,
    val userHasFavorited: Boolean = false,
    val userIsSubscriber: Boolean = false,
    val over18: Boolean = false
)

@Serializable
data class RedditUser(
    val name: String,
    val totalKarma: Int = 0,
    val linkKarma: Int = 0,
    val commentKarma: Int = 0,
    val iconImg: String? = null,
    val bannerImg: String? = null,
    val createdUtc: Long = System.currentTimeMillis() / 1000,
    val bio: String = "",
    val isFriend: Boolean = false,
    val isBlocked: Boolean = false
)

@Serializable
data class InboxItem(
    val id: String,
    val fullname: String,
    val subject: String,
    val body: String,
    val author: String,
    val dest: String = "",
    val wasComment: Boolean = false,
    val parentId: String? = null,
    val context: String? = null,
    val createdUtc: Long = System.currentTimeMillis() / 1000,
    val isNew: Boolean = true,
    val subreddit: String? = null
)

@Serializable
data class Multireddit(
    val name: String,
    val displayName: String = name,
    val description: String = "",
    val subreddits: List<String> = emptyList(),
    val iconUrl: String? = null,
    val path: String = "/user/me/m/$name",
    val visibility: String = "private"
)

@Serializable
data class Flair(
    val id: String,
    val text: String,
    val backgroundColor: String? = null,
    val textColor: String? = null
)
