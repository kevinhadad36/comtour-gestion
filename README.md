# COMTOUR GESTION

Application web responsive et installable pour la gestion de l’Agence ComTour à Moroni.

## Développement local

```bash
npm ci
cp .env.example .env.local
npm run dev
```

Renseigner les variables Supabase dans `.env.local` pour connecter le backend.

## GitHub Pages

Le workflow GitHub Actions construit l’application et la publie automatiquement sur GitHub Pages à chaque mise à jour de `main`. Configurer les variables de dépôt `VITE_SUPABASE_URL` et `VITE_SUPABASE_PUBLISHABLE_KEY` dans Settings → Secrets and variables → Actions.

Les secrets locaux `.env.local` ne doivent jamais être commités. La clé publishable est destinée au frontend; l’accès aux données doit être protégé par les politiques RLS Supabase.

La migration de schéma et du catalogue se trouve dans `supabase/`.
