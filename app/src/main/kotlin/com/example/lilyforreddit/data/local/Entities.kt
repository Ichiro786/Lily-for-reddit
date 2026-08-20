package com.example.lilyforreddit.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "saved_posts")
data class SavedPostEntity(
    @PrimaryKey val id: String,
    val fullname: String,
    val title: String,
    val subreddit: String,
    val author: String,
    val score: Int,
    val numComments: Int,
    val url: String,
    val previewUrl: String?,
    val isSelf: Boolean,
    val selftext: String,
    val createdUtc: Long,
    val savedAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "history_posts")
data class HistoryPostEntity(
    @PrimaryKey val id: String,
    val title: String,
    val subreddit: String,
    val author: String,
    val score: Int,
    val numComments: Int,
    val previewUrl: String?,
    val viewedAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "subreddit_affinity")
data class SubredditAffinityEntity(
    @PrimaryKey val subreddit: String,
    val score: Double = 1.0,
    val lastVisited: Long = System.currentTimeMillis()
)
