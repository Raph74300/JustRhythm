# Guide de publication sur l'App Store

Basé sur le parcours réel de publication de **JustRhythm** (première app, Bundle ID `dev.oundjian.justrhythm`). Réutilisable tel quel pour les prochaines apps sous le même compte développeur — il suffira d'adapter les noms, bundle IDs et contenus.

---

## 0. Prérequis uniques (déjà faits, ne se refont pas par app)

- [x] Compte Apple Developer Program payant activé (99 €/an, type **Individual**)
- [x] Vérification d'identité passée (CNI ou passeport — **pas** le permis rose, souvent refusé par le scan automatique)
- [x] Compte lié à un **Apple ID personnel**, jamais à une adresse d'employeur — l'identité qui publie doit survivre à un changement de job

**Piège rencontré** : l'écran "Select Document Type" qui n'affiche que *Driver's License* sans passeport ni CNI, même pour un compte français. Résolu en reprenant le parcours depuis `developer.apple.com/enroll` avec le nom exact de la pièce d'identité (accents compris) et en revalidant depuis le début. Si ça se reproduit : contacter le support Apple (`developer.apple.com/contact`), ne pas soumettre une pièce non conforme pour forcer le passage.

**Convention retenue** : préfixe reverse-DNS `dev.oundjian.*` pour toutes les apps futures (pas de nom de domaine à posséder, Apple ne vérifie rien). Un App ID **explicite** par app (`dev.oundjian.nomdelapp`) — jamais de wildcard, incompatible avec push, iCloud, App Groups, achats intégrés, Sign in with Apple.

---

## 1. Avant de coder / en parallèle de l'attente du compte

- [ ] Décider le **Bundle Identifier** définitif (`dev.oundjian.nomdelapp`) — s'y tenir, il devient figé après création de l'App ID
- [ ] Ajouter **`PrivacyInfo.xcprivacy`** au projet dès que possible (voir §5) — évite un rejet automatique au premier upload
- [ ] Vérifier tôt quelles méthodes de connexion / capacités sont **réellement implémentées** dans le code (voir §9bis) — évite de promettre publiquement une fonctionnalité pas encore solide, ou d'oublier d'en retirer la mention si elle est abandonnée en cours de route

---

## 2. App ID dans le portail développeur

`developer.apple.com/account` → **Certificates, Identifiers & Profiles** → **Identifiers** → **+**

1. **App IDs** → **App**
2. Description : nom de l'app
3. Bundle ID : **Explicit** → `dev.oundjian.nomdelapp` (minuscules, exact)
4. Capabilities : ne cocher que ce qui est réellement utilisé (rien par défaut pour une app locale sans réseau)
5. **Continue** → **Register**

**Vérifier dans Xcode** (Signing & Capabilities) :
- Bundle Identifier identique au caractère près
- **Team** : bien l'équipe personnelle sélectionnée (pas une équipe d'employeur si le compte y a aussi accès)

