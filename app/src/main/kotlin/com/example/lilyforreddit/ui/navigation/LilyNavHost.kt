package com.example.lilyforreddit.ui.navigation

import androidx.compose.animation.*
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.toRoute
import com.example.lilyforreddit.LilyApp
import com.example.lilyforreddit.ui.components.M3EFloatingNavBar
import com.example.lilyforreddit.ui.explore.ExploreScreen
import com.example.lilyforreddit.ui.feed.FeedScreen
import com.example.lilyforreddit.ui.foryou.ManageForYouScreen
import com.example.lilyforreddit.ui.inbox.InboxScreen
import com.example.lilyforreddit.ui.multireddit.MultiredditScreen
import com.example.lilyforreddit.ui.post.PostDetailScreen
import com.example.lilyforreddit.ui.search.SearchScreen
import com.example.lilyforreddit.ui.settings.SettingsScreen
import com.example.lilyforreddit.ui.submit.SubmitPostScreen
import com.example.lilyforreddit.ui.subreddit.SubredditScreen
import com.example.lilyforreddit.ui.user.UserScreen

@Composable
fun LilyNavHost(
    modifier: Modifier = Modifier,
    navController: NavHostController = rememberNavController()
) {
    val app = LilyApp.instance
    val inboxItems by app.redditRepository.inboxItems.collectAsStateWithLifecycle()
    val unreadCount = remember(inboxItems) { inboxItems.count { it.isNew } }
    val settings by app.settingsRepository.settings.collectAsStateWithLifecycle()

    var selectedTab by remember { mutableIntStateOf(0) }

    NavHost(
        navController = navController,
        startDestination = Screen.Home,
        modifier = modifier.fillMaxSize(),
        enterTransition = { fadeIn() + slideIntoContainer(AnimatedContentTransitionScope.SlideDirection.Start) },
        exitTransition = { fadeOut() + slideOutOfContainer(AnimatedContentTransitionScope.SlideDirection.Start) },
        popEnterTransition = { fadeIn() + slideIntoContainer(AnimatedContentTransitionScope.SlideDirection.End) },
        popExitTransition = { fadeOut() + slideOutOfContainer(AnimatedContentTransitionScope.SlideDirection.End) }
    ) {
        composable<Screen.Home> {
            Box(modifier = Modifier.fillMaxSize()) {
                // Tab content
                when (selectedTab) {
                    0 -> FeedScreen(
                        onPostClick = { sub, id -> navController.navigate(Screen.PostDetail(sub, id)) },
                        onSubredditClick = { sub -> navController.navigate(Screen.SubredditDetail(sub)) },
                        onUserClick = { user -> navController.navigate(Screen.UserProfile(user)) },
                        onSearchClick = { navController.navigate(Screen.Search()) },
                        onSubmitPostClick = { navController.navigate(Screen.SubmitPost()) },
                        onManageForYouClick = { navController.navigate(Screen.ManageForYou) }
                    )
                    1 -> ExploreScreen(
                        onSubredditClick = { sub -> navController.navigate(Screen.SubredditDetail(sub)) },
                        onMultiredditClick = { user, multi -> navController.navigate(Screen.MultiredditFeed(user, multi)) },
                        onSearchClick = { query -> navController.navigate(Screen.Search(query)) }
                    )
                    2 -> InboxScreen(
                        onUserClick = { user -> navController.navigate(Screen.UserProfile(user)) }
                    )
                    3 -> UserScreen(
                        username = settings.currentUsername,
                        onPostClick = { sub, id -> navController.navigate(Screen.PostDetail(sub, id)) },
                        onSettingsClick = { navController.navigate(Screen.Settings) },
                        onSubredditClick = { sub -> navController.navigate(Screen.SubredditDetail(sub)) }
                    )
                }

                // Floating Navigation Pill
                M3EFloatingNavBar(
                    currentIndex = selectedTab,
                    unreadCount = unreadCount,
                    modifier = Modifier.align(Alignment.BottomCenter),
                    onTabSelected = { selectedTab = it }
                )
            }
        }

        composable<Screen.PostDetail> { backStackEntry ->
            val route = backStackEntry.toRoute<Screen.PostDetail>()
            PostDetailScreen(
                subreddit = route.subreddit,
                postId = route.postId,
                onBack = { navController.popBackStack() },
                onSubredditClick = { sub -> navController.navigate(Screen.SubredditDetail(sub)) },
                onUserClick = { user -> navController.navigate(Screen.UserProfile(user)) }
            )
        }

        composable<Screen.SubredditDetail> { backStackEntry ->
            val route = backStackEntry.toRoute<Screen.SubredditDetail>()
            SubredditScreen(
                subredditName = route.name,
                onBack = { navController.popBackStack() },
                onPostClick = { sub, id -> navController.navigate(Screen.PostDetail(sub, id)) },
                onUserClick = { user -> navController.navigate(Screen.UserProfile(user)) },
                onSubmitPostClick = { sub -> navController.navigate(Screen.SubmitPost(sub)) }
            )
        }

        composable<Screen.UserProfile> { backStackEntry ->
            val route = backStackEntry.toRoute<Screen.UserProfile>()
            UserScreen(
                username = route.username,
                onPostClick = { sub, id -> navController.navigate(Screen.PostDetail(sub, id)) },
                onSettingsClick = { navController.navigate(Screen.Settings) },
                onSubredditClick = { sub -> navController.navigate(Screen.SubredditDetail(sub)) }
            )
        }

        composable<Screen.Search> { backStackEntry ->
            val route = backStackEntry.toRoute<Screen.Search>()
            SearchScreen(
                initialQuery = route.initialQuery,
                initialSubreddit = route.initialSubreddit,
                onBack = { navController.popBackStack() },
                onPostClick = { sub, id -> navController.navigate(Screen.PostDetail(sub, id)) },
                onSubredditClick = { sub -> navController.navigate(Screen.SubredditDetail(sub)) },
                onUserClick = { user -> navController.navigate(Screen.UserProfile(user)) }
            )
        }

        composable<Screen.SubmitPost> { backStackEntry ->
            val route = backStackEntry.toRoute<Screen.SubmitPost>()
            SubmitPostScreen(
                initialSubreddit = route.initialSubreddit,
                onBack = { navController.popBackStack() },
                onPostCreated = { sub, id ->
                    navController.popBackStack()
                    navController.navigate(Screen.PostDetail(sub, id))
                }
            )
        }

        composable<Screen.Settings> {
            SettingsScreen(
                onBack = { navController.popBackStack() },
                onManageForYouClick = { navController.navigate(Screen.ManageForYou) }
            )
        }

        composable<Screen.ManageForYou> {
            ManageForYouScreen(
                onBack = { navController.popBackStack() }
            )
        }

        composable<Screen.MultiredditFeed> { backStackEntry ->
            val route = backStackEntry.toRoute<Screen.MultiredditFeed>()
            MultiredditScreen(
                username = route.username,
                multiredditName = route.name,
                onBack = { navController.popBackStack() },
                onPostClick = { sub, id -> navController.navigate(Screen.PostDetail(sub, id)) },
                onSubredditClick = { sub -> navController.navigate(Screen.SubredditDetail(sub)) },
                onUserClick = { user -> navController.navigate(Screen.UserProfile(user)) }
            )
        }
    }
}
