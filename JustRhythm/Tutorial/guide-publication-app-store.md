# Guide de publication sur l'App Store

Basé sur le parcours réel de publication de **JustRhythm** (première app, Bundle ID `dev.oundjian.justrhythm`). Réutilisable tel quel pour les prochaines apps sous le même compte développeur — il suffira d'adapter les noms et bundle IDs.

---

## 0. Prérequis uniques (déjà faits, ne se refont pas par app)

- [x] Compte Apple Developer Program payant activé (99 €/an, type **Individual**)
- [x] Vérification d'identité passée (CNI ou passeport — **pas** le permis rose, souvent refusé par le scan automatique)
- [x] Compte lié à un **Apple ID personnel**, jamais à une adresse d'employeur — l'identité qui publie doit survivre à un changement de job

**Piège rencontré** : l'écran "Select Document Type" qui n'affiche que *Driver's License* sans passeport ni CNI, même pour un compte français. Cause exacte non confirmée (probablement un souci ponctuel côté Apple) — résolu en reprenant le parcours depuis `developer.apple.com/enroll` avec le nom exact de la pièce d'identité (accents compris) et en revalidant depuis le début. Si ça se reproduit : contacter le support Apple (`developer.apple.com/contact`), ne pas soumettre une pièce non conforme pour forcer le passage.

**Convention retenue** : préfixe reverse-DNS `dev.oundjian.*` pour toutes les apps futures (pas de nom de domaine à posséder, Apple ne vérifie rien). Un App ID **explicite** par app (`dev.oundjian.nomdelapp`) — jamais de wildcard `dev.oundjian.*`, incompatible avec push, iCloud, App Groups, achats intégrés, Sign in with Apple.

---

## 1. Avant de coder / en parallèle de l'attente du compte

- [ ] Décider le **Bundle Identifier** définitif (`dev.oundjian.nomdelapp`) — s'y tenir, il devient figé après création de l'App ID
- [ ] Ajouter **`PrivacyInfo.xcprivacy`** au projet dès que possible (voir §5) — évite un rejet automatique au premier upload

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

**Piège rencontré** : avec "Automatically manage signing" coché, Xcode crée silencieusement un nouvel App ID à chaque changement de Bundle ID testé pendant le développement — la liste peut vite se remplir de doublons (`MyCompany.*`, anciens essais). Nettoyer périodiquement dans le portail (clic sur l'entrée → Delete) une fois le bon identifiant confirmé actif dans Xcode.

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

### Sur App Store Connect
**Confiance et sécurité** → **Confidentialité de l'app** → déclarer "Aucune donnée collectée" si l'app fonctionne en local sans réseau ni compte utilisateur.

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

**Important** : le code de raison doit être **exactement** la chaîne du catalogue Apple (`CA92.1`, `35F9.1`, etc.) — jamais un texte descriptif libre. Vérifier via clic droit sur le fichier → **Open As** → **Source Code** : les balises `<string>` sous les raisons doivent contenir uniquement le code, rien d'autre. L'inspecteur graphique de Xcode peut afficher un libellé descriptif à côté à titre d'aide — ce n'est qu'un affichage, pas ce qui est réellement écrit dans le fichier.

Comment savoir quelles API sont utilisées : chercher dans le code (`Cmd+Shift+F`) les occurrences de `UserDefaults`, `systemUptime`, `mach_absolute_time`, ou tout usage de `Date()` à des fins de chronométrage.

---

## 6. Réglages projet à vérifier avant l'archive

**Orientation** (target → **General** → **Deployment Info**) :
- Décocher toutes les orientations sauf celle réellement supportée (ex. **Portrait** seul)
- Puis, onglet **Info** → ajouter la clé **Requires full screen** (`UIRequiresFullScreen`) à `YES`

Sans cette seconde étape, Xcode signale : *"All interface orientations must be supported unless the app requires full screen."*

**Icône** : 1024×1024 px, **sans canal alpha** (pas de transparence, même invisible). Si exportée depuis Figma/Sketch/Photoshop, vérifier qu'elle est aplatie en RGB pur avant import dans l'Asset Catalog.

---

## 7. Archive et upload

Dans Xcode :
1. Destination de build : **Any iOS Device (arm64)** — pas un simulateur, pas l'iPhone en USB
   - Cette destination ne sert **qu'à archiver**, pas à lancer l'app (bouton ▶️). Xcode refuse avec *"A build only device cannot be used to run this target"* si on essaie de la lancer dessus — normal, ignorer et passer par le menu Product
2. Menu **Product** (barre du haut, pas la fenêtre du projet) → **Archive**
3. Une fois l'archive terminée, l'**Organizer** s'ouvre automatiquement, onglet **Archives**

**Avant Distribute App : cliquer sur Validate App**
Fait localement les mêmes vérifications qu'Apple à la réception (signature, `PrivacyInfo.xcprivacy`, icône) sans consommer d'upload. Permet de détecter un souci avant d'attendre le traitement serveur.

**Piège rencontré à la première validation** : erreur *"Invalid Signature. Code failed to satisfy specified code requirement(s)... Make sure you have signed your application with a distribution certificate, not an ad hoc certificate or a development certificate."*

Cause : sur un compte développeur tout juste activé, le certificat **Apple Distribution** n'existe pas encore automatiquement — seul le certificat de développement (utilisé pour lancer l'app sur son propre iPhone) est présent.

