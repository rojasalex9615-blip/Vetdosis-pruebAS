import 'package:google_sign_in/google_sign_in.dart';

const driveWebClientId = String.fromEnvironment(
  'GOOGLE_DRIVE_WEB_CLIENT_ID',
  defaultValue:
      '137670819-4skobkrkoqpk3leupqmns4aav5aahkpb.apps.googleusercontent.com',
);

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
