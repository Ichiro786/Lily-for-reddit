package com.example.lilyforreddit.ui.inbox

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.lilyforreddit.LilyApp
import com.example.lilyforreddit.data.models.InboxItem
import com.example.lilyforreddit.data.repository.RedditRepository
import kotlinx.coroutines.flow.*

data class InboxUiState(
    val items: List<InboxItem> = emptyList(),
    val unreadCount: Int = 0
)

class InboxViewModel(
    private val redditRepository: RedditRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(InboxUiState())
    val uiState: StateFlow<InboxUiState> = _uiState.asStateFlow()

    init {
        redditRepository.inboxItems.onEach { items ->
            _uiState.update {
                it.copy(
                    items = items,
                    unreadCount = items.count { item -> item.isNew }
                )
            }
        }.launchIn(viewModelScope)
    }

    fun markRead(id: String) {
        redditRepository.markInboxItemRead(id)
    }

    fun markAllRead() {
        redditRepository.markAllInboxRead()
    }

    companion object {
        val Factory: ViewModelProvider.Factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                val app = LilyApp.instance
                return InboxViewModel(app.redditRepository) as T
            }
        }
    }
}
