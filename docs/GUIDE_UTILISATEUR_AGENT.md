# 📱 Guide Utilisateur - Application Agent d'Embarquement

## Transport Interurbain - Application Mobile Agent

**Version**: 1.1  
**Dernière mise à jour**: Janvier 2026

---

## Table des Matières

1. [Introduction](#1-introduction)
2. [Installation et Configuration](#2-installation-et-configuration)
3. [Connexion à l'Application](#3-connexion-à-lapplication)
4. [Interface Principale](#4-interface-principale)
5. [Scanner un Ticket](#5-scanner-un-ticket)
6. [Validation des Tickets](#6-validation-des-tickets)
7. [Consultation des Voyages](#7-consultation-des-voyages)
8. [Gestion des Passagers](#8-gestion-des-passagers)
9. [Mode Hors Ligne](#9-mode-hors-ligne)
10. [Résolution des Problèmes](#10-résolution-des-problèmes)
11. [Bonnes Pratiques](#11-bonnes-pratiques)
12. [FAQ](#12-faq)
13. [Contact Support](#13-contact-support)

---

## 1. Introduction

### 🎯 Objectif de l'Application

L'application **Agent d'Embarquement** est conçue pour faciliter le travail des agents de terrain lors de l'embarquement des passagers. Elle permet de :

- **Scanner** les tickets des passagers (QR Code)
- **Vérifier** la validité des réservations
- **Valider** l'embarquement en temps réel
- **Consulter** la liste des passagers d'un voyage
- **Travailler** même sans connexion internet

### 👤 À qui s'adresse ce guide ?

Ce guide est destiné aux **agents d'embarquement** travaillant pour les compagnies de transport. Il couvre toutes les fonctionnalités de l'application mobile.

### 📋 Prérequis

- Smartphone Android (version 6.0+) ou iPhone (iOS 12+)
- Compte agent créé par votre compagnie
- Connexion internet (WiFi ou données mobiles) pour la synchronisation
- Caméra fonctionnelle pour le scan des QR codes

---

## 2. Installation et Configuration

### 📲 Téléchargement de l'Application

#### Android
1. Ouvrez le **Google Play Store**
2. Recherchez "**Transport Agent**"
3. Sélectionnez l'application avec le logo officiel
4. Appuyez sur **Installer**
5. Attendez la fin du téléchargement

#### iPhone
1. Ouvrez l'**App Store**
2. Recherchez "**Transport Agent**"
3. Appuyez sur **Obtenir**
4. Confirmez avec Face ID, Touch ID ou mot de passe
5. Attendez l'installation

### ⚙️ Configuration Initiale

Au premier lancement :

1. **Autorisations requises** :
   - 📷 **Caméra** : Indispensable pour scanner les QR codes
   - 📍 **Localisation** : Optionnel, pour le suivi des embarquements
   - 🔔 **Notifications** : Pour recevoir les alertes

2. **Acceptez** les conditions d'utilisation

3. **Sélectionnez** votre langue (Français par défaut)

> ⚠️ **Important** : L'accès à la caméra est obligatoire pour le scan des tickets.

---

## 3. Connexion à l'Application

### 🔐 Obtenir vos Identifiants

Vos identifiants sont fournis par votre **responsable** ou le **service RH** de votre compagnie :
- **Téléphone** : Votre numéro professionnel
- **Mot de passe** : Fourni à l'embauche (à changer à la première connexion)

### 📱 Procédure de Connexion

1. **Ouvrez** l'application Agent
2. **Entrez** votre numéro de téléphone (format : 77XXXXXXX)
3. **Saisissez** votre mot de passe
4. Appuyez sur **Se connecter**

```
┌─────────────────────────────────┐
│      🚌 Transport Agent         │
│                                 │
│  ┌─────────────────────────┐   │
│  │ 📱 77 123 45 67         │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │ 🔒 ••••••••             │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │      Se connecter       │   │
│  └─────────────────────────┘   │
│                                 │
│  Mot de passe oublié ?          │
└─────────────────────────────────┘
```

### 🔄 Mot de Passe Oublié

1. Appuyez sur "**Mot de passe oublié ?**"
2. Entrez votre numéro de téléphone
3. Un code de réinitialisation sera envoyé par SMS
4. Créez un nouveau mot de passe

> 💡 **Conseil** : Votre mot de passe doit contenir au moins 6 caractères.

---

## 4. Interface Principale

### 🏠 Écran d'Accueil

Après connexion, vous accédez au **tableau de bord** :

```
┌─────────────────────────────────┐
│ 🚌 Bonjour, Amadou !       ⚙️  │
├─────────────────────────────────┤
│                                 │
│  ┌───────────────────────────┐ │
│  │      📷 SCANNER           │ │
│  │      un ticket            │ │
│  └───────────────────────────┘ │
│                                 │
│  Voyage en cours :              │
│  ┌───────────────────────────┐ │
│  │ Dakar → Thiès             │ │
│  │ 🕐 14:00 | Bus: DK-1234   │ │
│  │ 👥 32/50 embarqués        │ │
│  │ ━━━━━━━━━━━░░░░░░░░ 64%   │ │
│  └───────────────────────────┘ │
│                                 │
│  ┌──────────┐ ┌──────────┐     │
│  │ 📋       │ │ 📊       │     │
│  │ Voyages  │ │ Stats    │     │
│  └──────────┘ └──────────┘     │
│                                 │
├─────────────────────────────────┤
│  🏠    📷    📋    👤           │
└─────────────────────────────────┘
```

### 📌 Éléments de l'Interface

| Élément | Description |
|---------|-------------|
| **Bouton Scanner** | Lance le scanner de QR code |
| **Voyage en cours** | Affiche le prochain voyage assigné |
| **Barre de progression** | Nombre de passagers embarqués |
| **Menu Voyages** | Liste de tous vos voyages |
| **Menu Stats** | Statistiques d'embarquement |

### 🔽 Barre de Navigation

- 🏠 **Accueil** : Retour au tableau de bord
- 📷 **Scanner** : Accès rapide au scan
- 📋 **Voyages** : Liste des voyages
- 👤 **Profil** : Paramètres et déconnexion

---

## 5. Scanner un Ticket

### 📷 Procédure de Scan

Le scan est la fonction principale de l'application :

1. **Appuyez** sur le bouton **Scanner**
2. **Pointez** la caméra vers le QR code du ticket
3. **Maintenez** le téléphone stable
4. Le scan est **automatique** dès que le code est détecté

```
┌─────────────────────────────────┐
│        Scanner le ticket        │
├─────────────────────────────────┤
│                                 │
│   ┌─────────────────────────┐   │
│   │                         │   │
│   │     ┌───────────┐       │   │
│   │     │ QR CODE   │       │   │
│   │     │   ici     │       │   │
│   │     └───────────┘       │   │
│   │                         │   │
│   └─────────────────────────┘   │
│                                 │
│   💡 Placez le QR code dans     │
│      le cadre                   │
│                                 │
│   ┌─────────────────────────┐   │
│   │ 🔦 Activer la lampe     │   │
│   └─────────────────────────┘   │
│                                 │
└─────────────────────────────────┘
```

### 🔦 Options du Scanner

- **Lampe torche** : Activez pour scanner dans l'obscurité
- **Zoom** : Pincez l'écran pour zoomer si nécessaire
- **Annuler** : Balayez vers le bas ou appuyez sur retour

### ✅ Résultat du Scan - Ticket Valide

```
┌─────────────────────────────────┐
│       ✅ TICKET VALIDE          │
├─────────────────────────────────┤
│                                 │
│  Passager :                     │
│  ┌───────────────────────────┐ │
│  │ 👤 Fatou DIALLO           │ │
│  │ 📱 77 234 56 78           │ │
│  └───────────────────────────┘ │
│                                 │
│  Détails du voyage :            │
│  ┌───────────────────────────┐ │
│  │ 📍 Dakar → Thiès          │ │
│  │ 📅 16 Jan 2026            │ │
│  │ 🕐 14:00                   │ │
│  │ 💺 Siège N°15             │ │
│  │ 🎫 TKT-2026-00456         │ │
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │   ✅ VALIDER EMBARQUEMENT │ │
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │   ❌ Refuser               │ │
│  └───────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
```

### ❌ Résultat du Scan - Ticket Invalide

```
┌─────────────────────────────────┐
│       ❌ TICKET INVALIDE        │
├─────────────────────────────────┤
│                                 │
│  ⚠️ Raison du refus :          │
│  ┌───────────────────────────┐ │
│  │ Ce ticket a déjà été      │ │
│  │ utilisé le 15/01/2026     │ │
│  │ à 14:05                    │ │
│  └───────────────────────────┘ │
│                                 │
│  Référence : TKT-2026-00456    │
│                                 │
│  ┌───────────────────────────┐ │
│  │   📷 Scanner un autre     │ │
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │   📞 Contacter support    │ │
│  └───────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
```

### ⚠️ Codes d'Erreur Possibles

| Code | Signification | Action |
|------|--------------|--------|
| **INVALID_TICKET** | Ticket non reconnu | Vérifier le QR code |
| **ALREADY_VALIDATED** | Déjà embarqué | Refuser l'embarquement |
| **EXPIRED_TICKET** | Ticket expiré | Orienter vers guichet |
| **WRONG_TRIP** | Mauvais voyage | Vérifier le voyage |
| **CANCELLED** | Ticket annulé | Refuser, orienter vers guichet |

---

## 6. Validation des Tickets

### ✅ Valider un Embarquement

Après un scan réussi :

1. **Vérifiez** les informations affichées
2. **Confirmez** visuellement l'identité du passager (si besoin)
3. Appuyez sur **"Valider Embarquement"**
4. Le passager peut maintenant embarquer

### 🔄 Synchronisation

- En **mode connecté** : La validation est envoyée immédiatement
- En **mode hors ligne** : La validation est stockée localement et synchronisée dès que possible

### 📝 Informations à Vérifier

Avant de valider, assurez-vous que :

| Élément | Vérification |
|---------|--------------|
| **Nom** | Correspond au passager |
| **Voyage** | Correspond à votre bus |
| **Date/Heure** | Correspond au départ |
| **Statut** | Ticket non utilisé |

### ❓ Cas Particuliers

#### Ticket pour un Tiers
Si le ticket a été acheté pour une autre personne :
- Le nom affiché est celui du **bénéficiaire** (pas de l'acheteur)
- Vérifiez l'identité du bénéficiaire

#### Ticket Partagé
Si le ticket a été partagé :
- Le QR code reste valide
- Seul le premier scan validé compte

---

## 7. Consultation des Voyages

### 📋 Liste des Voyages

Accédez à vos voyages assignés :

```
┌─────────────────────────────────┐
│          📋 Mes Voyages         │
├─────────────────────────────────┤
│                                 │
│  Aujourd'hui                    │
│  ─────────────────────────────  │
│                                 │
│  ┌───────────────────────────┐ │
│  │ 🟢 EN COURS               │ │
│  │ Dakar → Thiès             │ │
│  │ 🕐 14:00 | Bus: DK-1234   │ │
│  │ 👥 32/50 embarqués        │ │
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │ 🔵 PROGRAMMÉ              │ │
│  │ Dakar → Saint-Louis       │ │
│  │ 🕐 18:00 | Bus: DK-5678   │ │
│  │ 👥 45/55 réservés         │ │
│  └───────────────────────────┘ │
│                                 │
│  Demain                         │
│  ─────────────────────────────  │
│                                 │
│  ┌───────────────────────────┐ │
│  │ 🔵 PROGRAMMÉ              │ │
│  │ Dakar → Kaolack           │ │
│  │ 🕐 08:00 | Bus: DK-9012   │ │
│  │ 👥 28/50 réservés         │ │
│  └───────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
```

### 🔍 Détail d'un Voyage

Appuyez sur un voyage pour voir les détails :

```
┌─────────────────────────────────┐
│    Dakar → Thiès               │
│    16 Janvier 2026 - 14:00     │
├─────────────────────────────────┤
│                                 │
│  Informations                   │
│  ┌───────────────────────────┐ │
│  │ 🚌 Bus : DK-1234          │ │
│  │ 🧑‍✈️ Chauffeur : Moussa    │ │
│  │ 💺 Capacité : 50 places   │ │
│  │ 💰 Prix : 3 500 FCFA      │ │
│  └───────────────────────────┘ │
│                                 │
│  Statistiques                   │
│  ┌───────────────────────────┐ │
│  │ 📊 Réservations : 45      │ │
│  │ ✅ Embarqués : 32         │ │
│  │ ⏳ En attente : 13        │ │
│  │ ❌ Non présentés : 0      │ │
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │   👥 LISTE DES PASSAGERS  │ │
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │   📷 SCANNER TICKETS      │ │
│  └───────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
```

### 📊 Indicateurs de Statut

| Couleur | Statut | Description |
|---------|--------|-------------|
| 🟢 Vert | EN COURS | Embarquement actif |
| 🔵 Bleu | PROGRAMMÉ | Voyage à venir |
| 🟡 Jaune | EN ATTENTE | Départ imminent |
| ⚪ Gris | TERMINÉ | Voyage effectué |
| 🔴 Rouge | ANNULÉ | Voyage annulé |

---

## 8. Gestion des Passagers

### 👥 Liste des Passagers

Consultez tous les passagers d'un voyage :

```
┌─────────────────────────────────┐
│    👥 Passagers - Dakar→Thiès  │
│    32/50 embarqués              │
├─────────────────────────────────┤
│  🔍 Rechercher...               │
├─────────────────────────────────┤
│                                 │
│  ┌───────────────────────────┐ │
│  │ ✅ Fatou DIALLO           │ │
│  │    Siège 15 | Embarqué    │ │
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │ ✅ Amadou FALL            │ │
│  │    Siège 16 | Embarqué    │ │
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │ ⏳ Ibrahima DIOP          │ │
│  │    Siège 17 | En attente  │ │
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │ ⏳ Marie SECK             │ │
│  │    Siège 18 | En attente  │ │
│  └───────────────────────────┘ │
│                                 │
│  ... 28 autres passagers        │
│                                 │
└─────────────────────────────────┘
```

### 🔍 Recherche de Passager

Vous pouvez rechercher un passager par :
- **Nom** ou prénom
- **Numéro de téléphone**
- **Numéro de ticket**
- **Numéro de siège**

### 📋 Filtres Disponibles

- **Tous** : Affiche tous les passagers
- **Embarqués** : Passagers déjà validés
- **En attente** : Passagers pas encore embarqués
- **Non présentés** : Passagers absents après le départ

### 👤 Détail d'un Passager

Appuyez sur un passager pour voir ses informations :

```
┌─────────────────────────────────┐
│         👤 Fatou DIALLO         │
├─────────────────────────────────┤
│                                 │
│  Contact                        │
│  ┌───────────────────────────┐ │
│  │ 📱 77 234 56 78           │ │
│  │ ✉️ fatou@email.com        │ │
│  └───────────────────────────┘ │
│                                 │
│  Réservation                    │
│  ┌───────────────────────────┐ │
│  │ 🎫 TKT-2026-00456         │ │
│  │ 💺 Siège N°15             │ │
│  │ 💰 3 500 FCFA (Payé)      │ │
│  │ 📅 Réservé le 14/01/2026  │ │
│  └───────────────────────────┘ │
│                                 │
│  Statut                         │
│  ┌───────────────────────────┐ │
│  │ ✅ Embarqué à 13:55       │ │
│  │ 👤 Par: Agent Amadou      │ │
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │   📞 Appeler le passager  │ │
│  └───────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
```

---

## 9. Mode Hors Ligne

### 📴 Fonctionnement Sans Internet

L'application fonctionne même sans connexion :

#### ✅ Fonctionnalités Disponibles Hors Ligne
- Scanner les tickets
- Valider les embarquements
- Consulter la liste des passagers (préchargée)
- Voir les détails des voyages

#### ❌ Fonctionnalités Nécessitant Internet
- Synchronisation des nouvelles réservations
- Mise à jour des statistiques globales
- Réception des alertes en temps réel

### 🔄 Synchronisation

```
┌─────────────────────────────────┐
│      🔄 Synchronisation         │
├─────────────────────────────────┤
│                                 │
│  ⏳ 5 validations en attente    │
│                                 │
│  ┌───────────────────────────┐ │
│  │ 📤 Synchroniser maintenant│ │
│  └───────────────────────────┘ │
│                                 │
│  Dernière sync : 14:30          │
│                                 │
│  ✅ TKT-00456 - Envoyé          │
│  ✅ TKT-00457 - Envoyé          │
│  ⏳ TKT-00458 - En attente      │
│  ⏳ TKT-00459 - En attente      │
│  ⏳ TKT-00460 - En attente      │
│                                 │
└─────────────────────────────────┘
```

### 💡 Indicateurs de Connexion

| Icône | Statut |
|-------|--------|
| 🟢 | Connecté, synchronisé |
| 🟡 | Connecté, sync en cours |
| 🔴 | Hors ligne, données en attente |

### ⚠️ Important

> Les validations hors ligne sont stockées localement et envoyées automatiquement dès que la connexion est rétablie. **Ne supprimez pas l'application** avant synchronisation complète.

---

## 10. Résolution des Problèmes

### 🔧 Problèmes Courants

#### Le scanner ne fonctionne pas

1. Vérifiez que la **caméra est autorisée** dans les paramètres
2. **Nettoyez** l'objectif de la caméra
3. **Redémarrez** l'application
4. Si le problème persiste, **redémarrez** le téléphone

#### QR Code non reconnu

1. Assurez-vous que le QR code est **bien visible** et non endommagé
2. Activez la **lampe torche** si l'éclairage est faible
3. Essayez de **zoomer** sur le code
4. Demandez au passager de **régler la luminosité** de son écran

#### Connexion impossible

1. Vérifiez votre **connexion internet**
2. Vérifiez que vos **identifiants** sont corrects
3. Essayez de vous connecter en **WiFi**
4. Contactez votre responsable si le problème persiste

#### Synchronisation bloquée

1. Vérifiez votre **connexion internet**
2. Appuyez sur "**Synchroniser maintenant**"
3. Si ça persiste, allez dans **Paramètres > Forcer la synchronisation**
4. En dernier recours, contactez le support

### 🔄 Réinitialisation

Si l'application ne fonctionne plus correctement :

1. Allez dans **Paramètres > À propos**
2. Appuyez sur "**Réinitialiser l'application**"
3. **Reconnectez-vous** avec vos identifiants

> ⚠️ **Attention** : La réinitialisation supprime les données locales. Assurez-vous d'avoir synchronisé avant.

---

## 11. Bonnes Pratiques

### ✅ Avant l'Embarquement

1. **Connectez-vous** à l'application 30 min avant le départ
2. **Vérifiez** que votre voyage est bien affiché
3. **Synchronisez** les données (tirez vers le bas sur l'écran d'accueil)
4. **Testez** le scanner avec un ticket existant

### ✅ Pendant l'Embarquement

1. **Scannez** chaque ticket individuellement
2. **Vérifiez** les informations avant validation
3. **Validez** rapidement pour fluidifier l'embarquement
4. En cas de doute, **consultez** la liste des passagers

### ✅ Après l'Embarquement

1. **Vérifiez** le nombre de passagers embarqués
2. **Synchronisez** les dernières validations
3. **Signalez** les passagers non présentés
4. **Clôturez** le voyage si demandé

### 🚫 À Éviter

- ❌ Ne validez **jamais** sans scanner
- ❌ Ne laissez pas embarquer un **ticket invalide**
- ❌ Ne partagez **jamais** vos identifiants
- ❌ Ne supprimez pas l'application **sans synchroniser**

---

## 12. FAQ

### Q: Puis-je utiliser l'application sur plusieurs téléphones ?

**R**: Non, votre compte est lié à un seul appareil pour des raisons de sécurité. Contactez votre responsable pour changer d'appareil.

---

### Q: Que faire si le passager a perdu son ticket ?

**R**: 
1. Demandez son **nom complet** et **numéro de téléphone**
2. Recherchez-le dans la **liste des passagers**
3. Si trouvé, vous pouvez valider manuellement depuis sa fiche
4. Sinon, orientez-le vers le **guichet**

---

### Q: Le ticket est valide mais le voyage est différent ?

**R**: Le passager s'est trompé de bus. Orientez-le vers le bon bus ou le guichet pour modifier sa réservation.

---

### Q: Comment gérer un ticket déjà validé ?

**R**: 
1. Vérifiez l'**heure de validation** précédente
2. Si c'est une erreur, contactez votre **responsable**
3. Le passager ne peut pas embarquer deux fois

---

### Q: Que faire en cas de surréservation ?

**R**: 
1. La surréservation n'est normalement pas possible
2. Si cela arrive, contactez immédiatement votre **responsable**
3. Suivez les instructions de la direction

---

### Q: Puis-je valider après le départ du bus ?

**R**: Non, les validations sont bloquées après le départ. Les passagers non embarqués seront marqués comme "non présentés".

---

### Q: Comment signaler un problème technique ?

**R**: 
1. Allez dans **Paramètres > Signaler un problème**
2. Décrivez le problème en détail
3. L'équipe technique sera notifiée

---

### Q: L'application consomme-t-elle beaucoup de batterie ?

**R**: L'application est optimisée pour économiser la batterie. Le scanner ne s'active que pendant l'utilisation. Pour les longues sessions, prévoyez une batterie externe.

---

## 13. Contact Support

### 📞 Assistance Technique

**Horaires** : Lundi - Samedi, 7h - 22h

| Canal | Contact |
|-------|---------|
| 📱 Téléphone | +221 33 XXX XX XX |
| 📧 Email | support-agent@transport.sn |
| 💬 WhatsApp | +221 77 XXX XX XX |

### 🆘 Urgences

Pour les urgences pendant un embarquement :
- Contactez votre **responsable direct**
- Ligne d'urgence : **+221 70 XXX XX XX** (24h/24)

### 📋 Informations à Fournir

Lors d'un signalement, préparez :
- Votre **nom** et **numéro d'agent**
- Le **voyage concerné** (trajet, date, heure)
- Une **capture d'écran** si possible
- La **description précise** du problème

---

## Annexes

### A. Glossaire

| Terme | Définition |
|-------|------------|
| **QR Code** | Code-barres 2D contenant les infos du ticket |
| **Validation** | Action de confirmer l'embarquement d'un passager |
| **Synchronisation** | Envoi des données vers le serveur |
| **Ticket tiers** | Ticket acheté pour une autre personne |

### B. Raccourcis Clavier (Tablettes)

| Raccourci | Action |
|-----------|--------|
| **Entrée** | Valider |
| **Échap** | Annuler |
| **F5** | Rafraîchir |
| **Ctrl+F** | Rechercher |

### C. Versions de l'Application

| Version | Date | Nouveautés |
|---------|------|------------|
| 1.1 | Jan 2026 | Mode hors ligne amélioré, nouveaux indicateurs |
| 1.0 | Déc 2025 | Version initiale |

---

**Bonne utilisation de l'application Agent d'Embarquement !** 🚌

*Ce guide est la propriété de [Compagnie de Transport]. Toute reproduction est interdite.*

*Dernière mise à jour : Janvier 2026 - Version 1.1*
