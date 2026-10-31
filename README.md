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

Pour une base neuve, exécuter `supabase/schema.sql` dans SQL Editor. Pour une base déjà initialisée, appliquer `supabase/migrations/20261031_catalogue_services.sql`. L’accès aux données métier exige une session authentifiée et un profil ComTour; les tables activent RLS. Créer le premier utilisateur admin selon l’instruction en fin de schéma.

## Déploiement GitHub Pages

Le workflow `.github/workflows/deploy.yml` construit le site pour le chemin du dépôt et le déploie sur `https://kevinhadad36.github.io/comtour-gestion/` après chaque push sur `main`. Dans Settings → Secrets and variables → Actions → Variables, ajouter `VITE_SUPABASE_URL` et `VITE_SUPABASE_PUBLISHABLE_KEY`.

La clé publishable Supabase est intégrée au JavaScript du navigateur et n’est pas une clé secrète. La protection repose sur RLS et les rôles. N’exposez jamais une clé `service_role` dans le frontend ou dans GitHub Pages.

## Sauvegardes

Configurer les sauvegardes/PITR adaptées au plan Supabase, conserver aussi des exports chiffrés hors du projet et tester les restaurations. La rétention et la disponibilité varient selon le forfait Supabase.

## État de la version

Le dépôt comprend la structure frontend, l’authentification, le catalogue de services, les premiers écrans de gestion, le schéma SQL et le workflow Pages. Les cycles complets de facturation, paiements, rapprochement, documents PDF, clôture financière, rapports et exports doivent encore être développés avant un usage opérationnel.
