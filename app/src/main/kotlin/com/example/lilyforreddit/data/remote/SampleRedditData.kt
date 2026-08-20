package com.example.lilyforreddit.data.remote

import com.example.lilyforreddit.data.models.*

object SampleRedditData {

    val defaultSubreddits = listOf(
        Subreddit(
            name = "androiddev",
            displayName = "Android Developers",
            title = "Android Developers Community",
            publicDescription = "News, tutorials, and discussions for Android developers. Kotlin, Compose, Architecture Components and SDK updates.",
            subscribers = 245000,
            activeAccounts = 1250,
            iconImg = "https://picsum.photos/seed/androiddev/200/200",
            bannerImg = "https://picsum.photos/seed/androidbanner/1200/400",
            primaryColor = "#3DDC84",
            userHasFavorited = true,
            userIsSubscriber = true
        ),
        Subreddit(
            name = "kotlin",
            displayName = "Kotlin",
            title = "Kotlin Programming Language",
            publicDescription = "A modern programming language that makes developers happier. Android, Multiplatform, Server-side.",
            subscribers = 89000,
            activeAccounts = 480,
            iconImg = "https://picsum.photos/seed/kotlin/200/200",
            bannerImg = "https://picsum.photos/seed/kotlinbanner/1200/400",
            primaryColor = "#7F52FF",
            userHasFavorited = true,
            userIsSubscriber = true
        ),
        Subreddit(
            name = "technology",
            displayName = "Technology",
            title = "Technology News and Discussions",
            publicDescription = "A community dedicated to the news and discussions about the creation and use of technology and its surrounding issues.",
            subscribers = 15200000,
            activeAccounts = 8900,
            iconImg = "https://picsum.photos/seed/tech/200/200",
            bannerImg = "https://picsum.photos/seed/techbanner/1200/400",
            primaryColor = "#0079D3",
            userHasFavorited = false,
            userIsSubscriber = true
        ),
        Subreddit(
            name = "gaming",
            displayName = "Gaming",
            title = "All things gaming",
            publicDescription = "A subreddit for (almost) anything related to games - video games, board games, classic games, and tech.",
            subscribers = 38000000,
            activeAccounts = 22000,
            iconImg = "https://picsum.photos/seed/gaming/200/200",
            bannerImg = "https://picsum.photos/seed/gamingbanner/1200/400",
            primaryColor = "#FF4500",
            userHasFavorited = false,
            userIsSubscriber = true
        ),
        Subreddit(
            name = "science",
            displayName = "Science",
            title = "Major scientific breakthroughs and discussions",
            publicDescription = "This community is a place to share and discuss new scientific research. Peer-reviewed articles and AMA sessions.",
            subscribers = 31000000,
            activeAccounts = 14500,
            iconImg = "https://picsum.photos/seed/science/200/200",
            bannerImg = "https://picsum.photos/seed/sciencebanner/1200/400",
            primaryColor = "#00A699",
            userHasFavorited = false,
            userIsSubscriber = true
        ),
        Subreddit(
            name = "aww",
            displayName = "Aww",
            title = "Things that make you go AWW!",
            publicDescription = "A subreddit for cute and cuddly pictures, videos, and stories of animals and heartwarming moments.",
            subscribers = 34500000,
            activeAccounts = 18000,
            iconImg = "https://picsum.photos/seed/aww/200/200",
            bannerImg = "https://picsum.photos/seed/awwbanner/1200/400",
            primaryColor = "#FFB000",
            userHasFavorited = true,
            userIsSubscriber = true
        )
    )

