# Pomodocus

**FOCUS. WORK. REPEAT.** — *Focus on what matters.*

Application mobile Pomodoro (Flutter, Android & iOS) : minuteur fiable, cycles concentration / pauses,
notifications de fin de session, statistiques locales, thèmes clair et sombre.

## Démarrer

```bash
flutter pub get
flutter run                     # sur un téléphone Android branché ou un émulateur
flutter test --exclude-tags screenshots
```

APK prête à installer : `dist/pomodocus-1.0.0-android.apk`. Build, signature et OTA Shorebird :
[docs/RELEASING.md](docs/RELEASING.md).

## Mode plein écran (« mode vidéo »)

Paramètres → **Plein écran** :
- *Mode plein écran paysage* (activé par défaut) : ajoute le bouton ⛶ en haut de l'écran Focus.
- *Passer en plein écran au démarrage* : ouvre automatiquement ce mode quand une session démarre.

Dans ce mode, le téléphone passe à l'horizontale, les barres système sont masquées, l'écran reste
allumé et le décompte occupe tout l'écran (fond sombre). Toucher l'écran affiche les commandes
(pause, arrêt, passer la pause, quitter) ; elles disparaissent après 4 s pendant le décompte. Le
chiffre se décale très légèrement chaque minute pour éviter le marquage des écrans OLED. Le reste de
l'application est verrouillé en portrait.

Boutons en haut à droite du plein écran (également dans Paramètres → Plein écran) :
- **Horloge numérique / à volets** (flip clock) ; chacune a son tic-tac (`assets/sounds/tick_*.wav`).
- **Tic-tac** à chaque seconde, coupable. Il se mixe avec la musique sans la mettre en pause.
- **Ne pas déranger** : bloque les appels et les notifications de messages (alarmes et médias passent).
  Nécessite l'accès « Ne pas déranger » accordé une fois dans les réglages Android. Le réglage
  habituel de l'utilisateur est sauvegardé puis rétabli en quittant le plein écran, ou au lancement
  suivant si l'app a été tuée entre-temps (`DndController.kt`).

## Splash, widget, tuile et raccourcis (Android)

- **Splash animé** de 3 s (`lib/features/splash/`) après le splash natif : logo en Lottie
  (`assets/lottie/logo_reveal.json`), nom et slogan. Un toucher le passe ; il est sauté quand l'app
  est ouverte depuis le widget, la tuile ou un raccourci.
- **Widget d'écran d'accueil** (`TimerWidgetProvider.kt`) : session en cours et décompte en direct
  (Chronometer, sans réveiller l'app). Bouton ▶ : démarre ou reprend ; pendant une session, ouvre le
  plein écran.
- **Tuile Réglages rapides** (`PomodoroTileService.kt`) : démarre un Pomodoro, ou ouvre le décompte
  s'il tourne (sous-titre « Fin à 10:25 »).
- **Raccourcis** (appui long sur l'icône, `res/xml/shortcuts.xml`) : Démarrer, Plein écran,
  Statistiques.
- Paramètres → Raccourcis : ajout du widget et de la tuile en un geste (selon le lanceur / Android 13+).

L'app publie l'état du minuteur vers Android à chaque changement (`home_integration_service.dart`) ;
les actions arrivent par le canal `com.fab2dev.pomodocus/home`.

## Architecture (feature-first)

```
lib/
  main.dart, bootstrap.dart        démarrage, overrides Riverpod
  app/                             app, thème (couleurs, typo Manrope), router + registre de modules
  core/                            providers, services (notifications, son, haptique, updates),
                                   config distante, base Drift, horloge injectable, formatage
  features/
    focus/      domain/            PomodoroEngine (règles pures), entités, interfaces de repository
                data/              Drift (historique), SharedPreferences (minuteur actif)
                presentation/      TimerController, écran Focus, anneau, contrôles
    statistics/                    StatsSummary (calcul pur) + écran
    settings/                      PomodoroSettings (bornes, validation) + écran
    about/                         version et mises à jour
  shared/widgets/                  logo dessiné en code, motion (press, fade-in), stepper
```

### Fiabilité du minuteur

- Le temps restant est **toujours calculé depuis l'horloge** (`endsAt - now`), jamais à partir des
  ticks. Le ticker (250 ms) ne sert qu'à rafraîchir l'affichage.
- L'état actif est persisté à chaque transition ; au relancement ou au retour d'arrière-plan, l'état
  est recalculé et une session échue est finalisée.
- Finalisation **idempotente** : garde dans le contrôleur + `INSERT OR IGNORE` sur l'id de session.
- Heure du téléphone reculée : le temps restant est borné à la durée prévue. Avancée : la session
  se termine.
- Changer les durées n'affecte jamais une session démarrée (appliqué à la suivante).

### Règle de cycle

`cycleNumber` = rang du Pomodoro dans la série (1…N). Un focus terminé avec `cycleNumber ≥ N`
mène à la longue pause, après laquelle le compteur revient à 1 ; après une petite pause il augmente.

### Statistiques

« Temps concentré » = temps réellement concentré (sessions terminées + partie écoulée des sessions
interrompues). « Sessions terminées » ne compte que les Pomodoros complets. Les pauses ne comptent pas.

## Limites connues

- **Android** : la notification de fin utilise une alarme exacte si l'autorisation « Alarmes et
  rappels » est accordée, sinon une alarme inexacte qui peut être retardée par le mode Doze. Certains
  constructeurs (économie d'énergie agressive) peuvent aussi la retarder.
- **Enchaînement automatique en arrière-plan** : si l'app est fermée quand une session se termine,
  la suivante démarre au retour dans l'app (la notification prévient l'utilisateur).
- **iOS** : non compilé ici (nécessite macOS/Xcode). Les notifications utilisent le niveau
  *time-sensitive* ; leur affichage dépend des réglages Focus de l'utilisateur.
- APK actuelle signée avec la clé de debug (voir docs/RELEASING.md).

## Identité

Logo et déclinaisons dans `branding/` (`logo/` SVG maîtres, `png/` aperçus, `icons/` sources des icônes).
Régénérer : `py -3 branding/build_brand.py <dossier polices Manrope>`. Animations Lottie et son
générés par `node tool/generate_assets.js`.
