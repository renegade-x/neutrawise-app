import 'package:flutter_test/flutter_test.dart';
import 'package:neutrawise/services/app_logger.dart';

void main() {
  tearDown(() => AppLogger.reporter = null);

  test('forwards handled errors to the reporter', () {
    String? seenWhere;
    Object? seenError;
    AppLogger.reporter = (where, error, stack) {
      seenWhere = where;
      seenError = error;
    };

    AppLogger.error('quiz_repository', StateError('boom'));

    expect(seenWhere, 'quiz_repository');
    expect(seenError, isA<StateError>());
  });

  test('a failing reporter never throws', () {
    AppLogger.reporter = (where, error, stack) => throw Exception('reporter down');
    expect(() => AppLogger.error('x', 'y'), returnsNormally);
  });

  test('works without a reporter', () {
    expect(() => AppLogger.error('x', 'y'), returnsNormally);
  });
}
