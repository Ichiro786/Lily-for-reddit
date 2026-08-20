package com.example.lilyforreddit

import android.app.Application
import com.example.lilyforreddit.data.local.LilyDatabase
import com.example.lilyforreddit.data.remote.RedditApiClient
import com.example.lilyforreddit.data.repository.RedditRepository
import com.example.lilyforreddit.data.repository.SettingsRepository

class LilyApp : Application() {
    lateinit var database: LilyDatabase
        private set
    lateinit var redditApiClient: RedditApiClient
        private set
    lateinit var redditRepository: RedditRepository
        private set
    lateinit var settingsRepository: SettingsRepository
        private set

    override fun onCreate() {
        super.onCreate()
        instance = this
        database = LilyDatabase.getDatabase(this)
        redditApiClient = RedditApiClient()
        redditRepository = RedditRepository(redditApiClient, database)
        settingsRepository = SettingsRepository(this)
    }

    companion object {
        lateinit var instance: LilyApp
            private set
    }
}