    val defaultPosts = listOf(
        Post(
            id = "p1",
            fullname = "t3_p1",
            title = "Announcing Material 3 Expressive and Jetpack Compose 1.8 Highlights!",
            subreddit = "androiddev",
            author = "romain_guy",
            score = 1420,
            numComments = 184,
            upvoteRatio = 0.98,
            createdUtc = (System.currentTimeMillis() - 3600000 * 2) / 1000,
            permalink = "/r/androiddev/comments/p1/announcing_m3_expressive",
            url = "https://developer.android.com/jetpack/compose",
            domain = "developer.android.com",
            type = PostType.IMAGE,
            isSelf = false,
            selftext = "We are thrilled to unveil new fluid spring animations, adaptive canonical layouts, and refined Material 3 Expressive motion tokens for Compose.\n\nKey features in this release:\n- Upgraded performance pipeline\n- Enhanced LazyLayout prefetching\n- Predictive back gestures for all scaffold components\n- New expressive floating action bars and bottom navigation pills",
            linkFlairText = "Official",
            previewUrl = "https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=800&auto=format&fit=crop&q=80",
            previewWidth = 800,
            previewHeight = 450,
            stickied = true,
            feedReason = "★ Favourite · r/androiddev"
        ),
        Post(
            id = "p2",
            fullname = "t3_p2",
            title = "Kotlin 2.1 Multiplatform: Full Swift Export and Faster K2 Compilation Benchmark Analysis",
            subreddit = "kotlin",
            author = "jetbrains_team",
            score = 980,
            numComments = 92,
            upvoteRatio = 0.96,
            createdUtc = (System.currentTimeMillis() - 3600000 * 5) / 1000,
            permalink = "/r/kotlin/comments/p2/kotlin_2_1_multiplatform",
            url = "https://kotlinlang.org",
            domain = "kotlinlang.org",
            type = PostType.SELF,
            isSelf = true,
            selftext = "With Kotlin 2.1, the K2 compiler has reached widespread stability across all target platforms.\n\nHighlights:\n1. Direct Swift-Kotlin interop export without Objective-C wrappers\n2. Compilation speedups averaging 25-40% on large multi-module projects\n3. Improved memory footprints in daemon processes\n\nWhat are your experiences migrating existing codebases?",
            linkFlairText = "Discussion",
            feedReason = "★ Favourite · r/kotlin"
        ),
        Post(
            id = "p3",
            fullname = "t3_p3",
            title = "A collection of high-altitude aurora borealis captured over northern Norway last night",
            subreddit = "science",
            author = "astronomy_geek",
            score = 4250,
            numComments = 310,
            upvoteRatio = 0.99,
            createdUtc = (System.currentTimeMillis() - 3600000 * 7) / 1000,
            permalink = "/r/science/comments/p3/aurora_borealis_norway",
            url = "https://images.unsplash.com/photo-1531366936337-7c912a4589a7?w=1200&auto=format&fit=crop&q=80",
            domain = "i.redd.it",
            type = PostType.GALLERY,
            isSelf = false,
            linkFlairText = "Astronomy",
            previewUrl = "https://images.unsplash.com/photo-1531366936337-7c912a4589a7?w=800&auto=format&fit=crop&q=80",
            gallery = listOf(
                GalleryItem(url = "https://images.unsplash.com/photo-1531366936337-7c912a4589a7?w=1000&auto=format&fit=crop&q=80", caption = "Tromsø fjord reflection"),
                GalleryItem(url = "https://images.unsplash.com/photo-1517411032315-54ef2cb783bb?w=1000&auto=format&fit=crop&q=80", caption = "Green ribbon above the mountain peaks"),
                GalleryItem(url = "https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=1000&auto=format&fit=crop&q=80", caption = "Deep violet coronal burst")
            ),
            feedReason = "🔥 Trending on Reddit"
        ),
        Post(
            id = "p4",
            fullname = "t3_p4",
            title = "Meet Mochi, the golden retriever who insists on carrying his mini backpack on every morning walk",
            subreddit = "aww",
            author = "doggo_enthusiast",
            score = 8320,
            numComments = 455,
            upvoteRatio = 0.99,
            createdUtc = (System.currentTimeMillis() - 3600000 * 10) / 1000,
            permalink = "/r/aww/comments/p4/meet_mochi",
            url = "https://images.unsplash.com/photo-1552053831-71594a27632d?w=1200&auto=format&fit=crop&q=80",
            domain = "i.redd.it",
            type = PostType.IMAGE,
            isSelf = false,
            linkFlairText = "Cute Animals",
            previewUrl = "https://images.unsplash.com/photo-1552053831-71594a27632d?w=800&auto=format&fit=crop&q=80",
            feedReason = "Because you engage with r/aww"
        ),
        Post(
            id = "p5",
            fullname = "t3_p5",
            title = "Next-generation solid-state battery tech reaches 1,200 km range milestone in real-world EV tests",
            subreddit = "technology",
            author = "future_tech_pulse",
            score = 3190,
            numComments = 612,
            upvoteRatio = 0.94,
            createdUtc = (System.currentTimeMillis() - 3600000 * 14) / 1000,
            permalink = "/r/technology/comments/p5/solid_state_battery_milestone",
            url = "https://arstechnica.com",
            domain = "arstechnica.com",
            type = PostType.LINK,
            isSelf = false,
            selftext = "Researchers have successfully demonstrated ambient-temperature cycling with zero dendrite formation over 1,500 continuous rapid-charge cycles.",
            linkFlairText = "Energy",
            previewUrl = "https://images.unsplash.com/photo-1558441719-8b489c634a10?w=800&auto=format&fit=crop&q=80",
            feedReason = "Discover · r/technology"
        ),
        Post(
            id = "p6",
            fullname = "t3_p6",
            title = "Unreal Engine 5.5 open-world procedural landscape rendering demo running at 4K 120FPS",
            subreddit = "gaming",
            author = "pixel_warrior",
            score = 2780,
            numComments = 380,
            upvoteRatio = 0.95,
            createdUtc = (System.currentTimeMillis() - 3600000 * 18) / 1000,
            permalink = "/r/gaming/comments/p6/ue5_landscape_rendering",
            url = "https://images.unsplash.com/photo-1542751371-adc38448a05e?w=1200&auto=format&fit=crop&q=80",
            domain = "v.redd.it",
            type = PostType.VIDEO,
            isSelf = false,
            linkFlairText = "Game Dev",
            previewUrl = "https://images.unsplash.com/photo-1542751371-adc38448a05e?w=800&auto=format&fit=crop&q=80",
            fallbackVideoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            feedReason = "From r/gaming"
        )
    )

