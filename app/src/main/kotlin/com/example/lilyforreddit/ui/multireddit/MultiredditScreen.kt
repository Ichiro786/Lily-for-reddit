package com.example.lilyforreddit.ui.multireddit

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.lilyforreddit.LilyApp
import com.example.lilyforreddit.data.models.Post
import com.example.lilyforreddit.data.models.PostDisplay
import com.example.lilyforreddit.data.models.PostSort
import com.example.lilyforreddit.ui.components.CompactPostCard
import com.example.lilyforreddit.ui.components.PostCard
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MultiredditScreen(
    username: String,
    multiredditName: String,
    onBack: () -> Unit,
    onPostClick: (String, String) -> Unit,
    onSubredditClick: (String) -> Unit,
    onUserClick: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val app = LilyApp.instance
    val settings by app.settingsRepository.settings.collectAsStateWithLifecycle()
    val savedPosts by app.redditRepository.getAllSavedPosts().collectAsStateWithLifecycle(initialValue = emptyList())
    val savedIds = remember(savedPosts) { savedPosts.map { it.id }.toSet() }

    var posts by remember { mutableStateOf<List<Post>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    val coroutineScope = rememberCoroutineScope()

    val multis by app.redditRepository.multireddits.collectAsStateWithLifecycle()
    val currentMulti = multis.find { it.name.equals(multiredditName, ignoreCase = true) }

    LaunchedEffect(multiredditName) {
        isLoading = true
        val subreddits = currentMulti?.subreddits ?: listOf("androiddev", "kotlin")
        val combinedSubreddit = subreddits.joinToString("+")
        val (resultPosts, _) = app.redditRepository.getPosts(
            subreddit = combinedSubreddit,
            sort = PostSort.HOT
        )
        posts = resultPosts
        isLoading = false
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(currentMulti?.displayName ?: multiredditName, fontWeight = FontWeight.Bold)
                        Text(
                            text = "${currentMulti?.subreddits?.size ?: 0} subreddits combined",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { paddingValues ->
        if (isLoading) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(posts, key = { it.id }) { post ->
                    if (settings.postDisplay == PostDisplay.CARD) {
                        PostCard(
                            post = post,
                            isSaved = savedIds.contains(post.id),
                            blurNsfw = settings.blurNsfw,
                            blurSpoiler = settings.blurSpoiler,
                            onPostClick = { onPostClick(post.subreddit, post.id) },
                            onSubredditClick = onSubredditClick,
                            onUserClick = onUserClick,
                            onVote = { dir ->
                                app.redditRepository.vote(post.id, dir)
                                posts = posts.map { if (it.id == post.id) it.copy(likes = if (dir == 1) true else if (dir == -1) false else null) else it }
                            },
                            onToggleSave = { coroutineScope.launch { app.redditRepository.toggleSavePost(post) } },
                            onHidePost = {
                                app.redditRepository.hidePost(post.id)
                                posts = posts.filterNot { it.id == post.id }
                            }
                        )
                    } else {
                        CompactPostCard(
                            post = post,
                            onPostClick = { onPostClick(post.subreddit, post.id) },
                            onSubredditClick = onSubredditClick,
                            onVote = { dir -> app.redditRepository.vote(post.id, dir) }
                        )
                    }
                }
            }
        }
    }
}
