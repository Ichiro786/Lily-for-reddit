package com.example.lilyforreddit.ui.search

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.lilyforreddit.LilyApp
import com.example.lilyforreddit.data.models.Post
import com.example.lilyforreddit.data.models.Subreddit
import com.example.lilyforreddit.ui.components.PostCard
import com.example.lilyforreddit.ui.explore.SubredditListItem
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SearchScreen(
    initialQuery: String,
    initialSubreddit: String?,
    onBack: () -> Unit,
    onPostClick: (String, String) -> Unit,
    onSubredditClick: (String) -> Unit,
    onUserClick: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    var query by remember { mutableStateOf(initialQuery) }
    var selectedTab by remember { mutableIntStateOf(0) }
    var postResults by remember { mutableStateOf<List<Post>>(emptyList()) }
    var subResults by remember { mutableStateOf<List<Subreddit>>(emptyList()) }
    var isSearching by remember { mutableStateOf(false) }

    val app = LilyApp.instance
    val coroutineScope = rememberCoroutineScope()

    fun performSearch(q: String) {
        if (q.isBlank()) return
        coroutineScope.launch {
            isSearching = true
            try {
                postResults = app.redditRepository.searchPosts(q, initialSubreddit)
                subResults = app.redditRepository.searchSubreddits(q)
            } finally {
                isSearching = false
            }
        }
    }

    LaunchedEffect(Unit) {
        if (initialQuery.isNotBlank()) {
            performSearch(initialQuery)
        }
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.background)
                    .statusBarsPadding()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 8.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }

                    OutlinedTextField(
                        value = query,
                        onValueChange = {
                            query = it
                            if (it.length >= 2) performSearch(it)
                        },
                        placeholder = {
                            Text(
                                if (initialSubreddit != null) "Search in r/$initialSubreddit..."
                                else "Search posts, subreddits..."
                            )
                        },
                        trailingIcon = {
                            if (query.isNotEmpty()) {
                                IconButton(onClick = { query = "" }) {
                                    Icon(Icons.Filled.Close, contentDescription = "Clear")
                                }
                            }
                        },
                        singleLine = true,
                        shape = RoundedCornerShape(24.dp),
                        modifier = Modifier
                            .weight(1f)
                            .padding(end = 8.dp)
                            .testTag("search_screen_input")
                    )
                }

                TabRow(selectedTabIndex = selectedTab) {
                    Tab(
                        selected = selectedTab == 0,
                        onClick = { selectedTab = 0 },
                        text = { Text("Posts (${postResults.size})") }
                    )
                    Tab(
                        selected = selectedTab == 1,
                        onClick = { selectedTab = 1 },
                        text = { Text("Communities (${subResults.size})") }
                    )
                }
            }
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            if (isSearching) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            } else if (selectedTab == 0) {
                if (postResults.isEmpty()) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text(
                            text = if (query.isBlank()) "Type something to search Reddit" else "No posts found",
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        items(postResults) { post ->
                            PostCard(
                                post = post,
                                isSaved = false,
                                onPostClick = { onPostClick(post.subreddit, post.id) },
                                onSubredditClick = onSubredditClick,
                                onUserClick = onUserClick,
                                onVote = { dir -> app.redditRepository.vote(post.id, dir) },
                                onToggleSave = { coroutineScope.launch { app.redditRepository.toggleSavePost(post) } },
                                onHidePost = {
                                    app.redditRepository.hidePost(post.id)
                                    postResults = postResults.filterNot { it.id == post.id }
                                }
                            )
                        }
                    }
                }
            } else {
                if (subResults.isEmpty()) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text(
                            text = if (query.isBlank()) "Type something to find communities" else "No communities found",
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(vertical = 8.dp)
                    ) {
                        items(subResults) { sub ->
                            SubredditListItem(
                                subreddit = sub,
                                onClick = { onSubredditClick(sub.name) },
                                onToggleFavorite = { app.redditRepository.toggleFavorite(sub.name) },
                                onToggleSubscribe = { app.redditRepository.toggleSubscribe(sub.name) }
                            )
                        }
                    }
                }
            }
        }
    }
}
