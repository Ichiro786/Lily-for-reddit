package com.example.lilyforreddit.ui.navigation

import kotlinx.serialization.Serializable

sealed interface Screen {
    @Serializable
    data object Home : Screen

    @Serializable
    data class PostDetail(val subreddit: String, val postId: String) : Screen

    @Serializable
    data class SubredditDetail(val name: String) : Screen

    @Serializable
    data class UserProfile(val username: String) : Screen

    @Serializable
    data class Search(val initialQuery: String = "", val initialSubreddit: String? = null) : Screen

    @Serializable
    data class SubmitPost(val initialSubreddit: String? = null) : Screen

    @Serializable
    data object History : Screen

    @Serializable
    data object ManageForYou : Screen

    @Serializable
    data class MultiredditFeed(val username: String, val name: String) : Screen

    @Serializable
    data object Settings : Screen
}
