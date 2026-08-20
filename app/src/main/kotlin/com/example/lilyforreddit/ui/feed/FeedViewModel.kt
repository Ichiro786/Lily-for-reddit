package com.example.lilyforreddit.ui.feed

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.lilyforreddit.LilyApp
import com.example.lilyforreddit.data.models.*
import com.example.lilyforreddit.data.repository.RedditRepository
import com.example.lilyforreddit.data.repository.SettingsRepository
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

sealed interface FeedTab {
    data object ForYou : FeedTab
    data class Standard(val sort: PostSort) : FeedTab
}

data class FeedUiState(
    val posts: List<Post> = emptyList(),
    val isLoading: Boolean = false,
    val isRefreshing: Boolean = false,
    val selectedTab: FeedTab = FeedTab.ForYou,
    val topTime: TopTime = TopTime.DAY,
    val savedPostIds: Set<String> = emptySet(),
    val error: String? = null
)

class FeedViewModel(
    private val redditRepository: RedditRepository,
    private val settingsRepository: SettingsRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(FeedUiState())
    val uiState: StateFlow<FeedUiState> = _uiState.asStateFlow()

    val settings = settingsRepository.settings

    init {
        viewModelScope.launch {
            redditRepository.getAllSavedPosts().collect { savedList ->
                _uiState.update { it.copy(savedPostIds = savedList.map { s -> s.id }.toSet()) }
            }
        }
        loadFeed(FeedTab.ForYou)
    }

    fun selectTab(tab: FeedTab) {
        _uiState.update { it.copy(selectedTab = tab) }
        loadFeed(tab)
    }

    fun selectTopTime(time: TopTime) {
        _uiState.update { it.copy(topTime = time) }
        loadFeed(_uiState.value.selectedTab)
    }

    fun refresh() {
        _uiState.update { it.copy(isRefreshing = true) }
        loadFeed(_uiState.value.selectedTab, isRefresh = true)
    }

    private fun loadFeed(tab: FeedTab, isRefresh: Boolean = false) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = !isRefresh, error = null) }
            try {
                val posts = when (tab) {
                    is FeedTab.ForYou -> redditRepository.getForYouFeed()
                    is FeedTab.Standard -> {
                        val (p, _) = redditRepository.getPosts(
                            subreddit = null,
                            sort = tab.sort,
                            time = _uiState.value.topTime
                        )
                        p
                    }
                }
                _uiState.update {
                    it.copy(
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
                        error = e.message ?: "Failed to load posts"
                    )
                }
            }
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

    fun toggleDisplayMode() {
        val current = settings.value.postDisplay
        val newMode = if (current == PostDisplay.CARD) PostDisplay.COMPACT else PostDisplay.CARD
        settingsRepository.setPostDisplay(newMode)
    }

    companion object {
        val Factory: ViewModelProvider.Factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                val app = LilyApp.instance
                return FeedViewModel(app.redditRepository, app.settingsRepository) as T
            }
        }
    }
}
