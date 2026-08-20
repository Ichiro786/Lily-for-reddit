package com.example.lilyforreddit.ui.post

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.lilyforreddit.data.models.Comment
import com.example.lilyforreddit.data.models.Post
import com.example.lilyforreddit.ui.components.CommentItem
import com.example.lilyforreddit.ui.components.MediaViewer
import com.example.lilyforreddit.ui.components.formatScore
import com.example.lilyforreddit.ui.components.formatTimeAgo
import com.example.lilyforreddit.ui.theme.DownvoteBlue
import com.example.lilyforreddit.ui.theme.UpvoteOrange

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PostDetailScreen(
    subreddit: String,
    postId: String,
    onBack: () -> Unit,
    onSubredditClick: (String) -> Unit,
    onUserClick: (String) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: PostDetailViewModel = viewModel(
        factory = PostDetailViewModel.provideFactory(subreddit, postId)
    )
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val settings by viewModel.settings.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val clipboardManager = LocalClipboardManager.current

    var replyText by remember { mutableStateOf("") }
    var showSortMenu by remember { mutableStateOf(false) }

    val sortOptions = listOf(
        "confidence" to "Best",
        "top" to "Top",
        "new" to "New",
        "controversial" to "Controversial",
        "old" to "Old"
    )

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = "r/${uiState.post?.subreddit ?: subreddit}",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "${uiState.post?.numComments ?: 0} comments",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back"
                        )
                    }
                },
                actions = {
                    // Sort dropdown
                    Box {
                        IconButton(onClick = { showSortMenu = true }) {
                            Icon(
                                imageVector = Icons.Outlined.Sort,
                                contentDescription = "Sort comments"
                            )
                        }
                        DropdownMenu(
                            expanded = showSortMenu,
                            onDismissRequest = { showSortMenu = false }
                        ) {
                            sortOptions.forEach { (key, label) ->
                                DropdownMenuItem(
                                    text = {
                                        Text(
                                            text = label,
                                            fontWeight = if (uiState.commentSort == key) FontWeight.Bold else FontWeight.Normal
                                        )
                                    },
                                    onClick = {
                                        showSortMenu = false
                                        viewModel.loadPostAndComments(key)
                                    }
                                )
                            }
                        }
                    }

                    // Share button
                    IconButton(onClick = {
                        val post = uiState.post
                        if (post != null) {
                            val shareUrl = if (post.permalink.isNotBlank()) "https://reddit.com${post.permalink}" else post.url
                            val sendIntent = Intent().apply {
                                action = Intent.ACTION_SEND
                                putExtra(Intent.EXTRA_TEXT, "${post.title}\n$shareUrl")
                                type = "text/plain"
                            }
                            context.startActivity(Intent.createChooser(sendIntent, "Share post"))
                        }
                    }) {
                        Icon(Icons.Outlined.Share, contentDescription = "Share")
                    }
                }
            )
        },
        bottomBar = {
            // Reply Bar
            Surface(
                tonalElevation = 6.dp,
                shadowElevation = 8.dp,
                modifier = Modifier
                    .fillMaxWidth()
                    .imePadding()
                    .navigationBarsPadding()
            ) {
                Column(modifier = Modifier.fillMaxWidth()) {
                    if (uiState.replyingToComment != null) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.5f))
                                .padding(horizontal = 16.dp, vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(
                                text = "Replying to u/${uiState.replyingToComment?.author}",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSecondaryContainer
                            )
                            IconButton(
                                onClick = { viewModel.setReplyingTo(null) },
                                modifier = Modifier.size(20.dp)
                            ) {
                                Icon(Icons.Filled.Close, contentDescription = "Cancel reply", modifier = Modifier.size(14.dp))
                            }
                        }
                    }

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        TextField(
                            value = replyText,
                            onValueChange = { replyText = it },
                            placeholder = {
                                Text(
                                    if (uiState.replyingToComment != null) "Add a reply..." else "Add a comment..."
                                )
                            },
                            modifier = Modifier
                                .weight(1f)
                                .testTag("reply_input_field"),
                            shape = RoundedCornerShape(24.dp),
                            colors = TextFieldDefaults.colors(
                                focusedIndicatorColor = Color.Transparent,
                                unfocusedIndicatorColor = Color.Transparent
                            ),
                            maxLines = 4
                        )

                        Spacer(modifier = Modifier.width(8.dp))

                        IconButton(
                            onClick = {
                                if (replyText.isNotBlank()) {
                                    viewModel.submitReply(replyText)
                                    replyText = ""
                                }
                            },
                            enabled = replyText.isNotBlank(),
                            modifier = Modifier
                                .clip(CircleShape)
                                .background(
                                    if (replyText.isNotBlank()) MaterialTheme.colorScheme.primary
                                    else MaterialTheme.colorScheme.surfaceVariant
                                )
                        ) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.Send,
                                contentDescription = "Send",
                                tint = if (replyText.isNotBlank()) MaterialTheme.colorScheme.onPrimary
                                else MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }
    ) { paddingValues ->
        val post = uiState.post

        if (uiState.isLoading && post == null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
            }
        } else if (post != null) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
                contentPadding = PaddingValues(bottom = 16.dp)
            ) {
                // Post Header & Content Item
                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp)
                    ) {
                        // Subreddit & Author row
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(40.dp)
                                    .clip(CircleShape)
                                    .background(MaterialTheme.colorScheme.primaryContainer)
                                    .clickable { onSubredditClick(post.subreddit) },
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = if (post.subreddit.isNotEmpty()) post.subreddit.first().uppercase() else "R",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onPrimaryContainer
                                )
                            }
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text(
                                    text = post.subredditPrefixed,
                                    style = MaterialTheme.typography.titleSmall,
                                    fontWeight = FontWeight.Bold,
                                    modifier = Modifier.clickable { onSubredditClick(post.subreddit) }
                                )
                                Text(
                                    text = "Posted by u/${post.author} • ${formatTimeAgo(post.createdUtc)}",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.clickable { onUserClick(post.author) }
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(12.dp))

                        // Flair
                        if (!post.linkFlairText.isNullOrBlank()) {
                            Surface(
                                shape = RoundedCornerShape(6.dp),
                                color = MaterialTheme.colorScheme.secondaryContainer,
                                modifier = Modifier.padding(bottom = 8.dp)
                            ) {
                                Text(
                                    text = post.linkFlairText,
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSecondaryContainer,
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                                )
                            }
                        }

                        // Title
                        Text(
                            text = post.title,
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )

                        // Selftext
                        if (post.selftext.isNotBlank()) {
                            Spacer(modifier = Modifier.height(12.dp))
                            Text(
                                text = post.selftext,
                                style = MaterialTheme.typography.bodyLarge,
                                color = MaterialTheme.colorScheme.onSurface,
                                lineHeight = 24.sp
                            )
                        }

                        // Media
                        if (post.hasMedia) {
                            Spacer(modifier = Modifier.height(16.dp))
                            MediaViewer(
                                post = post,
                                blurNsfw = settings.blurNsfw,
                                blurSpoiler = settings.blurSpoiler
                            )
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        // Post Actions (Vote + Save)
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Surface(
                                shape = RoundedCornerShape(20.dp),
                                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                ) {
                                    IconButton(
                                        onClick = { viewModel.votePost(1) },
                                        modifier = Modifier.size(36.dp)
                                    ) {
                                        Icon(
                                            imageVector = if (post.likes == true) Icons.Filled.ArrowUpward else Icons.Outlined.ArrowUpward,
                                            contentDescription = "Upvote",
                                            tint = if (post.likes == true) UpvoteOrange else MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }

                                    Text(
                                        text = formatScore(post.score),
                                        style = MaterialTheme.typography.labelLarge,
                                        fontWeight = FontWeight.Bold,
                                        color = when (post.likes) {
                                            true -> UpvoteOrange
                                            false -> DownvoteBlue
                                            else -> MaterialTheme.colorScheme.onSurface
                                        },
                                        modifier = Modifier.padding(horizontal = 6.dp)
                                    )

                                    IconButton(
                                        onClick = { viewModel.votePost(-1) },
                                        modifier = Modifier.size(36.dp)
                                    ) {
                                        Icon(
                                            imageVector = if (post.likes == false) Icons.Filled.ArrowDownward else Icons.Outlined.ArrowDownward,
                                            contentDescription = "Downvote",
                                            tint = if (post.likes == false) DownvoteBlue else MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                }
                            }

                            Row(verticalAlignment = Alignment.CenterVertically) {
                                IconButton(onClick = { viewModel.toggleSavePost() }) {
                                    Icon(
                                        imageVector = if (uiState.isSaved) Icons.Filled.Bookmark else Icons.Outlined.BookmarkBorder,
                                        contentDescription = "Save",
                                        tint = if (uiState.isSaved) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }
                    }

                    HorizontalDivider(
                        color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f),
                        thickness = 1.dp
                    )

                    // Comments Section Title
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = "Comments (${uiState.comments.size})",
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = "Sorted by: ${sortOptions.find { it.first == uiState.commentSort }?.second ?: "Best"}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }

                // Comments List
                if (uiState.comments.isEmpty()) {
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(32.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "No comments yet. Be the first to start the discussion!",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                } else {
                    items(
                        items = uiState.comments,
                        key = { it.id }
                    ) { comment ->
                        Box(modifier = Modifier.padding(horizontal = 12.dp)) {
                            CommentItem(
                                comment = comment,
                                opAuthor = post.author,
                                onReplyClick = { target -> viewModel.setReplyingTo(target) },
                                onUserClick = onUserClick
                            )
                        }
                    }
                }
            }
        }
    }
}
