import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luli_for_reddit/core/storage/secure_store.dart';
import 'package:luli_for_reddit/features/auth/auth_controller.dart';
import 'package:luli_for_reddit/features/media/giphy_picker.dart';

class _Store extends SecureStore {
  @override
  Future<String?> get giphyKey async => 'test';
}

void main() {
  testWidgets(
    'Final audit: GIF sheet cancels stale queries and can close during network work',
    (tester) async {
      final requests = <(RequestOptions, RequestInterceptorHandler)>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(onRequest: (o, h) => requests.add((o, h))),
        );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStoreProvider.overrideWithValue(_Store()),
            giphyDioFactoryProvider.overrideWithValue(() => dio),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => unawaited(showGiphyPicker(context, ref)),
                  child: const Text('Open GIF'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open GIF'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(requests, hasLength(1));
      await tester.enterText(find.byType(TextField), 'new');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));
      expect(requests, hasLength(2));
      requests.last.$2.resolve(
        Response(
          requestOptions: requests.last.$1,
          statusCode: 200,
          data: {'data': []},
        ),
      );
      await tester.pump();
      requests.first.$2.resolve(
        Response(
          requestOptions: requests.first.$1,
          statusCode: 200,
          data: {'data': []},
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.enterText(find.byType(TextField), 'pending');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpWidget(const SizedBox());
      requests.last.$2.resolve(
        Response(
          requestOptions: requests.last.$1,
          statusCode: 200,
          data: {'data': []},
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
