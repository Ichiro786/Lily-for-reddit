package com.example.lilyforreddit.data.repository

import com.example.lilyforreddit.data.local.*
import com.example.lilyforreddit.data.models.*
import com.example.lilyforreddit.data.remote.RedditApiClient
import com.example.lilyforreddit.data.remote.SampleRedditData
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map

class RedditRepository(
    private val apiClient: RedditApiClient,
    private val database: LilyDatabase
) {
    // In-memory overrides for interactive instant feedback (votes, saved, subscriptions)
    private val postVotes = mutableMapOf<String, Boolean?>()
    private val postScoreDeltas = mutableMapOf<String, Int>()
    private val subscriptions = mutableMapOf<String, Boolean>()
    private val favorites = mutableMapOf<String, Boolean>()
    private val hiddenPosts = mutableSetOf<String>()

    private val _multireddits = MutableStateFlow(SampleRedditData.defaultMultireddits)
    val multireddits = _multireddits.asStateFlow()

    private val _inboxItems = MutableStateFlow(SampleRedditData.defaultInbox)
    val inboxItems = _inboxItems.asStateFlow()

    init {
        // Prime default subscriptions
        SampleRedditData.defaultSubreddits.forEach {
            subscriptions[it.name.lowercase()] = it.userIsSubscriber
            favorites[it.name.lowercase()] = it.userHasFavorited
        }
    }

    suspend fun getPosts(
        subreddit: String? = null,
        sort: PostSort = PostSort.BEST,
        time: TopTime = TopTime.DAY,
        after: String? = null,
        limit: Int = 25
    ): Pair<List<Post>, String?> {
        val (rawPosts, nextAfter) = apiClient.getPosts(subreddit, sort, time, after, limit)
        val posts = rawPosts.filterNot { hiddenPosts.contains(it.id) }.map { applyPostOverrides(it) }
        return Pair(posts, nextAfter)
    }

    suspend fun getForYouFeed(): List<Post> {
        val affinities = database.affinityDao().getAllAffinitiesSync()
        val affinityMap = affinities.associate { it.subreddit.lowercase() to it.score }

        // Fetch candidate posts from /best, /hot, and popular
        val (candidates, _) = apiClient.getPosts(null, PostSort.BEST, TopTime.DAY, null, 30)

        // Rank candidates using on-device affinity and recency
        val now = System.currentTimeMillis() / 1000
        val scored = candidates.map { post ->
            val subKey = post.subreddit.lowercase()
            val isFavorite = favorites[subKey] == true
            val isSubscribed = subscriptions[subKey] != false
            val affinity = affinityMap[subKey] ?: 1.0

            val ageHours = ((now - post.createdUtc).coerceAtLeast(1800)) / 3600.0
            val recency = 1.0 / (1.0 + ageHours / 24.0)

            val baseScore = when {
                isFavorite -> 4.0
                isSubscribed -> 2.5
                else -> 1.0
            }
            val totalScore = (post.score * 0.4 + recency * 50.0 + affinity * 15.0) * baseScore

            val reason = when {
                isFavorite -> "★ Favourite · r/${post.subreddit}"
                affinity > 3.0 -> "Because you engage with r/${post.subreddit}"
                isSubscribed -> "From r/${post.subreddit}"
                else -> "Discover · r/${post.subreddit}"
            }

            Pair(applyPostOverrides(post).copy(feedReason = reason), totalScore)
        }

        return scored.sortedByDescending { it.second }.map { it.first }
    }

    suspend fun getComments(
        subreddit: String,
        postId: String,
        sort: String = "confidence"
    ): Pair<Post?, List<Comment>> {
        val (post, comments) = apiClient.getComments(subreddit, postId, sort)
        val modifiedPost = post?.let { applyPostOverrides(it) }
        // Record affinity for this subreddit
        if (modifiedPost != null) {
            recordSubredditVisit(modifiedPost.subreddit)
            recordHistory(modifiedPost)
        }
        return Pair(modifiedPost, comments)
    }

    suspend fun searchPosts(query: String, subreddit: String? = null): List<Post> {
        val raw = apiClient.searchPosts(query, subreddit)
        return raw.map { applyPostOverrides(it) }
    }

    suspend fun searchSubreddits(query: String): List<Subreddit> {
        val raw = apiClient.searchSubreddits(query)
        return raw.map { applySubredditOverrides(it) }
    }

    suspend fun getSubscribedSubreddits(): List<Subreddit> {
        return SampleRedditData.defaultSubreddits.map { applySubredditOverrides(it) }
            .sortedWith(compareByDescending<Subreddit> { it.userHasFavorited }.thenBy { it.displayName })
    }

    suspend fun getSubredditAbout(name: String): Subreddit {
        val raw = apiClient.getSubredditAbout(name)
        return applySubredditOverrides(raw)
    }

    suspend fun getUserAbout(name: String): RedditUser {
        return apiClient.getUserAbout(name)
    }

    // --- Local DB / Saved Items ---
    fun getAllSavedPosts(): Flow<List<SavedPostEntity>> = database.savedPostDao().getAllSavedPosts()

    fun isPostSaved(postId: String): Flow<Boolean> = database.savedPostDao().isPostSaved(postId)

    suspend fun toggleSavePost(post: Post) {
        val isSaved = database.savedPostDao().isPostSavedSync(post.id)
        if (isSaved) {
            database.savedPostDao().unsavePost(post.id)
        } else {
            database.savedPostDao().savePost(
                SavedPostEntity(
                    id = post.id,
                    fullname = post.fullname,
                    title = post.title,
                    subreddit = post.subreddit,
                    author = post.author,
                    score = post.score,
                    numComments = post.numComments,
                    url = post.url,
                    previewUrl = post.previewUrl,
                    isSelf = post.isSelf,
                    selftext = post.selftext,
                    createdUtc = post.createdUtc
                )
            )
        }
    }

    // --- History ---
    fun getHistory(): Flow<List<HistoryPostEntity>> = database.historyDao().getHistory()

    suspend fun recordHistory(post: Post) {
        database.historyDao().recordHistory(
            HistoryPostEntity(
                id = post.id,
                title = post.title,
                subreddit = post.subreddit,
                author = post.author,
                score = post.score,
                numComments = post.numComments,
                previewUrl = post.previewUrl
            )
        )
    }

    suspend fun clearHistory() {
        database.historyDao().clearHistory()
    }

    // --- Affinity / Learned interests ---
    fun getAllAffinities(): Flow<List<SubredditAffinityEntity>> = database.affinityDao().getAllAffinities()

    suspend fun recordSubredditVisit(subreddit: String) {
        val subKey = subreddit.lowercase()
        val current = database.affinityDao().getAllAffinitiesSync().find { it.subreddit.lowercase() == subKey }
        val newScore = (current?.score ?: 1.0) + 1.0
        database.affinityDao().updateAffinity(
            SubredditAffinityEntity(
                subreddit = subreddit,
                score = newScore,
                lastVisited = System.currentTimeMillis()
            )
        )
    }

    suspend fun resetAllAffinities() {
        database.affinityDao().resetAllAffinities()
    }

    // --- Post Actions ---
    fun vote(postId: String, dir: Int) {
        val currentLike = postVotes[postId]
        val (newLike, delta) = when (dir) {
            1 -> if (currentLike == true) Pair(null, -1) else Pair(true, if (currentLike == false) 2 else 1)
            -1 -> if (currentLike == false) Pair(null, 1) else Pair(false, if (currentLike == true) -2 else -1)
            else -> Pair(null, 0)
        }
        postVotes[postId] = newLike
        postScoreDeltas[postId] = (postScoreDeltas[postId] ?: 0) + delta
    }

    fun hidePost(postId: String) {
        hiddenPosts.add(postId)
    }

    fun toggleSubscribe(subreddit: String) {
        val key = subreddit.lowercase()
        val current = subscriptions[key] ?: false
        subscriptions[key] = !current
    }

    fun toggleFavorite(subreddit: String) {
        val key = subreddit.lowercase()
        val current = favorites[key] ?: false
        favorites[key] = !current
    }

    // --- Inbox & Comments Actions ---
    fun markInboxItemRead(id: String) {
        val current = _inboxItems.value
        _inboxItems.value = current.map {
            if (it.id == id) it.copy(isNew = false) else it
        }
    }

    fun markAllInboxRead() {
        val current = _inboxItems.value
        _inboxItems.value = current.map { it.copy(isNew = false) }
    }

    fun submitCommentReply(postId: String, parentFullname: String, text: String): Comment {
        return Comment(
            id = "c_${System.currentTimeMillis()}",
            fullname = "t1_${System.currentTimeMillis()}",
            author = "redditor",
            body = text,
            score = 1,
            createdUtc = System.currentTimeMillis() / 1000,
            depth = 0,
            isOp = false,
            parentId = parentFullname
        )
    }

    fun submitNewPost(
        subreddit: String,
        title: String,
        kind: PostType,
        text: String = "",
        url: String = "",
        flair: String? = null
    ): Post {
        val newPost = Post(
            id = "user_post_${System.currentTimeMillis()}",
            fullname = "t3_user_${System.currentTimeMillis()}",
            title = title,
            subreddit = subreddit,
            author = "redditor",
            score = 1,
            numComments = 0,
            createdUtc = System.currentTimeMillis() / 1000,
            type = kind,
            isSelf = kind == PostType.SELF,
            selftext = text,
            url = url,
            linkFlairText = flair,
            likes = true
        )
        return newPost
    }

    private fun applyPostOverrides(post: Post): Post {
        val userVote = postVotes[post.id]
        val scoreDelta = postScoreDeltas[post.id] ?: 0
        return post.copy(
            likes = if (userVote != null) userVote else post.likes,
            score = (post.score + scoreDelta).coerceAtLeast(0)
        )
    }

    private fun applySubredditOverrides(sub: Subreddit): Subreddit {
        val key = sub.name.lowercase()
        val isSubbed = subscriptions[key] ?: sub.userIsSubscriber
        val isFav = favorites[key] ?: sub.userHasFavorited
        return sub.copy(
            userIsSubscriber = isSubbed,
            userHasFavorited = isFav
        )
    }
}
