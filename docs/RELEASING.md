# Pomodocus — Build, release et mises à jour OTA

## 1. Build Android local

```bash
flutter pub get
dart run build_runner build        # régénère app_database.g.dart si le schéma change
flutter analyze
flutter test --exclude-tags screenshots
flutter build apk --release        # → build/app/outputs/flutter-apk/app-release.apk
```

### Particularités de ce poste Windows

- **Avast intercepte le HTTPS** (certificat « Avast Web/Mail Shield Root »). Java ne connaît pas ce
  certificat, donc Gradle échoue avec `PKIX path building failed`. Solution sans toucher à la config
  globale : faire utiliser à Java le magasin de certificats Windows, pour la session en cours :
  ```bash
  # Git Bash
  export JAVA_TOOL_OPTIONS="-Djavax.net.ssl.trustStoreType=Windows-ROOT"
  # PowerShell
  $env:JAVA_TOOL_OPTIONS = "-Djavax.net.ssl.trustStoreType=Windows-ROOT"
  ```
  (Pour le rendre permanent, ajouter `systemProp.javax.net.ssl.trustStoreType=Windows-ROOT` dans
  `%USERPROFILE%\.gradle\gradle.properties`.)
- Le projet est sur `E:` et le cache pub sur `C:` : `kotlin.incremental=false` est défini dans
  `android/gradle.properties` pour éviter l'erreur « Could not close incremental caches ».
- `compileSdk = 37` (requis par `flutter_local_notifications` 23 et `androidx.core` 1.19) avec AGP 9.2.1
  et Gradle 9.4.1.

### Signature de production

`android/app/build.gradle.kts` lit `android/key.properties` s'il existe ; sinon la release est signée
avec la clé de debug (avertissement dans le log Gradle).

1. Créer la clé (une seule fois, à conserver précieusement) :
   ```powershell
   mkdir C:\Users\FABO\keys
   & "C:\Program Files\Java\jdk-22\bin\keytool.exe" -genkeypair -v `
     -keystore C:\Users\FABO\keys\pomodocus-upload.jks `
     -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Copier `android/key.properties.example` en `android/key.properties` et renseigner les mots de passe.
3. Construire : `flutter build appbundle --release` (Play Store) ou `flutter build apk --release`.
4. Vérifier : `& "C:\Program Files\Java\jdk-22\bin\keytool.exe" -printcert -jarfile build\app\outputs\flutter-apk\app-release.apk`

Sauvegarder le `.jks` et les mots de passe hors du PC (gestionnaire de mots de passe). Avec Play App
Signing, cette clé est la « clé d'importation » : Google peut la réinitialiser si elle est perdue,
mais pas sans démarche. Ne jamais committer le keystore ni `key.properties`.

## 2. Shorebird (Code Push)

Le package `shorebird_code_push` est intégré (`lib/core/services/update_service.dart`) et l'écran
**Paramètres → À propos et mises à jour** affiche la version, le numéro de patch et l'état des mises à
jour. En build `flutter` classique (ou debug), le service répond « indisponible » sans rien bloquer.

Le CLI Shorebird **n'est pas installé** et nécessite un compte : ces étapes sont à faire par le
développeur.

```powershell
# 1. Installer le CLI (PowerShell) — voir https://docs.shorebird.dev/getting-started/
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
iwr -UseBasicParsing 'https://raw.githubusercontent.com/shorebirdtech/install/main/install.ps1' | iex

# 2. Se connecter et initialiser le projet (crée shorebird.yaml avec l'app_id — à committer)
shorebird login
shorebird init

# 3. Vérifier la compatibilité avec la version de Flutter installée
shorebird doctor

# 4. Release Android (c'est CETTE build qu'il faut installer/publier pour recevoir des patchs)
shorebird release android                 # AAB pour le Play Store
shorebird release android --artifact apk  # APK pour test direct