**Piège rencontré** : avec "Automatically manage signing" coché, Xcode crée silencieusement un nouvel App ID à chaque changement de Bundle ID testé pendant le développement — la liste peut vite se remplir de doublons. Nettoyer périodiquement dans le portail (clic sur l'entrée → Delete) une fois le bon identifiant confirmé actif dans Xcode.

---

## 3. Fiche App Store Connect

`appstoreconnect.apple.com` → **Apps** → **+** → **New App**

| Champ | Valeur | Remarque |
|---|---|---|
| Platforms | iOS (+ watchOS si app compagnon) | |
| Name | Nom public | Unique sur tout l'App Store, distinct du Bundle ID |
| Primary Language | Anglais recommandé | Élargit l'audience direct ; on peut ajouter d'autres langues plus tard sans tout refaire |
| Bundle ID | Sélectionner celui créé en §2 | |
| SKU | Identifiant interne, jamais public | Ex. `NOMAPP001` — ne pas recopier le Bundle ID pour éviter la confusion |
| User Access | Full Access | |

**Note langue** : le nom, la description, les mots-clés et les captures se localisent indépendamment de l'UI de l'app elle-même. Rien n'empêche une UI en français et une fiche en anglais, ou l'inverse.

---

## 4. Conformité DSA — statut de trader

`Business` (menu du haut) → **Agreements** → section conformité DSA → déclarer le statut (généralement **non-trader** pour une publication à titre personnel sans structure).

À faire **une fois pour tout le compte**, pas par app. Peut bloquer la soumission si oublié — à traiter tôt.

---

## 5. Fiche de confidentialité + `PrivacyInfo.xcprivacy`

⚠️ **Ne pas confondre deux choses distinctes**, qui vivent à des endroits différents d'App Store Connect :
- **La fiche "nutrition label"** (ce paragraphe) : déclare quels *types de données* l'app collecte
- **L'URL de politique de confidentialité** (voir §9.3) : un lien vers une vraie page web, obligatoire même sans collecte de données

### Sur App Store Connect
**Confiance et sécurité** → **Confidentialité de l'app** → déclarer "Aucune donnée collectée" si l'app fonctionne en local sans réseau ni compte utilisateur.

Une fois l'URL de politique de confidentialité renseignée (§9.3), cette page a son **propre bouton "Publier"**, distinct du bouton "Ajouter pour vérification" de la page Distribution — à ne pas oublier, sinon la fiche de confidentialité reste en brouillon.

### Dans Xcode
Créer via **New File** → template **App Privacy File** (nom : `PrivacyInfo.xcprivacy`, target bien cochée).

Trois sections à remplir :
- **Tracking** : `NO`
- **Collected Data Types** : tableau vide (cohérent avec la fiche ci-dessus)
- **Accessed API Types** : déclarer chaque catégorie d'API "à motif obligatoire" réellement utilisée dans le code

**Catégories rencontrées sur JustRhythm** (app de mesure de justesse rythmique) :

| API utilisée dans le code | Catégorie à déclarer | Code de raison |
|---|---|---|
| `UserDefaults` (réglages locaux) | `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1` |
| `mach_absolute_time` / `systemUptime` (mesure de temps) | `NSPrivacyAccessedAPICategorySystemBootTime` | `35F9.1` |

**Important** : le code de raison doit être **exactement** la chaîne du catalogue Apple (`CA92.1`, `35F9.1`, etc.) — jamais un texte descriptif libre. Vérifier via clic droit sur le fichier → **Open As** → **Source Code** : les balises `<string>` sous les raisons doivent contenir uniquement le code. L'inspecteur graphique de Xcode peut afficher un libellé descriptif à côté à titre d'aide — ce n'est qu'un affichage, pas ce qui est réellement écrit dans le fichier.

Comment savoir quelles API sont utilisées : chercher dans le code (`Cmd+Shift+F`) les occurrences de `UserDefaults`, `systemUptime`, `mach_absolute_time`, ou tout usage de `Date()` à des fins de chronométrage.

---

## 6. Réglages projet à vérifier avant l'archive

**Orientation** (target → **General** → **Deployment Info**) :
- Décocher toutes les orientations sauf celles réellement supportées. JustRhythm ne coche que **Landscape Left** et **Landscape Right** depuis la 2.8 ; une application couchée en permanence se déclare ici et nulle part ailleurs — inutile d'écrire du code d'orientation.
- Puis, onglet **Info** → ajouter la clé **Requires full screen** (`UIRequiresFullScreen`) à `YES`

Sans cette seconde étape, Xcode signale : *"All interface orientations must be supported unless the app requires full screen."*

**Note** : Xcode peut aussi afficher un warning *"'UIRequiresFullScreen' has been deprecated starting in iOS 26.0 and will be ignored..."* une fois la clé ajoutée. C'est bénin — un avertissement de dépréciation future, pas une erreur. Le build réussit quand même et l'upload passe normalement.

**Icône** : 1024×1024 px, **sans canal alpha** (pas de transparence, même invisible). Script réutilisable : `AdaptImage.sh` (aplatit en JPEG puis reconvertit en PNG 1024×1024 via `sips`, sans canal alpha).

---

## 6bis. Conformité des visuels (captures + vidéo App Preview) — scripts réutilisables

### Captures d'écran — piège fréquent même en capturant sur un vrai iPhone

App Store Connect exige des dimensions **exactes**. Deux catégories servent en pratique :

| Catégorie | Portrait | Paysage |
|---|---|---|
| iPhone 6,9" — celle qu'on remplit aujourd'hui | `1320×2868` ou `1290×2796` | `2868×1320` ou `2796×1290` |
| iPhone 6,5" — repli, toujours accepté | `1242×2688` ou `1284×2778` | `2688×1242` ou `2778×1284` |

Ces chiffres correspondent aux résolutions natives de certains iPhones — **pas** à celle de ton téléphone. Une capture prise directement sur un iPhone 15 ou 16 (1179×2556, soit 2556×1179 couché) est parfaitement nette mais **ne correspond à aucune taille acceptée**, et sera refusée avec l'erreur *"Les dimensions d'au moins une capture d'écran sont incorrectes."*

Les proportions sont quasi identiques (écart ~0,2 %). Le script redimensionne donc **proportionnellement** puis recadre les quelques pixels en trop, plutôt que de forcer les deux dimensions d'un coup : la déformation serait invisible, mais elle n'a aucune raison d'exister.

**Script `resize-screenshots.sh`** (basé sur `sips`, natif macOS, aucune dépendance) :
```bash
chmod +x resize-screenshots.sh
./resize-screenshots.sh "/chemin/vers/tes/captures"
```
Détecte portrait/paysage automatiquement et produit les deux tailles d'un coup, dans `conformes/6.9-inch` et `conformes/6.5-inch`, sans toucher aux originaux. Vérifie aussi l'absence de canal alpha, qu'App Store Connect refuse.

### Vidéo App Preview — contraintes bien plus strictes qu'une image

Si une vidéo de démo est ajoutée à la fiche, les exigences dépassent largement la résolution :
- **Résolution** : `886×1920` (portrait) ou `1920×886` (paysage) pour iPhone — dimensions **différentes** de celles des captures d'écran, ne pas confondre
- **Codec** : H.264 High Profile (jusqu'au niveau 4.0) ou ProRes 422 HQ uniquement — un export **HEVC** (souvent le défaut d'un enregistrement d'écran iPhone) est rejeté
- **Audio** : une piste doit être présente, même silencieuse — un enregistrement sans son est rejeté pour cette seule raison
- **Fréquence d'images** : max 30 fps (les enregistrements d'écran tournent parfois à 60 fps)
- **Durée** : entre 15 et 30 secondes

**Script `conform-preview-video.sh`** (nécessite `ffmpeg`, installable via `brew install ffmpeg`) :
```bash
chmod +x conform-preview-video.sh
./conform-preview-video.sh "/chemin/vers/ta-video.mov"
```
Détecte l'orientation, rééencode en H.264 High Profile 4.0, plafonne à 30 fps, **ajoute une piste audio silencieuse si absente**, et avertit (sans couper automatiquement) si la durée sort de la fenêtre 15-30s.

---

## 7. Archive et upload

**Avant toute nouvelle archive après un premier upload déjà envoyé** : incrémenter le **Build** (target → General → champ Build, sous Version). Apple refuse un upload dont le couple Version + Build est identique à un build déjà reçu (`1.0 (1)` déjà uploadé → repasser à `1.0 (2)`, etc.). La **Version** (1.0) ne change que lors d'une vraie mise à jour publiée ; le **Build** s'incrémente à chaque envoi, y compris pour corriger un bug avant la première soumission.

Dans Xcode :
1. Destination de build : **Any iOS Device (arm64)** — pas un simulateur, pas l'iPhone en USB
   - Cette destination ne sert **qu'à archiver**, pas à lancer l'app (bouton ▶️). Xcode refuse avec *"A build only device cannot be used to run this target"* si on essaie de la lancer dessus — normal, ignorer et passer par le menu Product
2. Menu **Product** (barre du haut, pas la fenêtre du projet) → **Archive**
3. Une fois l'archive terminée, l'**Organizer** s'ouvre automatiquement, onglet **Archives**

**Avant Distribute App : cliquer sur Validate App**
Fait localement les mêmes vérifications qu'Apple à la réception (signature, `PrivacyInfo.xcprivacy`, icône) sans consommer d'upload.

**Piège rencontré à la première validation** : erreur *"Invalid Signature. Code failed to satisfy specified code requirement(s)... Make sure you have signed your application with a distribution certificate, not an ad hoc certificate or a development certificate."*

Cause : sur un compte développeur tout juste activé, le certificat **Apple Distribution** n'existe pas encore automatiquement — seul le certificat de développement est présent.

Correction :
1. **Xcode → Settings** (Cmd+,) → onglet **Accounts**
2. Sélectionner son Apple ID → sélectionner l'équipe → **Manage Certificates…**
3. Si aucun **Apple Distribution** n'apparaît : clic sur **+** → **Apple Distribution** → Xcode le génère et le télécharge automatiquement
4. **Product** → **Clean Build Folder** (Cmd+Shift+K)
5. **Product** → **Archive** à nouveau
6. Relancer **Validate App** pour confirmer

**Une fois Validate App réussi → Distribute App**
1. **App Store Connect** (déjà présélectionné — c'est le bon choix, les autres options comme *TestFlight Internal Only*, *Release Testing*, *Enterprise* ne s'appliquent pas ici)
2. **Upload** (pas *Export*, qui génère juste un .ipa local)
3. Signature automatique (Automatically manage signing), sauf raison contraire
4. Continuer jusqu'à l'écran final et confirmer

Délai habituel avant que le build apparaisse dans TestFlight : **10 à 60 minutes**.

---

## 7bis. Conformité chiffrement (popup TestFlight)

Au premier build visible dans TestFlight, App Store Connect affiche presque toujours une popup **"Documents sur le chiffrement des apps"**.

Pour une app sans serveur, sans communication réseau chiffrée et sans bibliothèque crypto personnalisée : cocher **"Aucun des algorithmes mentionnés ci-dessus"** → **Enregistrer**.

**Pour ne plus jamais revoir cette popup**, ajouter dans `Info.plist` :
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

---

## 8. TestFlight — la vraie phase de test

**Étape souvent oubliée : s'ajouter soi-même comme testeur.**
Un build "Prêt à soumettre" n'est **pas** automatiquement installable, même par le développeur — sans groupe de testeurs, personne n'est invité.

1. App Store Connect → onglet **TestFlight** → **+** à côté de **"TESTS INTERNES"**
2. Créer un groupe (ex. "Interne")
3. Ajouter son propre Apple ID comme testeur
4. Sélectionner le build pour ce groupe
5. Une invitation arrive par email ou directement dans l'app TestFlight

Ensuite, sur l'iPhone : installer l'app **TestFlight**, se connecter avec le même Apple ID, installer.

**Une fois installée** :
- Faire une **vraie séance d'usage** — c'est là qu'on découvre ce qui cloche en conditions réelles
- **Piège rencontré** : après une séance, débrancher le clavier MIDI peut laisser l'écran principal figé sur les **dernières valeurs jouées** (score, graphique) au lieu de revenir à un état neutre, alors même que le badge "No keyboard" en bas s'actualise correctement. Vérifier que **toute la zone d'affichage** (pas qu'un badge isolé) se réinitialise à la déconnexion — sinon l'examinateur peut voir des chiffres qui semblent factices.
- Point de vigilance plus général : si l'app est inutilisable sans matériel externe (MIDI, Bluetooth, etc.), un examinateur qui l'ouvre sans ce matériel ne verra qu'un écran d'attente. Deux actions : soigner cet état vide, et écrire une note claire dans **App Review Notes** (voir §9.4)

