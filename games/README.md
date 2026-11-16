# Games

The website remains self-contained in the root `index.html`: styles, scripts,
icons, game catalog, and launcher views are all inline. No build step is needed.
This folder is reserved for future HTML5 games you own or have permission to host.
No third-party game binaries have been copied into this repository.

## Current catalog

| Game | Website | Launch behavior |
| --- | --- | --- |
| Roblox | https://www.roblox.com | Theater launcher; direct website required |
| Subway Surfers | https://poki.com/en/g/subway-surfers | Theater launcher; direct website required |
| Temple Run 2 | https://poki.com/en/g/temple-run-2 | Theater launcher; direct website required |
| Geometry Dash | https://poki.com/en/g/geometry-dash | Theater launcher; direct website required |
| Crossy Road | https://poki.com/en/g/crossy-road | Theater launcher; direct website required |
| Slope | https://slopegame.com/ | Embedded viewer with direct/blank-window fallbacks |

All destinations responded with HTTP 200 during development. Roblox sends
`X-Frame-Options: SAMEORIGIN`. Poki restricts `frame-ancestors` to its own
approved origins. `about:blank` does not bypass those restrictions. Slope's
actual gameplay and third-party availability have not been browser-verified.

## Using the page

Open the root page, enter **1313**, then press **=** or **Enter**. Settings offers
four tab presets and a lock button. Reloading and leaving the page reset the
calculator; no application state is saved in browser storage. The passcode is
a view switch, not authentication or access control.

The Stealth buttons open a full-window iframe in `about:blank`, then replace
the original tab's current session-history entry with `https://google.com`.
A blocked popup leaves the original page open with a message. This does not
erase browsing history or network records. External sites manage their own
cookies and storage. Escape and tilde cannot be captured by the parent page
while a cross-origin iframe has keyboard focus; use the visible Panic button.

## Hosting and extending

For GitHub Pages, publish the branch containing the root `index.html` from `/`.
Merging a pull request does not configure Pages automatically.

To add an authorized local game, place its files in `games/<slug>/` and add an
entry to the inline `GAMES` array with a relative URL such as
`games/<slug>/index.html`. Omit `launchOnly` for embeddable games. Keep the
calculator and dashboard in the root file. Paths are relative so repository
Pages URLs work without a custom domain.
