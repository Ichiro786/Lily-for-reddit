package com.example.lilyforreddit.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface SavedPostDao {
    @Query("SELECT * FROM saved_posts ORDER BY savedAt DESC")
    fun getAllSavedPosts(): Flow<List<SavedPostEntity>>

    @Query("SELECT EXISTS(SELECT 1 FROM saved_posts WHERE id = :id)")
    fun isPostSaved(id: String): Flow<Boolean>

    @Query("SELECT EXISTS(SELECT 1 FROM saved_posts WHERE id = :id)")
    suspend fun isPostSavedSync(id: String): Boolean

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun savePost(post: SavedPostEntity)

    @Query("DELETE FROM saved_posts WHERE id = :id")
    suspend fun unsavePost(id: String)
}

@Dao
interface HistoryDao {
    @Query("SELECT * FROM history_posts ORDER BY viewedAt DESC LIMIT 100")
    fun getHistory(): Flow<List<HistoryPostEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun recordHistory(item: HistoryPostEntity)

    @Query("DELETE FROM history_posts WHERE id = :id")
    suspend fun deleteHistory(id: String)

    @Query("DELETE FROM history_posts")
    suspend fun clearHistory()
}

@Dao
interface AffinityDao {
    @Query("SELECT * FROM subreddit_affinity ORDER BY score DESC")
    fun getAllAffinities(): Flow<List<SubredditAffinityEntity>>

    @Query("SELECT * FROM subreddit_affinity ORDER BY score DESC")
    suspend fun getAllAffinitiesSync(): List<SubredditAffinityEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun updateAffinity(affinity: SubredditAffinityEntity)

    @Query("DELETE FROM subreddit_affinity WHERE subreddit = :subreddit")
    suspend fun deleteAffinity(subreddit: String)

    @Query("DELETE FROM subreddit_affinity")
    suspend fun resetAllAffinities()
}
