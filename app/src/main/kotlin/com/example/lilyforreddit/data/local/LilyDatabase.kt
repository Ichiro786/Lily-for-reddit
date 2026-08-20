package com.example.lilyforreddit.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(
    entities = [
        SavedPostEntity::class,
        HistoryPostEntity::class,
        SubredditAffinityEntity::class
    ],
    version = 1,
    exportSchema = false
)
abstract class LilyDatabase : RoomDatabase() {
    abstract fun savedPostDao(): SavedPostDao
    abstract fun historyDao(): HistoryDao
    abstract fun affinityDao(): AffinityDao

    companion object {
        @Volatile
        private var INSTANCE: LilyDatabase? = null

        fun getDatabase(context: Context): LilyDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    LilyDatabase::class.java,
                    "lily_reddit.db"
                ).fallbackToDestructiveMigration().build()
                INSTANCE = instance
                instance
            }
        }
    }
}
