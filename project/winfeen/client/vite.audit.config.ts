import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
export default defineConfig({
  plugins: [react()], base: './',
  build: { outDir: 'dist-audit', emptyOutDir: true,
    rollupOptions: { output: { format: 'iife', inlineDynamicImports: true, entryFileNames: 'audit.js' } } },
})
