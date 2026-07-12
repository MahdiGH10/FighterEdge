# Connecting Firebase (production auth)

The app currently runs on `LocalAuthRepository` — a fully working on-device
backend. Because every screen depends only on the `AuthRepository` interface
(`lib/auth/auth_repository.dart`), going live with Firebase is a **one-file
swap in `main.dart`** — no UI changes.

## 1. Create the Firebase project

1. Go to <https://console.firebase.google.com> and create a project.
2. In **Authentication → Sign-in method**, enable:
   - Email/Password (and, under it, **Email link** for passwordless)
   - Google
   - Apple (needs an Apple Developer account for iOS)
3. (Optional) Create a **Cloud Firestore** database — we store each user's
   `plan` there so entitlements sync across devices.

## 2. Wire the app to your project

Install the CLIs and run configure from the project root:

```bash
dart pub global activate flutterfire_cli
flutterfire configure       # pick your project + platforms (web, android, ios)
```

This generates `lib/firebase_options.dart`. Then add the packages:

```bash
flutter pub add firebase_core firebase_auth cloud_firestore google_sign_in sign_in_with_apple
```

## 3. Add the Firebase implementation

Create `lib/auth/firebase_auth_repository.dart` with the code below. It
implements the same `AuthRepository` interface, mapping `User` ⇄ `AppUser` and
reading/writing the plan in Firestore.

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../billing/subscription.dart';
import '../models/app_user.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AppUser? _cached;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  Future<AppUser> _hydrate(User user) async {
    final snap = await _doc(user.uid).get();
    final planName = snap.data()?['plan'] as String?;
    final plan = Plan.values.firstWhere((p) => p.name == planName,
        orElse: () => Plan.free);
    final appUser = AppUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? (user.email?.split('@').first ?? ''),
      emailVerified: user.emailVerified,
      plan: plan,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
    );
    if (!snap.exists) {
      await _doc(user.uid).set(appUser.toJson());
    }
    _cached = appUser;
    return appUser;
  }

  @override
  Stream<AppUser?> authStateChanges() =>
      _auth.authStateChanges().asyncMap((u) async {
        if (u == null) {
          _cached = null;
          return null;
        }
        return _hydrate(u);
      });

  @override
  AppUser? get currentUser => _cached;

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      await cred.user!.updateDisplayName(displayName.trim());
      await cred.user!.sendEmailVerification();
      return _hydrate(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code, e.message ?? 'Sign-up failed.');
    }
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      return _hydrate(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code, e.message ?? 'Sign-in failed.');
    }
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  @override
  Future<AppUser> signInWithGoogle() async {
    final gUser = await GoogleSignIn().signIn();
    if (gUser == null) throw const AuthException('cancelled', 'Sign-in cancelled.');
    final gAuth = await gUser.authentication;
    final cred = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken, idToken: gAuth.idToken);
    final res = await _auth.signInWithCredential(cred);
    return _hydrate(res.user!);
  }

  @override
  Future<AppUser> signInWithApple() async {
    final apple = await SignInWithApple.getAppleIDCredential(scopes: [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ]);
    final cred = OAuthProvider('apple.com').credential(
        idToken: apple.identityToken, accessToken: apple.authorizationCode);
    final res = await _auth.signInWithCredential(cred);
    return _hydrate(res.user!);
  }

  // Passwordless email link. (Requires configuring an ActionCodeSettings URL.)
  @override
  Future<void> sendMagicLink(String email) => _auth.sendSignInLinkToEmail(
        email: email.trim(),
        actionCodeSettings: ActionCodeSettings(
          url: 'https://YOUR_APP.page.link/auth',
          handleCodeInApp: true,
          androidPackageName: 'com.fighteredge.fighter_edge',
          iOSBundleId: 'com.fighteredge.fighterEdge',
        ),
      );

  @override
  Future<AppUser> verifyMagicCode({
    required String email,
    required String code, // the link the user tapped
  }) async {
    final cred = await _auth.signInWithEmailLink(email: email, emailLink: code);
    return _hydrate(cred.user!);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<AppUser> updatePlan(AppUser user) async {
    await _doc(user.id).set({'plan': user.plan.name}, SetOptions(merge: true));
    _cached = user;
    return user;
  }
}
```

> Note: Firebase's magic-link is a tapped **link**, not a 6-digit code, so the
> `MagicLinkScreen` code-entry step is only used by the local backend. With
> Firebase you'd handle the incoming link via deep-linking instead.

## 4. Flip the switch in `main.dart`

```dart
// import 'auth/firebase_auth_repository.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';

await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
final authRepo = FirebaseAuthRepository();
// (delete the LocalAuthRepository lines)
```

Everything else — screens, `AuthController`, `ProGate`, the paywall — works
unchanged, because they only know about `AuthRepository`.

## 5. Firestore security rules (REQUIRED before real users)

A new Firestore database is reachable over the API until you lock it down (the
Firestore equivalent of "RLS off"). Set these rules in **Firestore → Rules** so
each user can only touch their own document **and cannot change their own
`plan`** — otherwise anyone can self-upgrade to Pro from the client:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read: if request.auth != null && request.auth.uid == uid;

      // Users may create their profile on the free plan only.
      allow create: if request.auth != null
                    && request.auth.uid == uid
                    && request.resource.data.plan == 'free';

      // Users may update their profile but NOT the plan field.
      allow update: if request.auth != null
                    && request.auth.uid == uid
                    && request.resource.data.plan == resource.data.plan;
    }
    // Everything else denied by default.
  }
}
```

With these rules on, the client's `updatePlan()` can no longer change `plan`
(by design). Plan changes must come from a **trusted server** — see below.

## 6. Billing — entitlements must be server-authoritative

⚠️ Today `setPlan()` is called directly from the client (the paywall button),
so the plan is client-controlled. That is fine for the current no-payments demo
but is **not safe once money is involved** — never trust a client-supplied plan.

Before shipping paid Pro:

1. Integrate **RevenueCat** (`purchases_flutter`) or **Stripe**.
2. Verify the purchase **server-side**: a Cloud Function receives the
   provider's webhook, **verifies its signature**, and only then writes
   `users/{uid}.plan = 'pro'` via the Admin SDK (which bypasses the rules above).
3. The client keeps *reading* `plan` and gating with `Entitlements` for UX, but
   the source of truth is the server. Remove the client-side `updatePlan` write
   path (or leave it only for local/dev builds).

The entitlement model (`lib/billing/subscription.dart`) stays the same — only
*who is allowed to set the plan* changes.
```
