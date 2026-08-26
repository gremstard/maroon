# Maroon website

Static landing page for Firebase Hosting.

## Deploy
```bash
cd website
npx firebase-tools login
npx firebase-tools init hosting   # pick/create your Firebase project; public dir: public; no SPA rewrite
npx firebase-tools deploy
```

Note on the URL: `<project-id>.web.app` comes from the Firebase **project id**,
so `maroon.web.app` needs the project id `maroon` (likely taken — try
`maroon-game`, `playmaroon`, or add a custom domain later). The BDIA studio
site lives separately at braindumpia.web.app.

Download buttons point at the GitHub **latest** release, so publishing a new
release updates the site's downloads automatically — no site redeploy needed.
