package com.example.lilyforreddit.ui.user

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.lilyforreddit.LilyApp
import com.example.lilyforreddit.data.local.HistoryPostEntity
import com.example.lilyforreddit.data.local.SavedPostEntity
import com.example.lilyforreddit.data.models.Post
import com.example.lilyforreddit.data.models.RedditUser
import com.example.lilyforreddit.data.repository.RedditRepository
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class UserUiState(
    val user: RedditUser? = null,
    val userPosts: List<Post> = emptyList(),
    val savedPosts: List<SavedPostEntity> = emptyList(),
    val historyPosts: List<HistoryPostEntity> = emptyList(),
    val selectedTabIndex: Int = 0,
    val isLoading: Boolean = true
)

class UserViewModel(
    val username: String,
    private val redditRepository: RedditRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(UserUiState())
    val uiState: StateFlow<UserUiState> = _uiState.asStateFlow()

    init {
        loadUserData()
        observeSavedAndHistory()
    }

    private fun observeSavedAndHistory() {
        viewModelScope.launch {
            redditRepository.getAllSavedPosts().collect { saved ->
                _uiState.update { it.copy(savedPosts = saved) }
            }
        }
        viewModelScope.launch {
            redditRepository.getHistory().collect { hist ->
                _uiState.update { it.copy(historyPosts = hist) }
            }
        }
    }

    fun loadUserData() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            val user = redditRepository.getUserAbout(username)
            val (posts, _) = redditRepository.getPosts(limit = 10)
            _uiState.update {
                it.copy(
                    user = user,
                    userPosts = posts.filter { p -> p.author.equals(username, ignoreCase = true) }.ifEmpty { posts.take(3) },
                    isLoading = false
                )
            }
        }
    }

    fun selectTab(index: Int) {
        _uiState.update { it.copy(selectedTabIndex = index) }
    }

    fun clearHistory() {
        viewModelScope.launch {
            redditRepository.clearHistory()
        }
    }

    companion object {
        fun provideFactory(username: String): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    val app = LilyApp.instance
                    return UserViewModel(
                        username = username,
                        redditRepository = app.redditRepository
                    ) as T
                }
            }
    }
}
