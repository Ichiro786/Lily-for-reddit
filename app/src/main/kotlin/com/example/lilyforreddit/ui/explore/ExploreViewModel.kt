package com.example.lilyforreddit.ui.explore

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.lilyforreddit.LilyApp
import com.example.lilyforreddit.data.models.Multireddit
import com.example.lilyforreddit.data.models.Subreddit
import com.example.lilyforreddit.data.repository.RedditRepository
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class ExploreUiState(
    val subscribedSubreddits: List<Subreddit> = emptyList(),
    val multireddits: List<Multireddit> = emptyList(),
    val trendingSubreddits: List<Subreddit> = emptyList(),
    val searchQuery: String = "",
    val searchResults: List<Subreddit> = emptyList(),
    val isSearching: Boolean = false,
    val isLoading: Boolean = false
)

class ExploreViewModel(
    private val redditRepository: RedditRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(ExploreUiState())
    val uiState: StateFlow<ExploreUiState> = _uiState.asStateFlow()

    init {
        loadExploreData()
    }

    fun loadExploreData() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            val subs = redditRepository.getSubscribedSubreddits()
            val multis = redditRepository.multireddits.value
            _uiState.update {
                it.copy(
                    subscribedSubreddits = subs,
                    multireddits = multis,
                    trendingSubreddits = subs,
                    isLoading = false
                )
            }
        }
    }

    fun onSearchQueryChange(query: String) {
        _uiState.update { it.copy(searchQuery = query) }
        if (query.isNotBlank()) {
            viewModelScope.launch {
                _uiState.update { it.copy(isSearching = true) }
                val results = redditRepository.searchSubreddits(query)
                _uiState.update { it.copy(searchResults = results, isSearching = false) }
            }
        } else {
            _uiState.update { it.copy(searchResults = emptyList(), isSearching = false) }
        }
    }

    fun toggleFavorite(subreddit: String) {
        redditRepository.toggleFavorite(subreddit)
        loadExploreData()
    }

    fun toggleSubscribe(subreddit: String) {
        redditRepository.toggleSubscribe(subreddit)
        loadExploreData()
    }

    companion object {
        val Factory: ViewModelProvider.Factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                val app = LilyApp.instance
                return ExploreViewModel(app.redditRepository) as T
            }
        }
    }
}
