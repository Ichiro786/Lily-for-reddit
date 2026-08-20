package com.example.lilyforreddit.ui.subreddit

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.lilyforreddit.LilyApp
import com.example.lilyforreddit.data.models.Post
import com.example.lilyforreddit.data.models.PostSort
import com.example.lilyforreddit.data.models.Subreddit
import com.example.lilyforreddit.data.models.TopTime
import com.example.lilyforreddit.data.repository.RedditRepository
import com.example.lilyforreddit.data.repository.SettingsRepository
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class SubredditUiState(
    val subreddit: Subreddit? = null,
    val posts: List<Post> = emptyList(),
    val sort: PostSort = PostSort.HOT,
    val topTime: TopTime = TopTime.DAY,
    val savedPostIds: Set<String> = emptySet(),
    val isLoading: Boolean = true,
    val isRefreshing: Boolean = false,
    val error: String? = null
)

class SubredditViewModel(
    val subredditName: String,
    private val redditRepository: RedditRepository,
    private val settingsRepository: SettingsRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(SubredditUiState())
    val uiState: StateFlow<SubredditUiState> = _uiState.asStateFlow()

    val settings = settingsRepository.settings

    init {
        viewModelScope.launch {
            redditRepository.getAllSavedPosts().collect { savedList ->
                _uiState.update { it.copy(savedPostIds = savedList.map { s -> s.id }.toSet()) }
            }
        }
        loadSubredditData()
    }

    fun loadSubredditData(sort: PostSort = _uiState.value.sort, isRefresh: Boolean = false) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = !isRefresh, sort = sort, error = null) }
            try {
                val sub = redditRepository.getSubredditAbout(subredditName)
                val (posts, _) = redditRepository.getPosts(
                    subreddit = subredditName,
                    sort = sort,
                    time = _uiState.value.topTime
                )
                _uiState.update {
                    it.copy(
                        subreddit = sub,
                        posts = posts,
                        isLoading = false,
                        isRefreshing = false
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        isRefreshing = false,
                        error = e.message ?: "Failed to load r/$subredditName"
                    )
                }
            }
        }
    }

    fun toggleSubscribe() {
        redditRepository.toggleSubscribe(subredditName)
        val current = _uiState.value.subreddit ?: return
        _uiState.update {
            it.copy(subreddit = current.copy(userIsSubscriber = !current.userIsSubscriber))
        }
    }

    fun toggleFavorite() {
        redditRepository.toggleFavorite(subredditName)
        val current = _uiState.value.subreddit ?: return
        _uiState.update {
            it.copy(subreddit = current.copy(userHasFavorited = !current.userHasFavorited))
        }
    }

    fun vote(postId: String, dir: Int) {
        redditRepository.vote(postId, dir)
        _uiState.update { state ->
            state.copy(
                posts = state.posts.map { post ->
                    if (post.id == postId) {
                        val currentLike = post.likes
                        val (newLike, delta) = when (dir) {
                            1 -> if (currentLike == true) Pair(null, -1) else Pair(true, if (currentLike == false) 2 else 1)
                            -1 -> if (currentLike == false) Pair(null, 1) else Pair(false, if (currentLike == true) -2 else -1)
                            else -> Pair(null, 0)
                        }
                        post.copy(
                            likes = newLike,
                            score = (post.score + delta).coerceAtLeast(0)
                        )
                    } else post
                }
            )
        }
    }

    fun toggleSave(post: Post) {
        viewModelScope.launch {
            redditRepository.toggleSavePost(post)
        }
    }

    fun hidePost(postId: String) {
        redditRepository.hidePost(postId)
        _uiState.update { state ->
            state.copy(posts = state.posts.filterNot { it.id == postId })
        }
    }

    companion object {
        fun provideFactory(subredditName: String): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    val app = LilyApp.instance
                    return SubredditViewModel(
                        subredditName = subredditName,
                        redditRepository = app.redditRepository,
                        settingsRepository = app.settingsRepository
                    ) as T
                }
            }
    }
}
