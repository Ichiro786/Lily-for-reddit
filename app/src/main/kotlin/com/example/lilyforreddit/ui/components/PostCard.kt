package com.example.lilyforreddit.ui.components

import android.content.Intent
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
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
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.example.lilyforreddit.data.models.Post
import com.example.lilyforreddit.ui.theme.DownvoteBlue
import com.example.lilyforreddit.ui.theme.UpvoteOrange

@Composable
fun PostCard(
    post: Post,
    modifier: Modifier = Modifier,
    isSaved: Boolean = false,
    blurNsfw: Boolean = true,
    blurSpoiler: Boolean = true,
    onPostClick: () -> Unit,
    onSubredditClick: (String) -> Unit,
    onUserClick: (String) -> Unit,
    onVote: (Int) -> Unit,
    onToggleSave: () -> Unit,
    onHidePost: () -> Unit
) {
    val context = LocalContext.current
    val clipboardManager = LocalClipboardManager.current
    var showMenu by remember { mutableStateOf(false) }

    Card(
        modifier = modifier
            .fillMaxWidth()
            .testTag("post_card_${post.id}")
            .clickable { onPostClick() },
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            // Feed reason if present
            if (!post.feedReason.isNullOrBlank()) {
                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f),
                    modifier = Modifier.padding(bottom = 10.dp)
                ) {
                    Text(
                        text = post.feedReason,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                        fontWeight = FontWeight.Medium,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }

            // Header: Subreddit Avatar + Names + Timestamp + Overflow Menu
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Subreddit avatar
                Box(
                    modifier = Modifier
                        .size(36.dp)
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

                Spacer(modifier = Modifier.width(10.dp))

                Column(modifier = Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = post.subredditPrefixed,
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.clickable { onSubredditClick(post.subreddit) }
                        )
                        if (post.stickied) {
                            Spacer(modifier = Modifier.width(6.dp))
                            Icon(
                                imageVector = Icons.Filled.PushPin,
                                contentDescription = "Pinned",
                                tint = Color(0xFF4CAF50),
                                modifier = Modifier.size(14.dp)
                            )
                        }
                        if (post.locked) {
                            Spacer(modifier = Modifier.width(4.dp))
                            Icon(
                                imageVector = Icons.Filled.Lock,
                                contentDescription = "Locked",
                                tint = MaterialTheme.colorScheme.error,
                                modifier = Modifier.size(14.dp)
                            )
                        }
                    }

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = "u/${post.author}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.clickable { onUserClick(post.author) }
                        )
                        Text(
                            text = " • ${formatTimeAgo(post.createdUtc)}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                // 3-dot overflow menu
                Box {
                    IconButton(
                        onClick = { showMenu = true },
                        modifier = Modifier.size(32.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Filled.MoreVert,
                            contentDescription = "Post options",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    DropdownMenu(
                        expanded = showMenu,
                        onDismissRequest = { showMenu = false }
                    ) {
                        DropdownMenuItem(
                            text = { Text("Copy link") },
                            leadingIcon = { Icon(Icons.Outlined.ContentCopy, null) },
                            onClick = {
                                showMenu = false
                                val shareUrl = if (post.permalink.isNotBlank()) "https://reddit.com${post.permalink}" else post.url
                                clipboardManager.setText(AnnotatedString(shareUrl))
                            }
                        )
                        DropdownMenuItem(
                            text = { Text("Visit r/${post.subreddit}") },
                            leadingIcon = { Icon(Icons.Outlined.Forum, null) },
                            onClick = {
                                showMenu = false
                                onSubredditClick(post.subreddit)
                            }
                        )
                        DropdownMenuItem(
                            text = { Text("Hide post") },
                            leadingIcon = { Icon(Icons.Outlined.VisibilityOff, null) },
                            onClick = {
                                showMenu = false
                                onHidePost()
                            }
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Post Flair if present
            if (!post.linkFlairText.isNullOrBlank()) {
                Surface(
                    shape = RoundedCornerShape(6.dp),
                    color = MaterialTheme.colorScheme.secondaryContainer,
                    modifier = Modifier.padding(bottom = 6.dp)
                ) {
                    Text(
                        text = post.linkFlairText,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSecondaryContainer,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                    )
                }
            }

            // Post Title
            Text(
                text = post.title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
                lineHeight = 22.sp
            )

            // Selftext snippet
            if (post.isSelf && post.selftext.isNotBlank()) {
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = post.selftext,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 4,
                    overflow = TextOverflow.Ellipsis
                )
            }

            // Media viewer (images, videos, gallery)
            if (post.hasMedia) {
                Spacer(modifier = Modifier.height(12.dp))
                MediaViewer(
                    post = post,
                    blurNsfw = blurNsfw,
                    blurSpoiler = blurSpoiler,
                    onMediaClick = onPostClick
                )
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Action Bar
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                // Vote pill
                Surface(
                    shape = RoundedCornerShape(20.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp)
                    ) {
                        IconButton(
                            onClick = { onVote(1) },
                            modifier = Modifier.size(34.dp)
                        ) {
                            Icon(
                                imageVector = if (post.likes == true) Icons.Filled.ArrowUpward else Icons.Outlined.ArrowUpward,
                                contentDescription = "Upvote",
                                tint = if (post.likes == true) UpvoteOrange else MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(18.dp)
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
                            modifier = Modifier.padding(horizontal = 4.dp)
                        )

                        IconButton(
                            onClick = { onVote(-1) },
                            modifier = Modifier.size(34.dp)
                        ) {
                            Icon(
                                imageVector = if (post.likes == false) Icons.Filled.ArrowDownward else Icons.Outlined.ArrowDownward,
                                contentDescription = "Downvote",
                                tint = if (post.likes == false) DownvoteBlue else MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                }

                // Comments pill
                Surface(
                    shape = RoundedCornerShape(20.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f),
                    modifier = Modifier.clickable { onPostClick() }
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Outlined.ChatBubbleOutline,
                            contentDescription = "Comments",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = formatScore(post.numComments),
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }

                // Share & Save Actions
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(
                        onClick = {
                            val shareUrl = if (post.permalink.isNotBlank()) "https://reddit.com${post.permalink}" else post.url
                            val sendIntent = Intent().apply {
                                action = Intent.ACTION_SEND
                                putExtra(Intent.EXTRA_TEXT, "${post.title}\n$shareUrl")
                                type = "text/plain"
                            }
                            context.startActivity(Intent.createChooser(sendIntent, "Share post"))
                        },
                        modifier = Modifier.size(36.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Outlined.Share,
                            contentDescription = "Share",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(20.dp)
                        )
                    }

                    IconButton(
                        onClick = { onToggleSave() },
                        modifier = Modifier.size(36.dp)
                    ) {
                        Icon(
                            imageVector = if (isSaved) Icons.Filled.Bookmark else Icons.Outlined.BookmarkBorder,
                            contentDescription = "Save",
                            tint = if (isSaved) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }
            }
        }
    }
}

fun formatScore(score: Int): String {
    return when {
        score >= 1000000 -> String.format("%.1fM", score / 1000000.0)
        score >= 1000 -> String.format("%.1fk", score / 1000.0)
        else -> score.toString()
    }
}

fun formatTimeAgo(utcSeconds: Long): String {
    val diff = (System.currentTimeMillis() / 1000) - utcSeconds
    return when {
        diff < 60 -> "just now"
        diff < 3600 -> "${diff / 60}m"
        diff < 86400 -> "${diff / 3600}h"
        diff < 86400 * 30 -> "${diff / 86400}d"
        diff < 86400 * 365 -> "${diff / (86400 * 30)}mo"
        else -> "${diff / (86400 * 365)}y"
    }
}
