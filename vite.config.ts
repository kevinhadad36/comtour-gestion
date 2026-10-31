import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig(({ mode }) => {
  const base = mode === 'production' ? '/comtour-gestion/' : '/';
  return {
    base,
    plugins: [
      react(),
      VitePWA({
        registerType: 'autoUpdate',
        includeAssets: ['comtour.svg'],
        manifest: {
          name: 'COMTOUR GESTION',
          short_name: 'ComTour',
          description: 'Gestion de l’Agence ComTour',
          theme_color: '#102d45',
          background_color: '#f5f7f8',
          display: 'standalone',
          start_url: base,
          icons: [{ src: `${base}comtour.svg`, sizes: 'any', type: 'image/svg+xml', purpose: 'any' }],
        },
        workbox: { navigateFallback: 'index.html' },
      }),
    ],
  };
});
