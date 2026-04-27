import { defineConfig } from "vite"
import { resolve } from "path"
import ViteRails from "vite-plugin-rails"


export default defineConfig({
  resolve: {
    alias: {
      "@node_modules": resolve(__dirname, "node_modules"),
    }
  },
  plugins: [
    ViteRails()
  ],
})
