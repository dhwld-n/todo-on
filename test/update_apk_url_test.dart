import 'package:flutter_test/flutter_test.dart';
import 'package:todo_on/services/update_service.dart';

Map<String, String> _asset(String name) => {
  'name': name,
  'browser_download_url': 'https://example.test/$name',
};

void main() {
  test('prefers the versioned apk, whatever the upload order', () {
    // A fixed TODOon.apk collides with the last update in the phone's
    // Downloads and the browser opens the old file - so never pick it when
    // the versioned one is there.
    for (final assets in [
      [_asset('TODOon.apk'), _asset('TODOon-1.6.49.apk')],
      [_asset('TODOon-1.6.49.apk'), _asset('TODOon.apk')],
    ]) {
      expect(
        apkUrlFrom([_asset('TODOon-Setup.exe'), ...assets], '1.6.49'),
        'https://example.test/TODOon-1.6.49.apk',
      );
    }
  });

  test('falls back to any apk, and null when there is none', () {
    expect(
      apkUrlFrom([_asset('TODOon.apk')], '1.6.49'),
      'https://example.test/TODOon.apk',
    );
    expect(
      apkUrlFrom([
        _asset('TODOon-Setup.exe'),
        _asset('TODOon-windows.zip'),
      ], '1.6.49'),
      isNull,
    );
  });
}