---

## 9. Rédiger le contenu de la fiche

### 9.1 Limites de caractères réelles — vérifier avant de rédiger

| Champ réel App Store Connect | Limite | Piège rencontré |
|---|---|---|
| **Subtitle** | 30 caractères | Un sous-titre "naturel" dépasse vite (ex. 33/30) — compter avant de valider |
| **Promotional Text** | 170 caractères | C'est le champ qui correspond à une "description courte" — modifiable à tout moment sans nouvelle version, contrairement à la Description |
| **Description** | 4000 caractères | Large marge en général |
| **Keywords** | 100 caractères, séparés par virgules **sans espace** | Ne pas répéter un mot déjà présent dans le nom de l'app ou le Subtitle — Apple les indexe déjà automatiquement, donc les répéter gaspille du budget caractère pour rien |

**Slogan / Marketing Copy / User Promise / Positioning** : utiles comme repères de ton pour rédiger, mais n'ont **aucun champ dédié** dans App Store Connect — à ne pas chercher à coller quelque part.

**Éviter les superlatifs invérifiables** ("le premier", "le seul") dans la Description — risque inutile pour un bénéfice marketing marginal.

### 9.2 Vérifier que les capacités annoncées sont réellement implémentées

Avant d'écrire "Supporte Bluetooth / réseau / etc." dans la Description : confirmer avec le code, pas avec l'intention. Une fonctionnalité évoquée puis abandonnée en cours de route doit être retirée de **tous** les textes (Description, mots-clés, App Review Notes) — pas seulement de la fiche marketing.