    fun getSampleComments(postId: String): List<Comment> {
        return listOf(
            Comment(
                id = "c1",
                fullname = "t1_c1",
                author = "compose_fanatic",
                body = "The spring physics update feels incredibly smooth! We were able to remove custom physics interpolation hacks in our custom navigation pills.",
                score = 340,
                createdUtc = (System.currentTimeMillis() - 3600000) / 1000,
                depth = 0,
                replies = listOf(
                    Comment(
                        id = "c1_1",
                        fullname = "t1_c1_1",
                        author = "romain_guy",
                        body = "Thanks! The team focused a lot on making sure low-end devices maintain 120Hz frame pacing even during continuous gesture flings.",
                        score = 210,
                        createdUtc = (System.currentTimeMillis() - 1800000) / 1000,
                        depth = 1,
                        isOp = true,
                        distinguished = "moderator",
                        replies = listOf(
                            Comment(
                                id = "c1_1_1",
                                fullname = "t1_c1_1_1",
                                author = "kotlin_coder_42",
                                body = "Does this integrate seamlessly with SharedElementTransitions across NavHost destinations?",
                                score = 45,
                                createdUtc = (System.currentTimeMillis() - 900000) / 1000,
                                depth = 2
                            )
                        )
                    )
                )
            ),
            Comment(
                id = "c2",
                fullname = "t1_c2",
                author = "mobile_architect",
                body = "Really loving the Material 3 Expressive guidelines. Lily for Reddit feels so fast and responsive with the floating pill navigation.",
                score = 185,
                createdUtc = (System.currentTimeMillis() - 3600000 * 2) / 1000,
                depth = 0,
                replies = listOf(
                    Comment(
                        id = "c2_1",
                        fullname = "t1_c2_1",
                        author = "ui_craftsman",
                        body = "Agreed, the edge-to-edge layout combined with translucent floating bars makes browsing Reddit a joy.",
                        score = 88,
                        createdUtc = (System.currentTimeMillis() - 3600000) / 1000,
                        depth = 1
                    )
                )
            ),
            Comment(
                id = "c3",
                fullname = "t1_c3",
                author = "dev_curious",
                body = "Great writeup! Bookmarked for testing in our next sprint.",
                score = 32,
                createdUtc = (System.currentTimeMillis() - 3600000 * 3) / 1000,
                depth = 0
            )
        )
    }

    val defaultInbox = listOf(
        InboxItem(
            id = "inb1",
            fullname = "t4_inb1",
            subject = "Welcome to Lily for Reddit!",
            body = "Welcome to Lily for Reddit — your fast, modern Material 3 Expressive client. You can customize feeds, switch themes, search communities, view galleries, and explore posts with on-device personalization.",
            author = "lily_bot",
            dest = "redditor",
            createdUtc = (System.currentTimeMillis() - 3600000 * 4) / 1000,
            isNew = true
        ),
        InboxItem(
            id = "inb2",
            fullname = "t1_inb2",
            subject = "Comment reply on 'Material 3 Expressive'",
            body = "Thanks for the feedback! We are constantly improving performance and adding more customization options.",
            author = "romain_guy",
            dest = "redditor",
            wasComment = true,
            subreddit = "androiddev",
            createdUtc = (System.currentTimeMillis() - 3600000 * 12) / 1000,
            isNew = false
        )
    )

    val defaultMultireddits = listOf(
        Multireddit(
            name = "dev_news",
            displayName = "Android & Kotlin Dev",
            description = "All the latest developments in Kotlin, Android Jetpack, and modern mobile engineering.",
            subreddits = listOf("androiddev", "kotlin"),
            path = "/user/me/m/dev_news"
        ),
        Multireddit(
            name = "science_tech",
            displayName = "Future & Tech",
            description = "Scientific discoveries, tech innovations, and breakthroughs.",
            subreddits = listOf("science", "technology"),
            path = "/user/me/m/science_tech"
        )
    )

    val currentUser = RedditUser(
        name = "redditor",
        totalKarma = 14850,
        linkKarma = 6200,
        commentKarma = 8650,
        iconImg = "https://picsum.photos/seed/currentuser/200/200",
        bannerImg = "https://picsum.photos/seed/userbanner/1200/400",
        createdUtc = (System.currentTimeMillis() - 3600000L * 24 * 365 * 3) / 1000,
        bio = "Android enthusiast & Material Design appreciator. Exploring Jetpack Compose and Kotlin Multiplatform."
    )
}
