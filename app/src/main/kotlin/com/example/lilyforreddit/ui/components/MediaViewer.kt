package com.example.lilyforreddit.ui.components

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.OpenInNew
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.example.lilyforreddit.data.models.GalleryItem
import com.example.lilyforreddit.data.models.Post
import com.example.lilyforreddit.data.models.PostType

@Composable
fun MediaViewer(
    post: Post,
    modifier: Modifier = Modifier,
    blurNsfw: Boolean = true,
    blurSpoiler: Boolean = true,
    onMediaClick: (() -> Unit)? = null
) {
    var showFullDialog by remember { mutableStateOf(false) }
    var selectedGalleryIndex by remember { mutableIntStateOf(0) }
    val context = LocalContext.current

    val shouldBlur = (post.over18 && blurNsfw) || (post.spoiler && blurSpoiler)
    var isRevealed by remember { mutableStateOf(!shouldBlur) }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
    ) {
        when (post.type) {
            PostType.IMAGE, PostType.GIF -> {
                val imageUrl = post.previewUrl ?: post.url
                if (imageUrl.isNotBlank()) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 180.dp, max = 400.dp)
                            .clickable {
                                if (!isRevealed) {
                                    isRevealed = true
                                } else {
                                    showFullDialog = true
                                    onMediaClick?.invoke()
                                }
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        AsyncImage(
                            model = ImageRequest.Builder(context)
                                .data(imageUrl)
                                .crossfade(true)
                                .build(),
                            contentDescription = post.title,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .fillMaxWidth()
                                .heightIn(min = 180.dp, max = 400.dp)
                        )
                        if (!isRevealed) {
                            Surface(
                                color = Color.Black.copy(alpha = 0.75f),
                                shape = RoundedCornerShape(16.dp)
                            ) {
                                Text(
                                    text = if (post.over18) "NSFW · Tap to reveal" else "Spoiler · Tap to reveal",
                                    color = Color.White,
                                    style = MaterialTheme.typography.labelMedium,
                                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                                )
                            }
                        }
                    }
                }
            }

            PostType.GALLERY -> {
                if (post.gallery.isNotEmpty()) {
                    val pagerState = rememberPagerState { post.gallery.size }
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(280.dp)
                    ) {
                        HorizontalPager(
                            state = pagerState,
                            modifier = Modifier.fillMaxSize()
                        ) { page ->
                            val item = post.gallery[page]
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .clickable {
                                        selectedGalleryIndex = page
                                        showFullDialog = true
                                    },
                                contentAlignment = Alignment.Center
                            ) {
                                AsyncImage(
                                    model = ImageRequest.Builder(context)
                                        .data(item.url)
                                        .crossfade(true)
                                        .build(),
                                    contentDescription = item.caption ?: post.title,
                                    contentScale = ContentScale.Crop,
                                    modifier = Modifier.fillMaxSize()
                                )
                            }
                        }

                        // Gallery Pill Counter
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = Color.Black.copy(alpha = 0.65f),
                            modifier = Modifier
                                .align(Alignment.TopEnd)
                                .padding(12.dp)
                        ) {
                            Text(
                                text = "${pagerState.currentPage + 1}/${post.gallery.size}",
                                color = Color.White,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        }

                        // Caption if present
                        val currentCaption = post.gallery.getOrNull(pagerState.currentPage)?.caption
                        if (!currentCaption.isNullOrBlank()) {
                            Surface(
                                shape = RoundedCornerShape(topStart = 8.dp, topEnd = 8.dp),
                                color = Color.Black.copy(alpha = 0.65f),
                                modifier = Modifier
                                    .align(Alignment.BottomCenter)
                                    .fillMaxWidth()
                            ) {
                                Text(
                                    text = currentCaption,
                                    color = Color.White,
                                    style = MaterialTheme.typography.bodySmall,
                                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                                )
                            }
                        }
                    }
                }
            }

            PostType.VIDEO -> {
                val preview = post.previewUrl ?: "https://images.unsplash.com/photo-1542751371-adc38448a05e?w=800"
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(240.dp)
                        .clickable {
                            val videoUrl = post.fallbackVideoUrl ?: post.hlsUrl ?: post.url
                            if (videoUrl.isNotBlank()) {
                                try {
                                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(videoUrl))
                                    context.startActivity(intent)
                                } catch (_: Exception) {}
                            }
                        },
                    contentAlignment = Alignment.Center
                ) {
                    AsyncImage(
                        model = ImageRequest.Builder(context)
                            .data(preview)
                            .crossfade(true)
                            .build(),
                        contentDescription = "Video preview",
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxSize()
                    )
                    Surface(
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.9f),
                        shadowElevation = 6.dp,
                        modifier = Modifier.size(56.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                imageVector = Icons.Filled.PlayArrow,
                                contentDescription = "Play video",
                                tint = MaterialTheme.colorScheme.onPrimary,
                                modifier = Modifier.size(32.dp)
                            )
                        }
                    }
                }
            }

            PostType.LINK -> {
                if (post.previewUrl != null) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(180.dp)
                            .clickable {
                                if (post.url.isNotBlank()) {
                                    try {
                                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(post.url))
                                        context.startActivity(intent)
                                    } catch (_: Exception) {}
                                }
                            }
                    ) {
                        AsyncImage(
                            model = ImageRequest.Builder(context)
                                .data(post.previewUrl)
                                .crossfade(true)
                                .build(),
                            contentDescription = post.title,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier.fillMaxSize()
                        )
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = Color.Black.copy(alpha = 0.7f),
                            modifier = Modifier
                                .align(Alignment.BottomStart)
                                .padding(8.dp)
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = Icons.Filled.OpenInNew,
                                    contentDescription = null,
                                    tint = Color.White,
                                    modifier = Modifier.size(14.dp)
                                )
                                Spacer(modifier = Modifier.width(4.dp))
                                Text(
                                    text = post.domain.ifBlank { "External Link" },
                                    color = Color.White,
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Medium
                                )
                            }
                        }
                    }
                }
            }

            PostType.SELF -> {
                // Self text rendered directly in PostCard
            }
        }
    }

    if (showFullDialog) {
        Dialog(
            onDismissRequest = { showFullDialog = false },
            properties = DialogProperties(usePlatformDefaultWidth = false)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black)
            ) {
                if (post.type == PostType.GALLERY && post.gallery.isNotEmpty()) {
                    val fullPagerState = rememberPagerState(
                        initialPage = selectedGalleryIndex
                    ) { post.gallery.size }

                    HorizontalPager(
                        state = fullPagerState,
                        modifier = Modifier.fillMaxSize()
                    ) { page ->
                        AsyncImage(
                            model = post.gallery[page].url,
                            contentDescription = null,
                            contentScale = ContentScale.Fit,
                            modifier = Modifier.fillMaxSize()
                        )
                    }

                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = Color.Black.copy(alpha = 0.6f),
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .navigationBarsPadding()
                            .padding(bottom = 24.dp)
                    ) {
                        Text(
                            text = "${fullPagerState.currentPage + 1} of ${post.gallery.size}",
                            color = Color.White,
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp)
                        )
                    }
                } else {
                    val fullImageUrl = post.previewUrl ?: post.url
                    AsyncImage(
                        model = fullImageUrl,
                        contentDescription = null,
                        contentScale = ContentScale.Fit,
                        modifier = Modifier.fillMaxSize()
                    )
                }

                IconButton(
                    onClick = { showFullDialog = false },
                    modifier = Modifier
                        .statusBarsPadding()
                        .padding(16.dp)
                        .align(Alignment.TopEnd)
                        .background(Color.Black.copy(alpha = 0.5f), CircleShape)
                ) {
                    Icon(Icons.Filled.Close, contentDescription = "Close", tint = Color.White)
                }
            }
        }
    }
}
