# Borno Pulse — Official Bilingual Website

This directory contains the production-grade, bilingual (English & Bengali) public website for **[Borno Pulse](https://github.com/kazinayeem/Borno-Pulse)**, engineered in React 19, TypeScript, Vite, and Tailwind CSS.

---

## 🌟 Architecture & Features

- **Framework**: React 19 + TypeScript + Vite.
- **Styling**: Tailwind CSS v4 with custom macOS-inspired frosted glassmorphism and Apple aesthetics.
- **Bilingual Engine**: Complete English (`en`) and Bengali (`bn`) localization with instant runtime switching, `localStorage` persistence, and HTML `lang` synchronization.
- **Client Routing**: React Router (`HashRouter`) providing full static hosting compatibility across GitHub Pages, Cloudflare Pages, Netlify, and static CDNs without 404s on page refresh.
- **Interactive Screenshot Gallery**: Over 80 authentic application screenshots categorized by telemetry, developer tools, file utilities, settings, and menu bar widget states, with Light/Dark theme switching and a keyboard-accessible modal lightbox.
- **Privacy First**: Zero trackers, zero analytics SDKs, zero cookies, and zero user data collection.

---

## 📁 Directory Structure

```text
website/
├── public/                  # Static assets
│   ├── app-icon.png         # High-resolution Borno Pulse icon
│   ├── favicon.png          # Browser favicon
│   ├── developer_avatar.png # Founder profile photo
│   ├── robots.txt           # Search engine crawlers policy
│   ├── sitemap.xml          # SEO sitemap
│   └── screenshots/         # 80+ Real application screenshots
│       ├── light/           # Light mode app screens
│       ├── dark/            # Dark mode app screens
│       └── widget/          # Menu bar popover states
├── src/
│   ├── components/          # Navbar, Footer, Lightbox, Icons
│   ├── context/             # LanguageProvider & useLanguage hook
│   ├── data/                # Features & Screenshots inventories
│   ├── i18n/                # English & Bengali dictionaries
│   ├── pages/               # Home, Features, Screenshots, Download, Docs, Contributing, Privacy, FAQ
│   ├── types/               # TypeScript definitions
│   ├── App.tsx              # Application shell with routes
│   └── main.tsx             # Entry point
```

---

## 🚀 Local Development

```bash
# 1. Install dependencies
cd website
npm install

# 2. Run local development server
npm run dev

# 3. Build optimized static production bundle
npm run build

# 4. Preview production build locally
npm run preview
```

---

## 🚢 Static Deployment

The generated `website/dist/` directory is completely standalone and ready for static hosting:
- **GitHub Pages**: Deploy contents of `website/dist/` to the `gh-pages` branch.
- **Vercel / Netlify / Cloudflare Pages**: Set build directory to `website` and output directory to `dist`.

---

## 📄 License & Attribution

- **Author**: Mohammad Ali Nayeem ([@kazinayeem](https://github.com/kazinayeem))
- **Organization**: [BornoSoft](https://bornosoft.bd)
- **License**: MIT License