### 9.3 Deux pages web obligatoires à héberger soi-même

Deux champs différents, deux emplacements différents dans App Store Connect :

| Champ | Obligatoire | Emplacement | Format attendu |
|---|---|---|---|
| **URL de l'assistance** (Support URL) | Oui | **Informations sur l'app** (Général) | Vraie page web `https://`, **pas** de lien `mailto:` |
| **URL de la Politique de confidentialité** | Oui, même sans collecte de données | **Confidentialité de l'app** (Confiance et sécurité) | Vraie page web, distincte de la fiche "nutrition label" |
| **Copyright** | Oui | **Informations sur l'app** (Général) | Format strict `[Année] [Nom]`, ex. `2026 Prénom Nom` — sans URL, sans texte marketing |

**Solution rapide sans site existant** : héberger deux pages HTML statiques sur **GitHub Pages** (`username.github.io`) — gratuit, HTTPS natif, upload direct via l'interface web GitHub (Add file → Upload files). URL finale : `https://username.github.io/nom-du-fichier.html`.

Astuce de cohérence visuelle : reprendre la palette et l'icône réelles de l'app plutôt qu'un template générique — ancre les pages dans l'identité du produit.

### 9.4 App Review Information (fiche de version)

- **Connexion requise** : décocher cette case si l'app n'a ni compte ni identifiants — sinon l'examinateur tentera de se connecter et échouera, ce qui peut entraîner un rejet sans rapport avec l'app elle-même
- **Coordonnées** (Prénom, Nom, Téléphone, E-mail) : bloque la soumission si laissé vide, malgré une apparence de champ facultatif
- **Remarques / Notes** : c'est le champ le plus important en cas de point d'usage particulier (ex. matériel externe requis) — rédiger en anglais, quelle que soit la langue de l'app. Exemple utilisé pour JustRhythm :
  > This app requires a MIDI keyboard connected via USB to function — it analyzes the timing of notes played against a metronome click. Without a keyboard connected, the app displays a clean "No keyboard detected" state (see Settings screen) rather than any error. This is expected behavior, not a bug.
