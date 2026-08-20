package com.example.lilyforreddit.ui.submit

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.lilyforreddit.LilyApp
import com.example.lilyforreddit.data.models.PostType

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SubmitPostScreen(
    initialSubreddit: String?,
    onBack: () -> Unit,
    onPostCreated: (String, String) -> Unit,
    modifier: Modifier = Modifier
) {
    var subreddit by remember { mutableStateOf(initialSubreddit ?: "androiddev") }
    var title by remember { mutableStateOf("") }
    var selectedType by remember { mutableStateOf(PostType.SELF) }
    var textContent by remember { mutableStateOf("") }
    var urlContent by remember { mutableStateOf("") }
    var flairText by remember { mutableStateOf("") }
    var isNsfw by remember { mutableStateOf(false) }
    var isSpoiler by remember { mutableStateOf(false) }
    var isSubmitting by remember { mutableStateOf(false) }

    val app = LilyApp.instance

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = { Text("Create Post", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    Button(
                        onClick = {
                            if (title.isNotBlank() && subreddit.isNotBlank()) {
                                isSubmitting = true
                                val newPost = app.redditRepository.submitNewPost(
                                    subreddit = subreddit.removePrefix("r/").trim(),
                                    title = title.trim(),
                                    kind = selectedType,
                                    text = textContent.trim(),
                                    url = urlContent.trim(),
                                    flair = flairText.takeIf { it.isNotBlank() }
                                )
                                onPostCreated(newPost.subreddit, newPost.id)
                            }
                        },
                        enabled = title.isNotBlank() && subreddit.isNotBlank() && !isSubmitting,
                        modifier = Modifier.testTag("submit_post_button")
                    ) {
                        Text("Post")
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Target Subreddit
            OutlinedTextField(
                value = subreddit,
                onValueChange = { subreddit = it },
                label = { Text("Subreddit") },
                prefix = { Text("r/") },
                singleLine = true,
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("submit_subreddit_input"),
                shape = RoundedCornerShape(12.dp)
            )

            // Post Type Chips
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                listOf(
                    PostType.SELF to "Text",
                    PostType.LINK to "Link",
                    PostType.IMAGE to "Image"
                ).forEach { (type, label) ->
                    FilterChip(
                        selected = selectedType == type,
                        onClick = { selectedType = type },
                        label = { Text(label) }
                    )
                }
            }

            // Post Title
            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                label = { Text("Title") },
                placeholder = { Text("An interesting title...") },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("submit_title_input"),
                shape = RoundedCornerShape(12.dp)
            )

            // Content based on type
            when (selectedType) {
                PostType.SELF -> {
                    OutlinedTextField(
                        value = textContent,
                        onValueChange = { textContent = it },
                        label = { Text("Body text (Markdown supported)") },
                        placeholder = { Text("Share your thoughts, story, or discussion points...") },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(180.dp)
                            .testTag("submit_body_input"),
                        shape = RoundedCornerShape(12.dp)
                    )
                }
                PostType.LINK, PostType.IMAGE -> {
                    OutlinedTextField(
                        value = urlContent,
                        onValueChange = { urlContent = it },
                        label = { Text(if (selectedType == PostType.LINK) "URL" else "Image / Media URL") },
                        placeholder = { Text("https://...") },
                        singleLine = true,
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("submit_url_input"),
                        shape = RoundedCornerShape(12.dp)
                    )
                }
                else -> {}
            }

            // Optional Flair
            OutlinedTextField(
                value = flairText,
                onValueChange = { flairText = it },
                label = { Text("Post Flair (Optional)") },
                placeholder = { Text("e.g. Discussion, News, Question") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp)
            )

            // Tags (NSFW / Spoiler)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                FilterChip(
                    selected = isNsfw,
                    onClick = { isNsfw = !isNsfw },
                    label = { Text("18+ NSFW") }
                )

                FilterChip(
                    selected = isSpoiler,
                    onClick = { isSpoiler = !isSpoiler },
                    label = { Text("Spoiler") }
                )
            }
        }
    }
}
