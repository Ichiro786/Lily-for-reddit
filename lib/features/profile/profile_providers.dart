import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../models/reddit_user.dart';

final userAboutProvider = FutureProvider.autoDispose.family<RedditUser, String>(
  (ref, name) => ref.watch(redditRepositoryProvider).getUserAbout(name),
);
