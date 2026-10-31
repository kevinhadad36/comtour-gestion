# COMTOUR GESTION

Application web React + TypeScript, responsive et installable (PWA), pour l’Agence ComTour de Moroni.

## Lancer en local

```bash
npm ci
Copy-Item .env.example .env.local
npm run dev
```

Renseigner `VITE_SUPABASE_URL` et `VITE_SUPABASE_PUBLISHABLE_KEY` dans `.env.local` pour connecter Supabase. N’ajoutez jamais `.env.local`, un mot de passe de base de données ni une clé `service_role` au dépôt.

## Base Supabase

Pour une base neuve, exécuter `supabase/schema.sql`, puis appliquer dans l’ordre les migrations de `supabase/migrations/` qui ne sont pas déjà présentes. Pour l’instance ComTour existante, appliquer `20261101_workflows_finance.sql` dans l’éditeur SQL Supabase. Cette migration est additive et conserve les données métier déjà présentes. Les fonctions de devis détaillés, les bilans de mission, les charges récurrentes, les justificatifs privés et les paramètres de l’agence nécessitent cette migration. L’accès aux données métier exige une session authentifiée et un profil ComTour; les tables activent RLS.

Les justificatifs sont stockés dans un bucket privé `comtour-documents`, avec liens temporaires signés. Les reçus, devis et bilans s’ouvrent dans la boîte d’impression du navigateur et peuvent être enregistrés en PDF. Les exports tabulaires sont au format CSV UTF-8 compatible Excel.

## Déploiement GitHub Pages

Le workflow `.github/workflows/deploy.yml` construit le site pour le chemin du dépôt et le déploie sur `https://kevinhadad36.github.io/comtour-gestion/` après chaque push sur `main`. Dans Settings → Secrets and variables → Actions → Variables, ajouter `VITE_SUPABASE_URL` et `VITE_SUPABASE_PUBLISHABLE_KEY`.

La clé publishable Supabase est intégrée au JavaScript du navigateur et n’est pas une clé secrète. La protection repose sur RLS et les rôles. N’exposez jamais une clé `service_role` dans le frontend ou dans GitHub Pages.

## Sauvegardes

Configurer les sauvegardes/PITR adaptées au plan Supabase, conserver aussi des exports chiffrés hors du projet et tester les restaurations. La rétention et la disponibilité varient selon le forfait Supabase.

Les sauvegardes automatiques de base de données ne sont pas pilotées par le frontend GitHub Pages. Vérifier le plan Supabase du projet ComTour et mettre en place une copie de sauvegarde externe avant d’utiliser l’application comme registre comptable de référence.

## Parcours actuellement implémentés

- Clients, prestataires, catalogue, dépenses, paiements et charges récurrentes.
- Devis avec plusieurs prestations, frais de service, devise, taux et acompte.
- Conversion d’un devis validé en facture et en mission.
- Enregistrement des règlements, statut des factures et reçus imprimables.
- Suppléments de mission en attente d’accord client; l’accord ou le refus est tracé dans le dossier.
- Suivi financier par mission, justificatifs privés, historique d’événements, clôture/réouverture contrôlée.
- Tableau de bord et rapports financiers fondés sur les données Supabase, export CSV/Excel et impression PDF.

La migration `20261101_workflows_finance.sql` doit être exécutée dans Supabase avant d’utiliser les nouveaux parcours. La récurrence des charges est générée de façon idempotente à la première ouverture de l’application par un profil comptable ou administrateur chaque mois; une exécution planifiée indépendante du frontend reste à configurer si elle est requise.
