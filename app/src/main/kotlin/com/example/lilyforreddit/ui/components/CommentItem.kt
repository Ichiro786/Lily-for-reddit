package com.example.lilyforreddit.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Reply
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.outlined.ArrowDownward
import androidx.compose.material.icons.outlined.ArrowUpward
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
import com.example.lilyforreddit.data.models.Comment
import com.example.lilyforreddit.ui.theme.DepthLineColors
import com.example.lilyforreddit.ui.theme.DownvoteBlue
import com.example.lilyforreddit.ui.theme.UpvoteOrange

@Composable
fun CommentItem(
    comment: Comment,
    opAuthor: String,
    modifier: Modifier = Modifier,
    onReplyClick: (Comment) -> Unit,
    onUserClick: (String) -> Unit
) {
    var isCollapsed by remember { mutableStateOf(comment.isCollapsed) }
    var userVote by remember { mutableStateOf(comment.likes) }
    var scoreDelta by remember { mutableIntStateOf(0) }

    val depthColor = DepthLineColors[comment.depth % DepthLineColors.size]
    val isOp = comment.author.equals(opAuthor, ignoreCase = true) || comment.isOp

    Row(
        modifier = modifier
            .fillMaxWidth()
            .testTag("comment_${comment.id}")
            .padding(vertical = 4.dp)
    ) {
        // Vertical depth indicator lines
        if (comment.depth > 0) {
            for (i in 0 until comment.depth) {
                val lineColor = DepthLineColors[i % DepthLineColors.size]
                Box(
                    modifier = Modifier
                        .width(2.dp)
                        .fillMaxHeight()
                        .padding(vertical = 2.dp)
                        .background(lineColor.copy(alpha = 0.6f), RoundedCornerShape(1.dp))
                )
                Spacer(modifier = Modifier.width(10.dp))
            }
        }

        // Comment content card
        Column(
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(12.dp))
                .background(
                    if (comment.depth == 0) MaterialTheme.colorScheme.surface
                    else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)
                )
                .clickable { isCollapsed = !isCollapsed }
                .padding(horizontal = 12.dp, vertical = 8.dp)
        ) {
            // Header: Author + Badges + Score + Time
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "u/${comment.author}",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = if (isOp) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.clickable { onUserClick(comment.author) }
                )

                if (isOp) {
                    Spacer(modifier = Modifier.width(4.dp))
                    Surface(
                        shape = RoundedCornerShape(4.dp),
                        color = MaterialTheme.colorScheme.primaryContainer
                    ) {
                        Text(
                            text = "OP",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                            modifier = Modifier.padding(horizontal = 4.dp, vertical = 1.dp)
                        )
                    }
                }

                if (comment.distinguished != null) {
                    Spacer(modifier = Modifier.width(4.dp))
                    Icon(
                        imageVector = Icons.Filled.Shield,
                        contentDescription = "Moderator",
                        tint = Color(0xFF4CAF50),
                        modifier = Modifier.size(14.dp)
                    )
                }

                Spacer(modifier = Modifier.width(6.dp))

                Text(
                    text = "• ${formatScore(comment.score + scoreDelta)} pts",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Text(
                    text = " • ${formatTimeAgo(comment.createdUtc)}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                if (isCollapsed && comment.replies.isNotEmpty()) {
                    Spacer(modifier = Modifier.width(6.dp))
                    Surface(
                        shape = RoundedCornerShape(4.dp),
                        color = MaterialTheme.colorScheme.secondaryContainer
                    ) {
                        Text(
                            text = "+${comment.replies.size} replies",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSecondaryContainer,
                            modifier = Modifier.padding(horizontal = 4.dp, vertical = 1.dp)
                        )
                    }
                }
            }

            AnimatedVisibility(visible = !isCollapsed) {
                Column {
                    Spacer(modifier = Modifier.height(6.dp))

                    Text(
                        text = comment.body,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface,
                        lineHeight = 20.sp
                    )

                    Spacer(modifier = Modifier.height(6.dp))

                    // Comment Action Bar
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.End
                    ) {
                        // Upvote
                        IconButton(
                            onClick = {
                                val (newVote, delta) = when (userVote) {
                                    true -> Pair(null, -1)
                                    false -> Pair(true, 2)
                                    null -> Pair(true, 1)
                                }
                                userVote = newVote
                                scoreDelta += delta
                            },
                            modifier = Modifier.size(30.dp)
                        ) {
                            Icon(
                                imageVector = if (userVote == true) Icons.Filled.ArrowUpward else Icons.Outlined.ArrowUpward,
                                contentDescription = "Upvote comment",
                                tint = if (userVote == true) UpvoteOrange else MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(16.dp)
                            )
                        }

                        // Downvote
                        IconButton(
                            onClick = {
                                val (newVote, delta) = when (userVote) {
                                    false -> Pair(null, 1)
                                    true -> Pair(false, -2)
                                    null -> Pair(false, -1)
                                }
                                userVote = newVote
                                scoreDelta += delta
                            },
                            modifier = Modifier.size(30.dp)
                        ) {
                            Icon(
                                imageVector = if (userVote == false) Icons.Filled.ArrowDownward else Icons.Outlined.ArrowDownward,
                                contentDescription = "Downvote comment",
                                tint = if (userVote == false) DownvoteBlue else MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(16.dp)
                            )
                        }

                        Spacer(modifier = Modifier.width(4.dp))

                        // Reply button
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                            modifier = Modifier.clickable { onReplyClick(comment) }
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = Icons.Filled.Reply,
                                    contentDescription = "Reply",
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.size(14.dp)
                                )
                                Spacer(modifier = Modifier.width(4.dp))
                                Text(
                                    text = "Reply",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // Render nested replies recursively if not collapsed
    if (!isCollapsed && comment.replies.isNotEmpty()) {
        Column(modifier = Modifier.fillMaxWidth()) {
            comment.replies.forEach { reply ->
                CommentItem(
                    comment = reply,
                    opAuthor = opAuthor,
                    onReplyClick = onReplyClick,
                    onUserClick = onUserClick
                )
            }
        }
    }
}
