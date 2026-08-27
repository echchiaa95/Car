# Phase 4.2 — Déploiement Guard sur le projet Supabase `school-management`

Ce dossier contient uniquement ce qui est nécessaire pour déployer **Phase 4 (guard_checks)** sur un projet Supabase réel. Rien d'autre n'est touché : le schéma de Phase 2 et les migrations Phase 3.2/3.3/3.4 sont des **prérequis vérifiés**, jamais modifiés.

**Aucune opération destructive** (`DROP TABLE`, `DROP POLICY`, `DROP FUNCTION`, `TRUNCATE`) n'est présente dans ce dossier.

---

## Avant de commencer

Le schéma complet de Phase 2 (`schools`, `students`, `profiles`, `user_roles`, etc.) et les migrations Phase 3.2 → 3.4 (Auth PIN/QR) doivent déjà être appliqués sur ce projet Supabase. Si ce n'est pas encore le cas, appliquez-les d'abord (elles ne sont pas répétées dans ce dossier).

---

## ÉTAPE 1 — Preflight

**Quoi copier** : tout le contenu de `00_preflight.sql`.
**Où le coller** : Supabase Dashboard → votre projet `school-management` → **SQL Editor** → New query → coller → Run.
**Quoi attendre** : un tableau de résultats, une ligne par vérification, colonne `status`. **Toutes les lignes doivent afficher `OK`.**
**En cas d'erreur** : si une ligne affiche `MISSING`, c'est qu'une migration précédente (Phase 2 ou Phase 3.x) n'a pas été appliquée sur ce projet. Ne passez pas à l'étape 2 — appliquez d'abord la migration manquante correspondante.

---

## ÉTAPE 2 — Installation

**Condition** : uniquement si l'étape 1 est entièrement `OK`.
**Quoi copier** : tout le contenu de `01_phase4_guard_checks.sql`.
**Où le coller** : même endroit (SQL Editor → New query).
**Quoi attendre** : `Success. No rows returned.` C'est normal — ce script crée une table, des index et des policies, il ne retourne pas de données.
**En cas d'erreur** : notez le message d'erreur exact. Ce script est conçu pour être rejouable sans risque (`IF NOT EXISTS` partout où c'est possible) — une erreur signifie généralement qu'une dépendance de l'étape 1 a changé entre-temps. Relancez `00_preflight.sql` pour confirmer.

---

## ÉTAPE 3 — Vérification post-déploiement

**Quoi copier** : tout le contenu de `02_verify_phase4.sql`.
**Où le coller** : SQL Editor → New query.
**Quoi attendre** : plusieurs tableaux (sections A à G). **Chaque ligne `status` doit afficher `OK`.**
**En cas d'erreur** : si une section affiche `FAIL`, la table ou ses policies ne correspondent pas à ce qui est attendu — ne passez pas à l'étape 4. Le détail de la ligne en échec indique précisément quoi corriger (colonne manquante, policy manquante, etc.).

---

## ÉTAPE 4 — Créer/identifier les comptes de test (manuel, obligatoire)

Ce projet **ne crée jamais de compte Supabase Auth depuis du SQL** (règle de sécurité du projet). Vous devez créer deux comptes manuellement :

1. Dashboard → **Authentication** → **Users** → **Add user**.
   - Créez un utilisateur pour "Guard A" (n'importe quel email/mot de passe, ex. `guard-a-test@example.com`).
   - Créez un second utilisateur pour "Guard B" (ex. `guard-b-test@example.com`).
2. Dans la table **Users**, copiez l'**UUID** de chacun (colonne `UID` ou `id`).
3. Gardez ces deux UUID sous la main pour l'étape suivante.

---

## ÉTAPE 5 — Préparer les données de test

**Quoi copier** : `05_test_data.sql`, **Partie 1** d'abord (aucune modification nécessaire, copiable telle quelle).
**Où le coller** : SQL Editor → Run.
**Quoi attendre** : `Success`. Cela crée École Test A / École Test B, un élève et un badge dans chacune.

Ensuite, **Partie 2** du même fichier :
- Remplacez `REPLACE_WITH_GUARD_A_AUTH_UID` par l'UUID réel de Guard A (étape 4).
- Remplacez `REPLACE_WITH_GUARD_B_AUTH_UID` par l'UUID réel de Guard B.
- Collez et exécutez.
**Quoi attendre** : `Success`. Si vous obtenez une erreur `invalid input syntax for type uuid`, c'est que vous avez oublié de remplacer un des deux placeholders — c'est volontaire, pour éviter une insertion accidentelle avec de fausses valeurs.

Pour que Guard A/B puissent réellement se connecter à l'app depuis un téléphone (PIN + numéro), exécutez aussi les 4 lignes en commentaire à la fin de `05_test_data.sql` (elles réutilisent `fn_set_user_pin`, déjà existante depuis Phase 3.3 — aucune nouveauté).

---

## ÉTAPE 6 — Tester depuis le téléphone (GitHub Pages)

1. Ouvrez l'app déployée sur GitHub Pages.
2. Connectez-vous avec le `user_number` + PIN de Guard A (ex. `90001` / `1357`).
3. Onglet "التلاميذ" → chercher `TEST-A-001` → doit apparaître.
4. Chercher `TEST-B-001` → ne doit **rien** retourner.
5. Déconnexion ("استخدام حساب آخر"), reconnexion avec Guard B (`90002` / `2468`).
6. Répétez symétriquement.

Le détail complet, avec les 8 scénarios exacts à vérifier (y compris les tentatives d'écriture interdites), est dans **`06_rls_test_plan.md`**.

---

## ÉTAPE 7 — Vérifier `guard_checks`

Après quelques scans/recherches côté Guard A et Guard B, dans SQL Editor :
```sql
select school_id, checked_by, method, result, created_at
from guard_checks
order by created_at desc
limit 20;
```
**Quoi attendre** : une ligne par contrôle effectué, avec le bon `school_id` et le bon `checked_by` pour chaque guard — jamais les deux mélangés pour un même contrôle.

---

## Confirmation

- **Phase 3.4 inchangée** : ce dossier n'ajoute ni ne modifie aucun fichier de Phase 3.4 (Auth/PIN/QR/session/remembered-device). Vérifié par diff complet — voir le rapport final.
- **Aucune opération destructive incluse** : aucun `DROP TABLE`, `DROP POLICY`, `DROP FUNCTION`, ni `TRUNCATE` dans l'ensemble de ce dossier.