# 5. Après une correction Dart uniquement
shorebird patch android
```

Validation recommandée : installer l'APK issue de `shorebird release`, publier un petit patch
(ex. changer une phrase de l'écran Focus), lancer l'app, attendre le téléchargement, relancer :
le numéro de patch apparaît dans « À propos ».

### Ce qu'un patch peut / ne peut pas changer

| Patch OTA possible | Nouvelle release obligatoire |
|---|---|
| Code Dart : écrans, logique, styles, corrections | Code natif Android/iOS, nouveaux plugins natifs |
| Dépendances purement Dart | Permissions, `AndroidManifest.xml`, Gradle |
| | Assets : polices, sons, animations Lottie, icônes |
| | Changement de version de Flutter |

Ne jamais utiliser l'OTA pour contourner les règles des stores.

## 3. Configuration distante / feature flags

`RemoteConfigService` (`lib/core/config/remote_config_service.dart`) est indépendant du fournisseur :
valeurs par défaut intégrées, cache local de la dernière configuration valide, délai d'attente de 5 s,
validation des champs. Le MVP utilise `NoRemoteConfigSource` (aucun serveur). Pour brancher un
backend, implémenter `RemoteConfigSource.fetch()` et l'injecter dans `remoteConfigServiceProvider`.

Les modules de navigation sont déclarés dans `lib/app/router/app_modules.dart` ; un module avec un
`flag` n'apparaît que si le flag est vrai. Les flags ne sont pas un mécanisme de sécurité.

## 4. iOS avec Codemagic

### Build de test non signée (`ios-unsigned`)

Aucun prérequis Apple côté Codemagic. Lancer le workflow, télécharger l'artefact
`pomodocus-<version>-ios-unsigned.ipa`, puis l'installer avec **Sideloadly** (Windows) : brancher
l'iPhone en USB, glisser l'IPA, se connecter avec son Apple ID (un compte gratuit suffit). Sur
l'iPhone : Réglages → Général → VPN et gestion de l'appareil → faire confiance au profil, et activer
le Mode développeur (Réglages → Confidentialité et sécurité). Avec un Apple ID gratuit, l'app
expire au bout de 7 jours : il suffit de la réinstaller.

### Build signée TestFlight (`ios-release`)

La build signée iOS se fait sur Codemagic (`codemagic.yaml`, workflow `ios-release`) : analyse,
tests, build IPA signée, envoi des dSYM à Sentry, puis envoi sur TestFlight.

À configurer une seule fois :

1. **App Store Connect** : créer l'app avec le bundle id `com.fab2dev.pomodocus`, puis noter son
   « Identifiant Apple » (Informations générales) et le reporter dans `APP_STORE_APPLE_ID` du
   `codemagic.yaml`.
2. **Clé API** : App Store Connect → Utilisateurs et accès → Intégrations → clé avec le rôle
   *App Manager*. L'ajouter dans Codemagic (Team settings → Integrations → Developer Portal) sous le
   nom `Pomodocus ASC`, ou adapter `integrations.app_store_connect`.
3. **Certificat de distribution** : Team settings → codemagic.yaml settings → Code signing
   identities → générer ou importer un certificat *Apple Distribution*. Le profil App Store est
   ensuite récupéré ou créé automatiquement (`ios_signing`).
4. **Variables Sentry** : dans l'app Codemagic → Environment variables, créer le groupe `sentry`
   avec `SENTRY_DSN`, `SENTRY_ENVIRONMENT`, `SENTRY_TRACES_SAMPLE_RATE`, `SENTRY_ORG`,
   `SENTRY_PROJECT` et `SENTRY_AUTH_TOKEN` (cocher *Secret*).

Le numéro de build est calculé automatiquement (dernier build TestFlight + 1) ; la version vient du
`pubspec.yaml`. Les builds se lancent à la main, ou à chaque tag `v*` si le bloc `triggering` est
décommenté.

Pour une release Shorebird (patchs OTA sur iOS), remplacer l'étape « Build IPA » par
`shorebird release ios -- --dart-define-from-file=.env --build-number=$BUILD_NUMBER` après
`shorebird init` (voir la doc Codemagic × Shorebird ; jeton `SHOREBIRD_TOKEN` requis).

## 5. Sentry (suivi des bugs)

`sentry_flutter` est initialisé dans `lib/bootstrap.dart` à partir de valeurs passées à la
compilation (`lib/core/config/sentry_config.dart`). **Sans `SENTRY_DSN`, Sentry n'est pas démarré** :
le dev local et les tests fonctionnent sans configuration.

```bash
cp .env.example .env                 # puis renseigner SENTRY_DSN (ignoré par git)
flutter run --dart-define-from-file=.env
flutter build appbundle --release --dart-define-from-file=.env
shorebird release android -- --dart-define-from-file=.env   # et idem pour chaque patch
```

Envoi des symboles de débogage (traces lisibles pour les crashs natifs) après une build release :
copier `sentry.properties.example` en `sentry.properties` (ignoré par git), renseigner `org`,
`project` et `auth_token`, puis `dart run sentry_dart_plugin`. Le jeton d'API ne va **jamais** dans
`.env` : tout ce fichier est compilé dans l'app.

Aucune donnée personnelle n'est envoyée (`sendDefaultPii = false`). Les rapports contiennent le
fil de navigation (écrans visités).
