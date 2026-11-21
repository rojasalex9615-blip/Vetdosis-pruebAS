import 'package:flutter_test/flutter_test.dart';
import 'package:vetdosis_pro/modules/backup/data/drive_backup_authorization.dart';

void main() {
  test('Un define vacío cae al ID público, no queda vacío', () {
    // CI passes --dart-define=GOOGLE_DRIVE_WEB_CLIENT_ID= when the variable is
    // unset, and an empty define overrides defaultValue. This is the exact
    // regression: the resolved value must never be empty.
    expect(driveWebClientId, isNotEmpty);
    expect(driveWebClientId, endsWith('.apps.googleusercontent.com'));
  });

  test('Un define real se respeta', () {
    if (declaredDriveWebClientId.isEmpty) {
      expect(driveWebClientId, driveDefaultWebClientId);
    } else {
      expect(driveWebClientId, declaredDriveWebClientId);
    }
  });
}