Correction :
1. **Xcode → Settings** (Cmd+,) → onglet **Accounts**
2. Sélectionner son Apple ID → sélectionner l'équipe → **Manage Certificates…**
3. Si aucun **Apple Distribution** n'apparaît dans la liste : clic sur **+** en bas à gauche → **Apple Distribution** → Xcode le génère et le télécharge automatiquement
4. Fermer, retourner sur le projet → **Product** → **Clean Build Folder** (Cmd+Shift+K)
5. **Product** → **Archive** à nouveau
6. Relancer **Validate App** sur la nouvelle archive pour confirmer

**Une fois Validate App réussi → Distribute App**
1. **App Store Connect** (déjà présélectionné dans la fenêtre "Select a method for distribution" — c'est le bon choix, les autres options comme *TestFlight Internal Only*, *Release Testing*, *Enterprise* ne s'appliquent pas ici)
2. **Upload** (pas *Export*, qui génère juste un .ipa local sans le publier)
3. Signature automatique (Automatically manage signing), sauf raison contraire
4. Continuer jusqu'à l'écran final et confirmer

Délai habituel avant que le build apparaisse dans TestFlight sur App Store Connect : **10 à 60 minutes**.

---

## 8. TestFlight — la vraie phase de test

- Installer l'app soi-même via l'app TestFlight sur son propre iPhone
- Faire une **vraie séance d'usage**, pas juste ouvrir l'app deux secondes — c'est là qu'on découvre ce qui cloche en conditions réelles
- Point de vigilance identifié pour JustRhythm : l'app est **inutilisable sans clavier MIDI**. Un examinateur Apple qui l'ouvre sans matériel connecté ne verra qu'un écran qui ne fait rien. Deux actions :
  - Soigner l'état "aucun clavier détecté" — c'est probablement le seul écran que l'examinateur verra
  - Écrire une note claire dans **App Review Notes** (en anglais, quelle que soit la langue de l'app) expliquant ce point avant soumission

---

## 9. Soumission finale

- Remplir la fiche complète : captures d'écran (formats exacts affichés par App Store Connect selon la taille d'appareil), description, catégorie (ex. **Musique**)
- Fiche de collecte de données : confirmer "aucune donnée" si toujours vrai
- Soumettre pour revue
- Délai habituel : quelques jours
- Un ou deux rejets sur des détails de fiche (métadonnées, captures, wording) sont fréquents et normaux à la première soumission — pas un signal d'alarme

---

## Récapitulatif express (checklist copier-coller pour la prochaine app)

- [ ] Bundle ID choisi : `dev.oundjian.___`
- [ ] App ID créé dans le portail développeur
- [ ] Xcode : Bundle ID + Team alignés
- [ ] Fiche App Store Connect créée (nom, langue, SKU, Bundle ID)
- [ ] `PrivacyInfo.xcprivacy` ajouté et vérifié en Source Code
- [ ] Fiche de confidentialité remplie
- [ ] Orientation verrouillée + Requires full screen si applicable
- [ ] Icône 1024×1024 sans alpha
- [ ] Archive → **Validate App** (vérifier le certificat **Apple Distribution** existe dans Manage Certificates si erreur de signature) → Distribute App → App Store Connect → Upload
- [ ] Test réel via TestFlight + App Review Notes si point d'usage à signaler
- [ ] Captures, description, catégorie
- [ ] Soumission
