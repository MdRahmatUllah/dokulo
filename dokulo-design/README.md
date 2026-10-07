# Dokulo – design export

Static HTML screens exported from the Dokulo design canvas (7 Oct 2026).
Open `index.html` in a browser to browse everything.

## Structure

```
dokulo-design/
├── index.html            start page
├── assets/               shared fonts (icons + handwriting), works offline
├── light/                English, light theme
├── dark/                 English, dark theme
└── deutsch/              German, light theme (frames marked DE in §32.2)
```

Each theme folder uses the same sub-folders and file names, so
`light/02-home/home-default.html`, `dark/02-home/home-default.html` and
`deutsch/02-home/home-default.html` show the same screen.

| Folder | Content |
|---|---|
| 00-design-system | foundations, components, illustrations overview, one file per illustration ILL-01…20, motion (light only) |
| 01-onboarding … 23-paywall | phone screens, one file per state: `<screen>-<state>.html` |
| 24-tablet | tablet screens, `-landscape` (1366×1024) and `-portrait` (820×1180) |
| 25-system-surfaces | notifications, share sheet, widgets, Live Activity |
| 26-global-states | offline, errors, storage, update |
| 27-accessibility | 200 % text checks |
| 28-store-assets | app icon and store assets (light only) |

`-iphone-se` in a file name means the iPhone SE size (375×667). Phone frames are 393×852.

## Notes

- Each screen is one HTML file with its styles inside. It only shares `assets/fonts.css` and the font files, so keep the folder structure as it is.
- The files are static snapshots of each state. Links still work: a tab, tool or back button opens the matching screen file. Toggles and sheets inside a screen don't animate.
- `deutsch/` holds the screens §32.2 marks for German. Links from these screens to screens without a German version open the English light screen.
