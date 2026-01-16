# 🚌 Guide Utilisateur - Compagnies de Transport

## Transport Interurbain CI - Guide Administrateur

Ce guide est destiné aux administrateurs et gestionnaires des compagnies de transport utilisant le module **Transport Interurbain** d'Odoo.

---

## 📋 Table des matières

1. [Configuration initiale](#configuration-initiale)
2. [Gestion de la compagnie](#gestion-de-la-compagnie)
3. [Gestion des bus](#gestion-des-bus)
4. [Gestion des itinéraires](#gestion-des-itinéraires)
5. [Programmation des voyages](#programmation-des-voyages)
6. [Gestion des réservations](#gestion-des-réservations)
7. [Utilisation de l'application agent](#utilisation-de-lapplication-agent)
8. [Rapports et statistiques](#rapports-et-statistiques)
9. [Configuration avancée](#configuration-avancée)
10. [Résolution des problèmes](#résolution-des-problèmes)

---

## ⚙️ Configuration initiale

### Accès au module

1. Connectez-vous à Odoo avec vos identifiants
2. Accédez au module **Transport Interurbain** depuis le menu principal
3. Vérifiez vos droits d'accès :
   - **Utilisateur** : Accès en lecture
   - **Agent** : Gestion des réservations et embarquement
   - **Responsable** : Gestion complète de la compagnie
   - **Administrateur** : Configuration système

### Première configuration

Suivez ces étapes dans l'ordre :

1. ✅ Créer/configurer votre compagnie
2. ✅ Ajouter vos villes desservies
3. ✅ Créer vos itinéraires
4. ✅ Enregistrer vos bus
5. ✅ Programmer vos premiers voyages

---

## 🏢 Gestion de la compagnie

### Créer une compagnie

**Menu :** Configuration > Compagnies > Créer

Renseignez les informations suivantes :

| Champ | Description | Exemple |
|-------|-------------|---------|
| **Nom** | Nom commercial | Transport Express CI |
| **Téléphone** | Numéro principal | +225 01 XX XX XX XX |
| **Email** | Email de contact | contact@express-ci.com |
| **Site web** | URL du site | www.express-ci.com |
| **Logo** | Image (300x100px) | logo.png |

### Configuration des tarifs

**Onglet "Tarification" :**

- **Frais de réservation** : Montant facturé pour une réservation (ex: 500 FCFA)
- **Durée de réservation** : Temps avant expiration (ex: 24 heures)
- **Commission agent** : Pourcentage pour les agents (ex: 5%)

### Configuration des paiements

**Onglet "Paiements" :**

- ☑️ **Autoriser paiement en ligne** : Active Wave, Orange Money, etc.
- **Wave Merchant ID** : Identifiant marchand Wave
- **Clé API Wave** : Clé secrète pour l'intégration

### Contacts et adresses

Ajoutez vos agences et points de vente :

```
Menu : Configuration > Compagnies > [Votre compagnie] > Onglet "Contacts"
```

---

## 🚐 Gestion des bus

### Ajouter un bus

**Menu :** Configuration > Bus > Créer

| Champ | Description | Obligatoire |
|-------|-------------|-------------|
| **Nom/Numéro** | Identifiant interne | ✅ |
| **Immatriculation** | Plaque d'immatriculation | ✅ |
| **Compagnie** | Votre compagnie | ✅ |
| **Capacité** | Nombre de places | ✅ |
| **Type** | Standard / VIP / Mini | ✅ |

### Configuration des sièges

**Onglet "Sièges" :**

1. Cliquez sur **"Générer les sièges"**
2. Définissez la disposition :
   - Nombre de rangées
   - Configuration (2+2, 2+1, etc.)
   - Numérotation (A1, A2, B1, B2...)

### Gestion des bagages

**Onglet "Bagages" :**

- ☑️ **Gérer les bagages** : Active le suivi des bagages
- **Franchise (kg)** : Poids inclus (ex: 25 kg)
- **Prix kg supplémentaire** : Tarif excédent (ex: 500 FCFA/kg)
- **Poids max par passager** : Limite (ex: 50 kg)

### États d'un bus

| État | Description | Peut voyager |
|------|-------------|--------------|
| 🟢 **Disponible** | Prêt à opérer | ✅ |
| 🟡 **En maintenance** | Réparation en cours | ❌ |
| 🔴 **Hors service** | Indisponible | ❌ |

---

## 🛣️ Gestion des itinéraires

### Créer un itinéraire

**Menu :** Configuration > Itinéraires > Créer

**Informations de base :**

| Champ | Description |
|-------|-------------|
| **Nom** | Ex: Abidjan - Yamoussoukro |
| **Ville de départ** | Ville d'origine |
| **Ville d'arrivée** | Destination finale |
| **Distance (km)** | Distance totale |
| **Durée estimée** | Temps de trajet (heures) |
| **Prix de base** | Tarif standard |

### Ajouter des arrêts intermédiaires

**Onglet "Arrêts" :**

1. Cliquez sur **"Ajouter une ligne"**
2. Pour chaque arrêt :
   - **Ville** : Arrêt intermédiaire
   - **Séquence** : Ordre sur le trajet (1, 2, 3...)
   - **Durée depuis départ** : Temps écoulé (heures)
   - **Prix depuis départ** : Tarif partiel
   - **Prix jusqu'à arrivée** : Tarif restant

**Exemple : Abidjan → Bouaké → Yamoussoukro**

| Séquence | Ville | Durée | Prix départ | Prix arrivée |
|----------|-------|-------|-------------|--------------|
| 1 | Bouaké | 3h | 4000 FCFA | 3000 FCFA |

### Compagnies autorisées

Si l'itinéraire est partagé entre plusieurs compagnies :

**Onglet "Compagnies" :**
- Ajoutez les compagnies autorisées à opérer

---

## 📅 Programmation des voyages

### Créer un voyage

**Menu :** Voyages > Créer

**Étape 1 - Informations de base :**

| Champ | Description |
|-------|-------------|
| **Compagnie** | Votre compagnie |
| **Itinéraire** | Trajet du voyage |
| **Bus** | Véhicule assigné |
| **Date et heure de départ** | Moment du départ |

**Étape 2 - Lieu de rassemblement :**

- **Lieu** : Ex: Gare routière d'Adjamé
- **Adresse détaillée** : Informations complémentaires
- **Coordonnées GPS** : Pour la géolocalisation
- **Heure d'arrivée avant départ** : Ex: 30 minutes

**Étape 3 - Tarification :**

- **Prix standard** : Tarif adulte
- **Prix VIP** : Tarif premium
- **Prix enfant** : Tarif réduit

### Programmer le voyage

1. Cliquez sur **"Programmer"** ✅
2. Le voyage passe en état **"Programmé"**
3. Il devient visible pour les passagers

### Workflow du voyage

```
[Brouillon] → [Programmé] → [Embarquement] → [En route] → [Arrivé]
     ↓
[Annulé]
```

### Actions disponibles

| Action | Description |
|--------|-------------|
| **Programmer** | Rendre disponible à la réservation |
| **Démarrer embarquement** | Ouvrir l'embarquement des passagers |
| **Départ** | Marquer le bus comme parti |
| **Arrivée** | Confirmer l'arrivée à destination |
| **Annuler** | Annuler le voyage (notifie les passagers) |

---

## 🎫 Gestion des réservations

### Vue d'ensemble

**Menu :** Réservations

La vue liste affiche toutes les réservations avec :
- Référence du ticket
- Passager et téléphone
- Voyage et date
- Montant et paiement
- État

### Filtres rapides

Utilisez les filtres pour trouver rapidement :

- 📅 **Aujourd'hui** : Départs du jour
- ⏳ **En attente** : Non payées
- ✅ **Confirmées** : Payées
- ❌ **Annulées** : Billets annulés

### Créer une réservation (vente en agence)

1. Cliquez sur **"Créer"**
2. Sélectionnez le **voyage**
3. Renseignez le **passager** :
   - Nom complet
   - Téléphone
   - Email (optionnel)
4. Sélectionnez le **siège**
5. Choisissez le type de billet
6. Cliquez sur **"Réserver"** ou **"Confirmer"**

### États d'une réservation

| État | Description | Actions possibles |
|------|-------------|-------------------|
| 🔵 **Brouillon** | En cours de création | Réserver, Confirmer |
| 🟡 **Réservé** | En attente de paiement | Confirmer, Annuler |
| 🟢 **Confirmé** | Payé | Embarquer, Annuler |
| 🚌 **Embarqué** | Passager à bord | - |
| ✔️ **Terminé** | Voyage effectué | - |
| ❌ **Annulé** | Billet annulé | - |

### Enregistrer un paiement

1. Ouvrez la réservation
2. Allez dans l'onglet **"Paiement"**
3. Cliquez sur **"Créer un paiement"**
4. Sélectionnez :
   - **Méthode** : Espèces, Wave, etc.
   - **Montant** : Total ou partiel
5. Cliquez sur **"Valider le paiement"**

### Annuler une réservation

1. Ouvrez la réservation
2. Cliquez sur **"Annuler"** ❌
3. Confirmez l'annulation
4. Le passager est notifié automatiquement

> ⚠️ Les remboursements doivent être traités séparément selon votre politique.

---

## 📱 Utilisation de l'application agent

### Installation

L'application agent est disponible sur :
- **Android** : Google Play Store
- **iOS** : App Store

### Connexion

1. Entrez votre **email/login** Odoo
2. Entrez votre **mot de passe**
3. L'application se synchronise avec le serveur

### Scanner un ticket

1. Appuyez sur **"Scanner"** 📷
2. Pointez la caméra sur le QR code du passager
3. Le résultat s'affiche :
   - ✅ **Valide** : Informations du passager
   - ❌ **Invalide** : Message d'erreur

### Embarquer un passager

Après un scan valide :

1. Vérifiez les informations du passager
2. Vérifiez l'identité si nécessaire
3. Appuyez sur **"EMBARQUER"** ✅
4. Le ticket passe en état "Embarqué"

### Vue du voyage

L'agent peut voir :
- 📊 Nombre de passagers embarqués
- 📊 Nombre en attente
- 📊 Places disponibles
- 💰 Revenus du voyage

### Mode hors ligne

L'application fonctionne même sans connexion :
- Les tickets scannés sont mis en cache
- Synchronisation automatique au retour de la connexion

---

## 📊 Rapports et statistiques

### Tableau de bord

**Menu :** Tableau de bord

Le tableau de bord affiche :
- 📈 Ventes du jour/semaine/mois
- 🚌 Voyages à venir
- 📊 Taux de remplissage
- 💰 Revenus par itinéraire

### Statistiques des réservations

**Menu :** Statistiques > Réservations

Vues disponibles :
- **Tableau croisé (Pivot)** : Analyse multidimensionnelle
- **Graphique** : Visualisation des tendances
- **Liste** : Données détaillées

### Analyses disponibles

| Analyse | Description |
|---------|-------------|
| **Par période** | Évolution des ventes |
| **Par itinéraire** | Performance des lignes |
| **Par compagnie** | Comparaison entre compagnies |
| **Par état** | Répartition des statuts |

### Statistiques des voyages

**Menu :** Statistiques > Voyages

- **Taux de remplissage** par jour/semaine/mois
- **Revenus** par voyage
- **Performance** par bus

### Exporter les données

1. Affichez le rapport souhaité
2. Cliquez sur **"Exporter"** 📤
3. Choisissez le format :
   - 📊 **Excel** (.xlsx)
   - 📄 **CSV** (.csv)

---

## 🔧 Configuration avancée

### Paramètres du module

**Menu :** Configuration > Paramètres

| Paramètre | Description |
|-----------|-------------|
| **Quota réservations par défaut** | Limite de places vendables |
| **Délai d'annulation** | Temps minimum avant voyage |
| **Notifications SMS** | Activer/désactiver |

### Séquences automatiques

Les numéros de référence sont générés automatiquement :
- **Voyages** : TRP/2025/00001
- **Réservations** : TKT/2025/00001
- **Paiements** : PAY/2025/00001

### Droits d'accès

| Groupe | Droits |
|--------|--------|
| **Utilisateur transport** | Lecture seule |
| **Agent transport** | Réservations + embarquement |
| **Responsable transport** | Gestion complète compagnie |
| **Administrateur transport** | Configuration système |

### Notifications automatiques

Le système envoie automatiquement :
- ✅ Confirmation de réservation
- ⏰ Rappel 24h avant départ
- ❌ Notification d'annulation
- 📝 Ticket électronique

---

## 🔧 Résolution des problèmes

### Le voyage n'apparaît pas pour les passagers

**Vérifications :**
1. ✅ Le voyage est-il en état "Programmé" ?
2. ✅ Le voyage est-il "Publié sur le site" ?
3. ✅ La date de départ est-elle dans le futur ?
4. ✅ Des places sont-elles disponibles ?

### Impossible d'assigner un bus

**Causes possibles :**
- Le bus est déjà assigné à un autre voyage ce jour
- Le bus est en maintenance
- Le bus appartient à une autre compagnie

### Paiement non validé

1. Vérifiez l'état du paiement Wave/Orange Money
2. Contactez le passager pour confirmation
3. Si validé côté opérateur, créez un paiement manuel

### L'agent ne peut pas scanner

**Vérifications :**
1. ✅ Connexion internet active ?
2. ✅ Voyage en mode "Embarquement" ?
3. ✅ QR code valide et non expiré ?
4. ✅ Ticket non déjà embarqué ?

### Contact support technique

- **Email** : support@transport-ci.com
- **Téléphone** : +225 XX XX XX XX XX
- **Horaires** : Lun-Ven 8h-18h

---

## 📝 Bonnes pratiques

### Avant le voyage

1. ✅ Vérifier le bus assigné est disponible
2. ✅ Confirmer le conducteur
3. ✅ Vérifier les réservations non payées
4. ✅ Préparer la liste des passagers

### Pendant l'embarquement

1. ✅ Ouvrir l'embarquement 30 min avant
2. ✅ Scanner tous les tickets
3. ✅ Vérifier les identités si nécessaire
4. ✅ Gérer les bagages encombrants

### Après le voyage

1. ✅ Marquer le voyage comme "Arrivé"
2. ✅ Vérifier les paiements en attente
3. ✅ Consulter les statistiques
4. ✅ Traiter les réclamations éventuelles

---

## 📞 Support et formation

### Formation disponible

Nous proposons des sessions de formation :
- **En ligne** : 2h via visioconférence
- **Sur site** : Formation complète d'une journée

### Documentation supplémentaire

- 📖 Guide technique API
- 📖 Manuel d'intégration Wave
- 📖 Politique de remboursement

---

**Merci de votre confiance !**

*Module Transport Interurbain - Version 1.0*
*© 2025 - Tous droits réservés*
