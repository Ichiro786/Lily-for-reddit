package com.example.lilyforreddit.data.models

import kotlinx.serialization.Serializable

@Serializable
data class Comment(
    val id: String,
    val fullname: String,
    val author: String,
    val body: String,
    val score: Int = 0,
    val createdUtc: Long = System.currentTimeMillis() / 1000,
    val depth: Int = 0,
    val replies: List<Comment> = emptyList(),
    val isOp: Boolean = false,
    val distinguished: String? = null,
    val likes: Boolean? = null,
    val saved: Boolean = false,
    val isCollapsed: Boolean = false,
    val parentId: String = ""
)
