package com.example.lilyforreddit.ui.post

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.lilyforreddit.LilyApp
import com.example.lilyforreddit.data.models.Comment
import com.example.lilyforreddit.data.models.Post
import com.example.lilyforreddit.data.repository.RedditRepository
import com.example.lilyforreddit.data.repository.SettingsRepository
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class PostDetailUiState(
    val post: Post? = null,
    val comments: List<Comment> = emptyList(),
    val isLoading: Boolean = true,
    val isSaved: Boolean = false,
    val commentSort: String = "confidence",
    val replyingToComment: Comment? = null,
    val error: String? = null
)

class PostDetailViewModel(
    private val subreddit: String,
    private val postId: String,
    private val redditRepository: RedditRepository,
    private val settingsRepository: SettingsRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(PostDetailUiState())
    val uiState: StateFlow<PostDetailUiState> = _uiState.asStateFlow()

    val settings = settingsRepository.settings

    init {
        viewModelScope.launch {
            redditRepository.isPostSaved(postId).collect { saved ->
                _uiState.update { it.copy(isSaved = saved) }
            }
        }
        loadPostAndComments()
    }

    fun loadPostAndComments(sort: String = _uiState.value.commentSort) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null, commentSort = sort) }
            try {
                val (post, comments) = redditRepository.getComments(subreddit, postId, sort)
                _uiState.update {
                    it.copy(
                        post = post,
                        comments = comments,
                        isLoading = false
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = e.message ?: "Failed to load thread"
                    )
                }
            }
        }
    }

    fun votePost(dir: Int) {
        val currentPost = _uiState.value.post ?: return
        redditRepository.vote(currentPost.id, dir)
        val currentLike = currentPost.likes
        val (newLike, delta) = when (dir) {
            1 -> if (currentLike == true) Pair(null, -1) else Pair(true, if (currentLike == false) 2 else 1)
            -1 -> if (currentLike == false) Pair(null, 1) else Pair(false, if (currentLike == true) -2 else -1)
            else -> Pair(null, 0)
        }
        _uiState.update {
            it.copy(
                post = currentPost.copy(
                    likes = newLike,
                    score = (currentPost.score + delta).coerceAtLeast(0)
                )
            )
        }
    }

    fun toggleSavePost() {
        val post = _uiState.value.post ?: return
        viewModelScope.launch {
            redditRepository.toggleSavePost(post)
        }
    }

    fun setReplyingTo(comment: Comment?) {
        _uiState.update { it.copy(replyingToComment = comment) }
    }

    fun submitReply(text: String) {
        val currentPost = _uiState.value.post ?: return
        val targetFullname = _uiState.value.replyingToComment?.fullname ?: currentPost.fullname
        val newComment = redditRepository.submitCommentReply(currentPost.id, targetFullname, text)

        val targetComment = _uiState.value.replyingToComment
        if (targetComment != null) {
            // Append to target comment's replies
            val updated = appendReplyRecursive(_uiState.value.comments, targetComment.id, newComment)
            _uiState.update { it.copy(comments = updated, replyingToComment = null) }
        } else {
            // Add top-level comment
            _uiState.update {
                it.copy(
                    comments = listOf(newComment) + it.comments,
                    replyingToComment = null
                )
            }
        }
    }

    private fun appendReplyRecursive(list: List<Comment>, targetId: String, newReply: Comment): List<Comment> {
        return list.map { c ->
            if (c.id == targetId) {
                c.copy(replies = c.replies + newReply.copy(depth = c.depth + 1))
            } else {
                c.copy(replies = appendReplyRecursive(c.replies, targetId, newReply))
            }
        }
    }

    companion object {
        fun provideFactory(subreddit: String, postId: String): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    val app = LilyApp.instance
                    return PostDetailViewModel(
                        subreddit = subreddit,
                        postId = postId,
                        redditRepository = app.redditRepository,
                        settingsRepository = app.settingsRepository
                    ) as T
                }
            }
    }
}
