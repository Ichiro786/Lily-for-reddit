package com.example.lilyforreddit.ui.feed

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.lilyforreddit.data.models.PostDisplay
import com.example.lilyforreddit.data.models.PostSort
import com.example.lilyforreddit.data.models.TopTime
import com.example.lilyforreddit.ui.components.CompactPostCard
import com.example.lilyforreddit.ui.components.GlassSurface
import com.example.lilyforreddit.ui.components.PostCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FeedScreen(
    onPostClick: (String, String) -> Unit,
    onSubredditClick: (String) -> Unit,
    onUserClick: (String) -> Unit,
    onSearchClick: () -> Unit,
    onSubmitPostClick: () -> Unit,
    onManageForYouClick: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: FeedViewModel = viewModel(factory = FeedViewModel.Factory)
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val settings by viewModel.settings.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()

    val tabs = listOf(
        FeedTab.ForYou,
        FeedTab.Standard(PostSort.BEST),
        FeedTab.Standard(PostSort.HOT),
        FeedTab.Standard(PostSort.NEWEST),
        FeedTab.Standard(PostSort.TOP),
        FeedTab.Standard(PostSort.RISING)
    )

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.background)
                    .statusBarsPadding()
            ) {
                // Top Action Row
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // App title & brand
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.weight(1f)
                    ) {
                        Surface(
                            shape = CircleShape,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(32.dp)
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Text(
                                    text = "🌸",
                                    fontSize = 16.sp
                                )
                            }
                        }
                        Spacer(modifier = Modifier.width(10.dp))
                        Text(
                            text = "Lily",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onBackground
                        )
                        Text(
                            text = " for Reddit",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Normal,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    // Search button
                    IconButton(
                        onClick = onSearchClick,
                        modifier = Modifier.testTag("feed_search_button")
                    ) {
                        Icon(
                            imageVector = Icons.Outlined.Search,
                            contentDescription = "Search Reddit",
                            tint = MaterialTheme.colorScheme.onSurface
                        )
                    }

                    // Compose submit button
                    IconButton(
                        onClick = onSubmitPostClick,
                        modifier = Modifier.testTag("feed_compose_button")
                    ) {
                        Icon(
                            imageVector = Icons.Outlined.Add,
                            contentDescription = "Create Post",
                            tint = MaterialTheme.colorScheme.primary
                        )
                    }

                    // Layout Mode toggle
                    IconButton(
                        onClick = { viewModel.toggleDisplayMode() },
                        modifier = Modifier.testTag("feed_layout_toggle")
                    ) {
                        Icon(
                            imageVector = if (settings.postDisplay == PostDisplay.CARD) Icons.Outlined.ViewAgenda else Icons.Outlined.ViewHeadline,
                            contentDescription = "Toggle display mode",
                            tint = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }

                // Scrollable feed tabs
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState())
                        .padding(horizontal = 16.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    tabs.forEach { tab ->
                        val isSelected = uiState.selectedTab == tab
                        val title = when (tab) {
                            is FeedTab.ForYou -> "✨ For You"
                            is FeedTab.Standard -> tab.sort.label
                        }

                        FilterChip(
                            selected = isSelected,
                            onClick = { viewModel.selectTab(tab) },
                            label = {
                                Text(
                                    text = title,
                                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium
                                )
                            },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
                                selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer
                            ),
                            border = FilterChipDefaults.filterChipBorder(
                                enabled = true,
                                selected = isSelected,
                                borderColor = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant
                            )
                        )
                    }

                    if (uiState.selectedTab is FeedTab.ForYou) {
                        IconButton(
                            onClick = onManageForYouClick,
                            modifier = Modifier.size(32.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Outlined.Tune,
                                contentDescription = "Manage For You Preferences",
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                }

                // Top time filter chips when TOP tab is selected
                AnimatedVisibility(
                    visible = (uiState.selectedTab as? FeedTab.Standard)?.sort == PostSort.TOP
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState())
                            .padding(horizontal = 16.dp, vertical = 4.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        TopTime.entries.forEach { time ->
                            val isSelected = uiState.topTime == time
                            SuggestionChip(
                                onClick = { viewModel.selectTopTime(time) },
                                label = { Text(time.label, fontSize = 12.sp) },
                                colors = SuggestionChipDefaults.suggestionChipColors(
                                    containerColor = if (isSelected) MaterialTheme.colorScheme.secondaryContainer else Color.Transparent
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
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            when {
                uiState.isLoading && uiState.posts.isEmpty() -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }

                uiState.posts.isEmpty() && uiState.error != null -> {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(32.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        Icon(
                            imageVector = Icons.Outlined.CloudOff,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.error,
                            modifier = Modifier.size(48.dp)
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = "Couldn't reach Reddit",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = uiState.error ?: "",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(onClick = { viewModel.refresh() }) {
                            Text("Retry")
                        }
                    }
                }

                else -> {
                    LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(
                            start = 16.dp,
                            end = 16.dp,
                            top = 12.dp,
                            bottom = 90.dp // Padding for floating pill navigation
                        ),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        items(
                            items = uiState.posts,
                            key = { it.id }
                        ) { post ->
                            if (settings.postDisplay == PostDisplay.CARD) {
                                PostCard(
                                    post = post,
                                    isSaved = uiState.savedPostIds.contains(post.id),
                                    blurNsfw = settings.blurNsfw,
                                    blurSpoiler = settings.blurSpoiler,
                                    onPostClick = { onPostClick(post.subreddit, post.id) },
                                    onSubredditClick = onSubredditClick,
                                    onUserClick = onUserClick,
                                    onVote = { dir -> viewModel.vote(post.id, dir) },
                                    onToggleSave = { viewModel.toggleSave(post) },
                                    onHidePost = { viewModel.hidePost(post.id) }
                                )
                            } else {
                                CompactPostCard(
                                    post = post,
                                    onPostClick = { onPostClick(post.subreddit, post.id) },
                                    onSubredditClick = onSubredditClick,
                                    onVote = { dir -> viewModel.vote(post.id, dir) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
