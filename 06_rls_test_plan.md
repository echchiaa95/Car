# Phase 4.2 — Plan de test RLS en conditions réelles

Ce plan suppose que :
- `00_preflight.sql` est passé (tout OK),
- `01_phase4_guard_checks.sql` a été exécuté,
- `02_verify_phase4.sql` est passé (tout OK),
- `05_test_data.sql` (Parties 1 et 2) a été exécuté avec les vrais UUID des comptes Guard A / Guard B,
- Guard A et Guard B peuvent se connecter à l'app (PIN/QR configurés, voir note en fin de `05_test_data.sql`).

Aucun de ces 8 tests ne nécessite de modifier le frontend — ils se font en utilisant l'app normalement, connecté successivement en tant que Guard A puis Guard B, plus quelques vérifications directes dans Supabase SQL Editor pour les cas où l'interface ne permet pas d'observer le refus directement (INSERT/UPDATE/DELETE interdits).

---

## TEST 1 — Guard A → Élève A
**Action** : connecté en tant que Guard A, ouvrir l'onglet "التلاميذ" (Élèves) ou rechercher `TEST-A-001`.
**Attendu** : **ALLOW** — "Élève Test A" apparaît, avec sa classe `6A-TEST`.

## TEST 2 — Guard A → Élève B
**Action** : toujours connecté en tant que Guard A, rechercher `TEST-B-001` ou `Élève Test B`.
**Attendu** : **DENY / EMPTY** — aucun résultat. La RLS (`p_students_staff`) filtre par `school_id` de Guard A ; l'élève de l'École B n'existe simplement pas dans le résultat de la requête.

## TEST 3 — Guard B → Élève B
**Action** : se déconnecter, se connecter en tant que Guard B, rechercher `TEST-B-001`.
**Attendu** : **ALLOW** — "Élève Test B" apparaît.

## TEST 4 — Guard B → Élève A
**Action** : toujours connecté en tant que Guard B, rechercher `TEST-A-001`.
**Attendu** : **DENY / EMPTY** — symétrique du Test 2.

## TEST 5 — Guard A → INSERT guard_check
**Action** : connecté en tant que Guard A, scanner (ou rechercher puis ouvrir) l'Élève Test A.
**Attendu** : **ALLOW** — le contrôle apparaît immédiatement dans l'onglet "السجل" (Historique) de Guard A.
**Vérification directe (optionnelle)** dans SQL Editor :
```sql
select * from guard_checks where school_id = 'a0000000-0000-4000-a000-000000000001' order by created_at desc limit 5;
```

## TEST 6 — Guard A → `checked_by` d'un autre utilisateur
**Action** : ce cas ne peut pas être déclenché depuis l'interface normale (`modules/students.js` n'envoie jamais `checked_by`, seule la policy le fixe via `auth.uid()`). Pour le tester réellement, il faut simuler une tentative malveillante directement via l'API REST ou SQL Editor **en tant que rôle `authenticated` avec le JWT de Guard A** :
```sql
-- Exécuté dans un contexte authentifié comme Guard A (ex: via l'API REST
-- avec le token de Guard A, PAS depuis SQL Editor qui agit en superuser) :
insert into guard_checks (school_id, checked_by, method, result)
values ('a0000000-0000-4000-a000-000000000001', 'REPLACE_WITH_GUARD_B_AUTH_UID', 'manual', 'AUTHORIZED');
```
**Attendu** : **DENY** — erreur `new row violates row-level security policy` (la clause `with check (checked_by = auth.uid() ...)` rejette toute valeur différente de l'utilisateur réellement connecté).
**Note** : depuis SQL Editor classique (connecté en superuser/postgres), RLS ne s'applique pas — ce test doit passer par un contexte réellement authentifié (API REST avec le JWT du Guard, ou `set local role authenticated; set local request.jwt.claims = '...';` en SQL Editor si vous voulez simuler sans passer par l'API).

## TEST 7 — Guard A → UPDATE guard_check
**Action** : tenter, dans un contexte authentifié comme Guard A :
```sql
update guard_checks set result = 'AUTHORIZED' where id = '<id d''un guard_check de Guard A>';
```
**Attendu** : **DENY** — `0 rows affected` (ou erreur RLS selon le client), car **aucune policy UPDATE n'existe** sur `guard_checks` (confirmé par `02_verify_phase4.sql`, section D). RLS refuse par défaut toute commande sans policy correspondante.

## TEST 8 — Guard A → DELETE guard_check
**Action** : tenter, dans le même contexte :
```sql
delete from guard_checks where id = '<id d''un guard_check de Guard A>';
```
**Attendu** : **DENY** — même raison que le Test 7, aucune policy DELETE.

---

## Résumé attendu

| Test | Résultat attendu |
|---|---|
| 1 | ALLOW |
| 2 | DENY / EMPTY |
| 3 | ALLOW |
| 4 | DENY / EMPTY |
| 5 | ALLOW |
| 6 | DENY |
| 7 | DENY |
| 8 | DENY |

Si un seul de ces résultats diffère de ce qui est attendu, **ne pas continuer vers la production** — revenir à `02_verify_phase4.sql` pour identifier quelle policy est en cause.
