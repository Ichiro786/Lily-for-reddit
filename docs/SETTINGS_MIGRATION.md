# Settings migration inventory

Audited before changing presentation. All 32 existing controls have exactly one destination. Font size, slider, and preview remain one control; accent swatches stay searchable.

| Destination | Existing control | Existing preference/state owner |
|---|---|---|
| Appearance | Theme | themeMode |
| Appearance | AMOLED black | amoled |
| Appearance | Dynamic color | useDynamicColor |
| Appearance | Accent color | seedColor |
| Appearance | Font size and preview | textScale |
| Appearance | Bottom bar labels | navLabels |
| Feed | Default sort | defaultSort |
| Feed | Post display | postDisplay |
| Feed | Blur NSFW media | blurNsfw |
| Feed | Data-saver thumbnails | midResThumbnails |
| Feed | Hide read posts automatically | hideReadPosts; reads legacy autoHideReadForYou |
| Feed | Resume feeds where I left off | resumeFeeds |
| Feed | Manage For You subreddits | Existing manage_for_you route/store |
| Power user features | Swipe to vote | swipeActions |
| Power user features | Autoplay videos | autoplayMedia |
| Power user features | API usage | rateLimitProvider; read only |
| Power user features | Inbox notifications | notifyInbox; notification permission/poller |
| History & data | History | Existing history route/store |
| History & data | Track history | trackHistory |
| History & data | Offline cache | offlineCache |
| History & data | Cache subscriptions | subsCacheEnabled |
| History & data | Subscriptions cache time | subsCacheMinutes |
| History & data | Clear cache | RedditClient.clearCache |
| Data & backup | Export backup | BackupService.exportBackup |
| Data & backup | Restore backup | BackupService.importBackup; existing confirmation |
| Account | Login method | authModeProvider; read only |
| Account | Reddit API credentials | Existing credential re-entry flow |
| Account | Clear all data | Existing confirmation/auth logout/secure store clear |
| About | Check for updates | checkUpdates |
| About | Check now | UpdateChecker |
| About | Reddit link/default-app information | Existing informational control |
| About | Content & conduct policy | Existing policy route |

Preference controls continue using SettingsController and the same SharedPreferences keys. No preference migration or reset is needed. Existing values/defaults, backups, cache behavior, update checks, and destructive confirmations remain unchanged.

Account switching/add/remove remains available from the profile and is also reachable through Account → Manage accounts. Custom feeds remain reachable from the profile toolbar. The signed-in Settings profile entry opens the full profile.

Search uses a typed catalog of stable IDs, categories, titles, and keywords; category pages render the existing controls without a second preference implementation. Selecting a result scrolls to and outlines that control.
