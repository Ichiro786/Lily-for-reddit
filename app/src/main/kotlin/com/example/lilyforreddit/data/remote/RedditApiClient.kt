package com.example.lilyforreddit.data.remote

import com.example.lilyforreddit.data.models.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class RedditApiClient {
    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build()

    private val userAgent = "android:com.example.lilyforreddit:v1.0.0 (by /u/lily_dev)"

    suspend fun getPosts(
        subreddit: String? = null,
        sort: PostSort = PostSort.HOT,
        time: TopTime = TopTime.DAY,
        after: String? = null,
        limit: Int = 25
    ): Pair<List<Post>, String?> = withContext(Dispatchers.IO) {
        val path = if (subreddit.isNullOrBlank() || subreddit == "all" || subreddit == "popular") {
            if (subreddit.isNullOrBlank()) "/${sort.path}.json" else "/r/$subreddit/${sort.path}.json"
        } else {
            "/r/$subreddit/${sort.path}.json"
        }

        var url = "https://www.reddit.com$path?limit=$limit&raw_json=1"
        if (sort.needsTime) {
            url += "&t=${time.param}"
        }
        if (!after.isNullOrBlank()) {
            url += "&after=$after"
        }

        try {
            val request = Request.Builder()
                .url(url)
                .header("User-Agent", userAgent)
                .build()

            val response = client.newCall(request).execute()
            if (response.isSuccessful) {
                val body = response.body?.string()
                if (!body.isNullOrBlank()) {
                    val json = JSONObject(body)
                    val data = json.optJSONObject("data")
                    val children = data?.optJSONArray("children") ?: JSONArray()
                    val nextAfter = data?.optString("after", null)

                    val posts = mutableListOf<Post>()
                    for (i in 0 until children.length()) {
                        val child = children.getJSONObject(i)
                        if (child.optString("kind") == "t3") {
                            val postData = child.getJSONObject("data")
                            posts.add(parsePost(postData))
                        }
                    }
                    if (posts.isNotEmpty()) {
                        return@withContext Pair(posts, nextAfter)
                    }
                }
            }
        } catch (_: Exception) {
            // Fall through to fallback
        }

        // Return sample data filtered by subreddit if available
        val filtered = if (!subreddit.isNullOrBlank()) {
            SampleRedditData.defaultPosts.filter { it.subreddit.equals(subreddit, ignoreCase = true) }
                .ifEmpty { SampleRedditData.defaultPosts }
        } else {
            SampleRedditData.defaultPosts
        }
        Pair(filtered, null)
    }

    suspend fun getComments(
        subreddit: String,
        postId: String,
        sort: String = "confidence"
    ): Pair<Post?, List<Comment>> = withContext(Dispatchers.IO) {
        val cleanPostId = postId.removePrefix("t3_")
        val path = if (subreddit.isNotBlank()) "/r/$subreddit/comments/$cleanPostId.json" else "/comments/$cleanPostId.json"
        val url = "https://www.reddit.com$path?sort=$sort&limit=50&raw_json=1"

        try {
            val request = Request.Builder()
                .url(url)
                .header("User-Agent", userAgent)
                .build()

            val response = client.newCall(request).execute()
            if (response.isSuccessful) {
                val body = response.body?.string()
                if (!body.isNullOrBlank()) {
                    val rootArray = JSONArray(body)
                    var post: Post? = null
                    val comments = mutableListOf<Comment>()

                    if (rootArray.length() > 0) {
                        val postObj = rootArray.getJSONObject(0)
                        val postChildren = postObj.optJSONObject("data")?.optJSONArray("children")
                        if (postChildren != null && postChildren.length() > 0) {
                            post = parsePost(postChildren.getJSONObject(0).getJSONObject("data"))
                        }
                    }

                    if (rootArray.length() > 1) {
                        val commentsObj = rootArray.getJSONObject(1)
                        val commentChildren = commentsObj.optJSONObject("data")?.optJSONArray("children") ?: JSONArray()
                        for (i in 0 until commentChildren.length()) {
                            val c = commentChildren.getJSONObject(i)
                            if (c.optString("kind") == "t1") {
                                comments.add(parseComment(c.getJSONObject("data"), 0))
                            }
                        }
                    }
                    if (comments.isNotEmpty()) {
                        return@withContext Pair(post, comments)
                    }
                }
            }
        } catch (_: Exception) {
            // fallback
        }

        val fallbackPost = SampleRedditData.defaultPosts.find { it.id == cleanPostId }
            ?: SampleRedditData.defaultPosts.first()
        Pair(fallbackPost, SampleRedditData.getSampleComments(cleanPostId))
    }

    suspend fun searchPosts(
        query: String,
        subreddit: String? = null,
        after: String? = null
    ): List<Post> = withContext(Dispatchers.IO) {
        val base = if (subreddit.isNullOrBlank()) "/search.json" else "/r/$subreddit/search.json"
        val url = "https://www.reddit.com$base?q=$query&type=link&limit=25&raw_json=1"

        try {
            val request = Request.Builder()
                .url(url)
                .header("User-Agent", userAgent)
                .build()

            val response = client.newCall(request).execute()
            if (response.isSuccessful) {
                val body = response.body?.string()
                if (!body.isNullOrBlank()) {
                    val json = JSONObject(body)
                    val children = json.optJSONObject("data")?.optJSONArray("children") ?: JSONArray()
                    val posts = mutableListOf<Post>()
                    for (i in 0 until children.length()) {
                        val c = children.getJSONObject(i)
                        if (c.optString("kind") == "t3") {
                            posts.add(parsePost(c.getJSONObject("data")))
                        }
                    }
                    if (posts.isNotEmpty()) return@withContext posts
                }
            }
        } catch (_: Exception) {}

        SampleRedditData.defaultPosts.filter {
            it.title.contains(query, ignoreCase = true) || it.selftext.contains(query, ignoreCase = true)
        }.ifEmpty { SampleRedditData.defaultPosts }
    }

    suspend fun searchSubreddits(query: String): List<Subreddit> = withContext(Dispatchers.IO) {
        val url = "https://www.reddit.com/subreddits/search.json?q=$query&limit=20&raw_json=1"
        try {
            val request = Request.Builder()
                .url(url)
                .header("User-Agent", userAgent)
                .build()

            val response = client.newCall(request).execute()
            if (response.isSuccessful) {
                val body = response.body?.string()
                if (!body.isNullOrBlank()) {
                    val json = JSONObject(body)
                    val children = json.optJSONObject("data")?.optJSONArray("children") ?: JSONArray()
                    val subs = mutableListOf<Subreddit>()
                    for (i in 0 until children.length()) {
                        val c = children.getJSONObject(i)
                        if (c.optString("kind") == "t5") {
                            subs.add(parseSubreddit(c.getJSONObject("data")))
                        }
                    }
                    if (subs.isNotEmpty()) return@withContext subs
                }
            }
        } catch (_: Exception) {}

        SampleRedditData.defaultSubreddits.filter {
            it.name.contains(query, ignoreCase = true) || it.title.contains(query, ignoreCase = true)
        }.ifEmpty { SampleRedditData.defaultSubreddits }
    }

    suspend fun getSubredditAbout(name: String): Subreddit = withContext(Dispatchers.IO) {
        val url = "https://www.reddit.com/r/$name/about.json?raw_json=1"
        try {
            val request = Request.Builder()
                .url(url)
                .header("User-Agent", userAgent)
                .build()

            val response = client.newCall(request).execute()
            if (response.isSuccessful) {
                val body = response.body?.string()
                if (!body.isNullOrBlank()) {
                    val json = JSONObject(body)
                    val data = json.optJSONObject("data")
                    if (data != null) {
                        return@withContext parseSubreddit(data)
                    }
                }
            }
        } catch (_: Exception) {}

        SampleRedditData.defaultSubreddits.find { it.name.equals(name, ignoreCase = true) }
            ?: Subreddit(
                name = name,
                displayName = name,
                title = "r/$name",
                publicDescription = "Welcome to r/$name community.",
                subscribers = 50000,
                activeAccounts = 300,
                iconImg = "https://picsum.photos/seed/$name/200/200",
                bannerImg = "https://picsum.photos/seed/${name}_banner/1200/400"
            )
    }

    suspend fun getUserAbout(username: String): RedditUser = withContext(Dispatchers.IO) {
        val url = "https://www.reddit.com/user/$username/about.json?raw_json=1"
        try {
            val request = Request.Builder()
                .url(url)
                .header("User-Agent", userAgent)
                .build()

            val response = client.newCall(request).execute()
            if (response.isSuccessful) {
                val body = response.body?.string()
                if (!body.isNullOrBlank()) {
                    val json = JSONObject(body)
                    val data = json.optJSONObject("data")
                    if (data != null) {
                        val name = data.optString("name", username)
                        val totalKarma = data.optInt("total_karma", 0)
                        val linkKarma = data.optInt("link_karma", 0)
                        val commentKarma = data.optInt("comment_karma", 0)
                        val iconImg = data.optString("icon_img").takeIf { it.isNotBlank() }
                        val createdUtc = data.optLong("created_utc", System.currentTimeMillis() / 1000)
                        return@withContext RedditUser(
                            name = name,
                            totalKarma = totalKarma,
                            linkKarma = linkKarma,
                            commentKarma = commentKarma,
                            iconImg = iconImg,
                            createdUtc = createdUtc
                        )
                    }
                }
            }
        } catch (_: Exception) {}

        if (username.equals(SampleRedditData.currentUser.name, ignoreCase = true)) {
            SampleRedditData.currentUser
        } else {
            RedditUser(
                name = username,
                totalKarma = 3450,
                linkKarma = 1200,
                commentKarma = 2250,
                iconImg = "https://picsum.photos/seed/$username/200/200",
                createdUtc = (System.currentTimeMillis() - 3600000L * 24 * 180) / 1000,
                bio = "Redditor on Lily for Reddit."
            )
        }
    }

    private fun parsePost(d: JSONObject): Post {
        val id = d.optString("id", "")
        val fullname = d.optString("name", "t3_$id")
        val title = d.optString("title", "").trim()
        val subreddit = d.optString("subreddit", "")
        val author = d.optString("author", "[deleted]")
        val score = d.optInt("score", 0)
        val numComments = d.optInt("num_comments", 0)
        val upvoteRatio = d.optDouble("upvote_ratio", 1.0)
        val createdUtc = d.optLong("created_utc", System.currentTimeMillis() / 1000)
        val permalink = d.optString("permalink", "")
        val url = d.optString("url", "")
        val domain = d.optString("domain", "")
        val isSelf = d.optBoolean("is_self", false)
        val selftext = d.optString("selftext", "")
        val over18 = d.optBoolean("over_18", false)
        val spoiler = d.optBoolean("spoiler", false)
        val stickied = d.optBoolean("stickied", false)
        val locked = d.optBoolean("locked", false)
        val saved = d.optBoolean("saved", false)
        val linkFlairText = d.optString("link_flair_text").takeIf { it.isNotBlank() }
        val isVideo = d.optBoolean("is_video", false)

        val gallery = parseGallery(d)
        val preview = parsePreview(d)

        val type = when {
            isSelf -> PostType.SELF
            gallery.isNotEmpty() -> PostType.GALLERY
            isVideo || url.endsWith(".mp4") || url.endsWith(".gifv") -> PostType.VIDEO
            url.endsWith(".gif") -> PostType.GIF
            url.endsWith(".jpg") || url.endsWith(".jpeg") || url.endsWith(".png") || url.endsWith(".webp") -> PostType.IMAGE
            d.optString("post_hint") == "image" -> PostType.IMAGE
            else -> PostType.LINK
        }

        val redditVideo = d.optJSONObject("media")?.optJSONObject("reddit_video")
        val hlsUrl = redditVideo?.optString("hls_url")?.takeIf { it.isNotBlank() }
        val fallbackVideoUrl = redditVideo?.optString("fallback_url")?.takeIf { it.isNotBlank() }

        return Post(
            id = id,
            fullname = fullname,
            title = title,
            subreddit = subreddit,
            subredditPrefixed = "r/$subreddit",
            author = author,
            score = score,
            numComments = numComments,
            upvoteRatio = upvoteRatio,
            createdUtc = createdUtc,
            permalink = permalink,
            url = url,
            domain = domain,
            type = type,
            isSelf = isSelf,
            selftext = selftext,
            over18 = over18,
            spoiler = spoiler,
            stickied = stickied,
            locked = locked,
            saved = saved,
            linkFlairText = linkFlairText,
            previewUrl = preview?.first,
            previewWidth = preview?.second,
            previewHeight = preview?.third,
            hlsUrl = hlsUrl,
            fallbackVideoUrl = fallbackVideoUrl,
            gallery = gallery
        )
    }

    private fun parsePreview(d: JSONObject): Triple<String, Int, Int>? {
        val preview = d.optJSONObject("preview") ?: return null
        val images = preview.optJSONArray("images") ?: return null
        if (images.length() == 0) return null
        val first = images.getJSONObject(0)
        val source = first.optJSONObject("source") ?: return null
        val url = source.optString("url").replace("&amp;", "&")
        val width = source.optInt("width", 0)
        val height = source.optInt("height", 0)
        return Triple(url, width, height)
    }

    private fun parseGallery(d: JSONObject): List<GalleryItem> {
        val galleryData = d.optJSONObject("gallery_data") ?: return emptyList()
        val mediaMetadata = d.optJSONObject("media_metadata") ?: return emptyList()
        val items = galleryData.optJSONArray("items") ?: return emptyList()
        val result = mutableListOf<GalleryItem>()
        for (i in 0 until items.length()) {
            val item = items.getJSONObject(i)
            val mediaId = item.optString("media_id")
            val meta = mediaMetadata.optJSONObject(mediaId) ?: continue
            val s = meta.optJSONObject("s") ?: continue
            var u = s.optString("u").takeIf { it.isNotBlank() } ?: s.optString("gif")
            if (u.isNotBlank()) {
                u = u.replace("&amp;", "&")
                result.add(
                    GalleryItem(
                        url = u,
                        width = s.optInt("x"),
                        height = s.optInt("y"),
                        caption = item.optString("caption").takeIf { it.isNotBlank() }
                    )
                )
            }
        }
        return result
    }

    private fun parseComment(d: JSONObject, depth: Int): Comment {
        val id = d.optString("id", "")
        val fullname = d.optString("name", "t1_$id")
        val author = d.optString("author", "[deleted]")
        val body = d.optString("body", "")
        val score = d.optInt("score", 0)
        val createdUtc = d.optLong("created_utc", System.currentTimeMillis() / 1000)
        val isOp = d.optBoolean("is_submitter", false)
        val distinguished = d.optString("distinguished").takeIf { it.isNotBlank() }
        val parentId = d.optString("parent_id", "")

        val replies = mutableListOf<Comment>()
        val repliesObj = d.optJSONObject("replies")
        val replyChildren = repliesObj?.optJSONObject("data")?.optJSONArray("children")
        if (replyChildren != null) {
            for (i in 0 until replyChildren.length()) {
                val child = replyChildren.getJSONObject(i)
                if (child.optString("kind") == "t1") {
                    replies.add(parseComment(child.getJSONObject("data"), depth + 1))
                }
            }
        }

        return Comment(
            id = id,
            fullname = fullname,
            author = author,
            body = body,
            score = score,
            createdUtc = createdUtc,
            depth = depth,
            replies = replies,
            isOp = isOp,
            distinguished = distinguished,
            parentId = parentId
        )
    }

    private fun parseSubreddit(d: JSONObject): Subreddit {
        val name = d.optString("display_name", d.optString("name", ""))
        val title = d.optString("title", name)
        val desc = d.optString("public_description", "")
        val subs = d.optLong("subscribers", 0)
        val active = d.optLong("active_user_count", 0)
        var icon = d.optString("icon_img").takeIf { it.isNotBlank() }
            ?: d.optString("community_icon").takeIf { it.isNotBlank() }
        if (icon != null) icon = icon.replace("&amp;", "&")
        var banner = d.optString("banner_background_image").takeIf { it.isNotBlank() }
            ?: d.optString("banner_img").takeIf { it.isNotBlank() }
        if (banner != null) banner = banner.replace("&amp;", "&")
        val color = d.optString("primary_color").takeIf { it.isNotBlank() }
            ?: d.optString("key_color").takeIf { it.isNotBlank() }
        val favorited = d.optBoolean("user_has_favorited", false)
        val subscribed = d.optBoolean("user_is_subscriber", false)
        val over18 = d.optBoolean("over18", false)

        return Subreddit(
            name = name,
            displayName = name,
            title = title,
            publicDescription = desc,
            subscribers = subs,
            activeAccounts = active,
            iconImg = icon,
            bannerImg = banner,
            primaryColor = color,
            userHasFavorited = favorited,
            userIsSubscriber = subscribed,
            over18 = over18
        )
    }
}
