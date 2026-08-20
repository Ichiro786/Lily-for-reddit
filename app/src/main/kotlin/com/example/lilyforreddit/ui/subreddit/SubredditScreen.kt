package com.example.lilyforreddit.ui.subreddit

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.example.lilyforreddit.data.models.PostDisplay
import com.example.lilyforreddit.data.models.PostSort
import com.example.lilyforreddit.ui.components.CompactPostCard
import com.example.lilyforreddit.ui.components.PostCard
import com.example.lilyforreddit.ui.components.formatScore

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SubredditScreen(
    subredditName: String,
    onBack: () -> Unit,
    onPostClick: (String, String) -> Unit,
    onUserClick: (String) -> Unit,
    onSubmitPostClick: (String) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: SubredditViewModel = viewModel(
        factory = SubredditViewModel.provideFactory(subredditName)
    )
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val settings by viewModel.settings.collectAsStateWithLifecycle()

    val sorts = listOf(PostSort.HOT, PostSort.NEWEST, PostSort.TOP, PostSort.RISING)

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "r/$subredditName",
                        fontWeight = FontWeight.Bold
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { onSubmitPostClick(subredditName) }) {
                        Icon(Icons.Outlined.Add, contentDescription = "Create Post in r/$subredditName")
                    }
                }
            )
        }
    ) { paddingValues ->
        val sub = uiState.subreddit

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues),
            contentPadding = PaddingValues(bottom = 24.dp)
        ) {
            // Banner & Header
            item {
                Column(modifier = Modifier.fillMaxWidth()) {
                    // Banner Image
                    if (!sub?.bannerImg.isNullOrBlank()) {
                        AsyncImage(
                            model = sub?.bannerImg,
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(120.dp)
                                .background(MaterialTheme.colorScheme.primaryContainer)
                        )
                    } else {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(90.dp)
                                .background(MaterialTheme.colorScheme.primaryContainer)
                        )
                    }

                    // Profile icon + info row
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(54.dp)
                                    .clip(CircleShape)
                                    .background(MaterialTheme.colorScheme.primary),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = subredditName.first().uppercase(),
                                    style = MaterialTheme.typography.headlineSmall,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onPrimary
                                )
                            }

                            Spacer(modifier = Modifier.width(14.dp))

                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = sub?.title ?: "r/$subredditName",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold
                                )
                                Text(
                                    text = "${formatScore(sub?.subscribers?.toInt() ?: 0)} subscribers • ${formatScore(sub?.activeAccounts?.toInt() ?: 0)} online",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }

                            // Favorite star
                            IconButton(onClick = { viewModel.toggleFavorite() }) {
                                Icon(
                                    imageVector = if (sub?.userHasFavorited == true) Icons.Filled.Star else Icons.Outlined.StarBorder,
                                    contentDescription = "Favorite",
                                    tint = if (sub?.userHasFavorited == true) Color(0xFFFFB000) else MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }

                            // Join Button
                            Button(
                                onClick = { viewModel.toggleSubscribe() },
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = if (sub?.userIsSubscriber == true) MaterialTheme.colorScheme.surfaceVariant else MaterialTheme.colorScheme.primary,
                                    contentColor = if (sub?.userIsSubscriber == true) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onPrimary
                                ),
                                shape = RoundedCornerShape(20.dp)
                            ) {
                                Text(
                                    text = if (sub?.userIsSubscriber == true) "Joined" else "Join",
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }

                        if (!sub?.publicDescription.isNullOrBlank()) {
                            Spacer(modifier = Modifier.height(10.dp))
                            Text(
                                text = sub?.publicDescription ?: "",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }

                        Spacer(modifier = Modifier.height(12.dp))

                        // Sort filter row
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .horizontalScroll(rememberScrollState()),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            sorts.forEach { sort ->
                                val isSelected = uiState.sort == sort
                                FilterChip(
                                    selected = isSelected,
                                    onClick = { viewModel.loadSubredditData(sort) },
                                    label = { Text(sort.label) },
                                    colors = FilterChipDefaults.filterChipColors(
                                        selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
                                        selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer
                                    )
                                )
                            }
                        }
                    }

                    HorizontalDivider(
                        color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f)
                    )
                }
            }

            // Posts list
            if (uiState.isLoading && uiState.posts.isEmpty()) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(48.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
                    }
                }
            } else {
                items(
                    items = uiState.posts,
                    key = { it.id }
                ) { post ->
                    Box(modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp)) {
                        if (settings.postDisplay == PostDisplay.CARD) {
                            PostCard(
                                post = post,
                                isSaved = uiState.savedPostIds.contains(post.id),
                                blurNsfw = settings.blurNsfw,
                                blurSpoiler = settings.blurSpoiler,
                                onPostClick = { onPostClick(post.subreddit, post.id) },
                                onSubredditClick = {},
                                onUserClick = onUserClick,
                                onVote = { dir -> viewModel.vote(post.id, dir) },
                                onToggleSave = { viewModel.toggleSave(post) },
                                onHidePost = { viewModel.hidePost(post.id) }
                            )
                        } else {
                            CompactPostCard(
                                post = post,
                                onPostClick = { onPostClick(post.subreddit, post.id) },
                                onSubredditClick = {},
                                onVote = { dir -> viewModel.vote(post.id, dir) }
                            )
                        }
                    }
                }
            }
        }
    }
}