- Pas de compte de démonstration nécessaire pour une app sans login

### 9.5 Captures d'écran et sélection du build

- Formats exacts vus en §6bis — utiliser `resize-screenshots.sh` si besoin
- Seules les **3 premières** captures sont utilisées sur la fiche d'installation
- Les captures servent pour toutes les langues et tailles déclarées
- **Build** : sélectionner celui déjà validé en TestFlight, dans la section Build de la fiche de version

### 9.6 Prix et disponibilité

Onglet **Tarification et disponibilité** : gratuit ou payant, pays de disponibilité (Monde entier convient dans la plupart des cas).

### 9.7 Soumettre

- Sur la page **Confidentialité de l'app** : cliquer sur son propre bouton **Publier** une fois l'URL de politique de confidentialité enregistrée — distinct du bouton de soumission de la page Distribution
- Sur la page **Distribution** (App iOS Version X.X) : bouton **Ajouter pour vérification**, puis confirmer
- Choix du mode de publication : automatique dès l'approbation, ou manuelle (l'app reste approuvée mais non publiée tant qu'on ne clique pas sur "Publier") — la manuelle laisse le contrôle du moment exact de sortie

### 9.8 Après soumission

- Délai habituel de revue : **quelques jours**
- Un ou deux rejets sur des détails de fiche (métadonnées, wording, catégorie) sont fréquents et normaux à la première soumission — corriger le point signalé dans **Resolution Center** et resoumettre
- Si rejet lié à un usage nécessitant du matériel externe : vérifier que la note en App Review Notes est assez explicite, éventuellement ajouter une courte vidéo de démo si le rejet persiste

