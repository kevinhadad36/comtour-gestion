# COMTOUR GESTION

Application web responsive React + TypeScript, conçue pour GitHub Pages et une base Supabase privée.

## Préparation locale

1. `npm ci`
2. Copier `.env.example` vers `.env.local` et renseigner `VITE_SUPABASE_URL` et `VITE_SUPABASE_PUBLISHABLE_KEY` (clé publique uniquement).
3. Exécuter `supabase/schema.sql` dans l’éditeur SQL Supabase. Le schéma comprend le catalogue des services.
4. Créer le premier compte dans Supabase Auth, puis ajouter sa ligne `profiles` avec le rôle `admin` (instruction SQL en fin de schéma).
5. `npm run dev`

Sans configuration Supabase, l’application affiche une page de configuration et ne fabrique pas de chiffres de production. Les accès nécessitent une session Supabase Auth. Les opérations et pièces financières restent sur le backend.

Pour un projet Supabase déjà initialisé avec une version antérieure du schéma, exécuter aussi `supabase/migrations/20261031_catalogue_services.sql`. Le module **Catalogue** permet aux profils administrateur et responsable administratif d’ajouter, modifier, archiver ou réactiver les services, avec catégories, unité de facturation et tarifs en KMF ou EUR.

## Déploiement GitHub Pages

Créer le dépôt public `comtour-gestion` sous le compte GitHub `comtour-gestion`, publier la branche `main`, puis ajouter dans Settings → Secrets and variables → Actions → Variables :

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_PUBLISHABLE_KEY`

Dans Settings → Pages, choisir **GitHub Actions** comme source. Le workflow `.github/workflows/deploy.yml` construit et publie automatiquement à chaque push sur `main`. Pour l’adresse `https://comtour-gestion.github.io/`, le dépôt doit être le dépôt Pages racine de l’organisation/compte `comtour-gestion`.

La clé publishable Supabase est une clé cliente, pas un secret d’administration. Elle est visible dans le bundle. La sécurité dépend de RLS et des rôles; ne jamais mettre une clé `service_role` dans GitHub Actions frontend, le dépôt ou le code client. Les variables `VITE_*` sont incorporées au JavaScript public.

## Données, sécurité et sauvegardes

- Activer la confirmation d’adresse e-mail et MFA pour les comptes administrateurs dans Supabase Auth.
- Les tables applicatives activent RLS; l’accès exige un utilisateur authentifié muni d’un profil ComTour. Les écritures sont historisées dans `audit_log`.
- Utiliser les sauvegardes automatiques / PITR du plan Supabase retenu; exporter régulièrement une sauvegarde chiffrée hors du projet. Tester périodiquement une restauration dans un projet isolé. Le forfait et la rétention sont définis par Supabase et peuvent évoluer.
- Ne stocker les justificatifs que dans un bucket privé Supabase Storage avec politiques RLS; aucun bucket public n’est configuré par défaut.

## Portée de cette première version

La base de l’interface, l’authentification, les listes/créations simples pour les principaux registres, la PWA, les politiques SQL initiales et le pipeline Pages sont fournis. Les cycles métier complets (lignes de devis, génération PDF, paiements/réconciliation, clôture financière, gestion de pièces jointes, permissions fines par action, exports et rapports) nécessitent encore leur implémentation avant un usage opérationnel. L’application n’est pas encore déployée : les identifiants Supabase, le dépôt GitHub, le domaine et les politiques de sauvegarde doivent être configurés par le propriétaire.
