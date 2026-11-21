import 'package:google_sign_in/google_sign_in.dart';

/// Public OAuth web client confirmed by the account owner. Not a secret.
const driveDefaultWebClientId =
    '137670819-4skobkrkoqpk3leupqmns4aav5aahkpb.apps.googleusercontent.com';

const _declaredDriveWebClientId = String.fromEnvironment(
  'GOOGLE_DRIVE_WEB_CLIENT_ID',
);

/// Raw value of the compile-time define, empty when unset.
const declaredDriveWebClientId = _declaredDriveWebClientId;

/// CI passes this define even when the variable is unset, and an empty define
/// overrides `defaultValue`. Fall back explicitly so the empty case cannot
/// reach `GoogleSignIn.initialize` as an empty `serverClientId`.
const driveWebClientId = declaredDriveWebClientId == ''
    ? driveDefaultWebClientId
    : declaredDriveWebClientId;

class DriveBackupAuthorization {
  static Future<void>? _initialization;
  static Future<GoogleSignInAccount> chooseAccount() async {
    final google = GoogleSignIn.instance;
    await (_initialization ??= google.initialize(
      serverClientId: driveWebClientId,
    ));
    // No clinic/account association or silent re-use across clinics.
    await google.signOut();
    return google.authenticate();
  }

  static Future<String> token(GoogleSignInAccount account) async =>
      (await account.authorizationClient.authorizeScopes([
        'https://www.googleapis.com/auth/drive.file',
      ])).accessToken;

  static Future<void> signOut() => GoogleSignIn.instance.signOut();
}