---

## Récapitulatif express (checklist copier-coller pour la prochaine app)

- [ ] Bundle ID choisi : `dev.oundjian.___`
- [ ] App ID créé dans le portail développeur
- [ ] Xcode : Bundle ID + Team alignés
- [ ] Fiche App Store Connect créée (nom, langue, SKU, Bundle ID)
- [ ] `PrivacyInfo.xcprivacy` ajouté et vérifié en Source Code
- [ ] Fiche de confidentialité "nutrition label" remplie
- [ ] Orientation verrouillée + Requires full screen si applicable
- [ ] Icône 1024×1024 sans alpha (`AdaptImage.sh`)
- [ ] Archive → **Validate App** (vérifier certificat Apple Distribution si erreur de signature) → Distribute App → Upload
- [ ] Conformité chiffrement (popup ou clé `ITSAppUsesNonExemptEncryption`)
- [ ] Groupe de testeurs internes créé + soi-même ajouté → build installé via TestFlight
- [ ] Test réel via TestFlight — vérifier qu'aucun état d'écran ne reste figé sur d'anciennes données
- [ ] Capacités réellement implémentées vérifiées avant rédaction (pas de fonctionnalité fantôme dans les textes)
- [ ] Subtitle ≤30 car., Promotional Text ≤170 car., Keywords ≤100 car. sans doublon avec nom/subtitle
- [ ] Captures d'écran aux bonnes dimensions (`resize-screenshots.sh` si besoin)
- [ ] Vidéo App Preview conforme si utilisée (`conform-preview-video.sh` si besoin)
- [ ] Page Support hébergée (GitHub Pages ou équivalent) + URL renseignée
- [ ] Page Politique de confidentialité hébergée + URL renseignée dans "Confidentialité de l'app"
- [ ] Copyright renseigné (format `[Année] [Nom]`)
- [ ] App Review Information : Connexion requise décochée si pas de login, Coordonnées remplies, Remarques rédigées si besoin
- [ ] Build sélectionné dans la fiche de version
- [ ] Prix et disponibilité renseignés
- [ ] Bouton Publier cliqué sur la fiche Confidentialité de l'app
- [ ] Ajouter pour vérification → choix publication auto/manuelle → soumission
