# In-page arcade

Five original games run directly in the root `index.html`, using Canvas and
vanilla JavaScript. They do not load external game scripts, assets, or iframes.
All graphics are drawn in code. No build step, downloads, or game accounts are
required. These are original alternatives, not copies of the branded games
previously linked in the catalog.

| Game | Play | Controls |
| --- | --- | --- |
| Neon Rush | Dodge lane barriers, jump, collect rings | Left/Right or A/D; Up/W/Space to jump |
| Ruins Runner | Clear fallen stones and gaps | Up/W/Space or Jump button |
| Pulse Jump | Time cube jumps over spikes | Up/W/Space or Jump button |
| Pixel Crossing | Cross traffic and reach the far bank | Arrow keys or WASD; on-screen direction buttons |
| Vector Slope | Steer a ball through a winding course | Hold Left/Right or A/D; hold on-screen steering buttons |

Each game includes Start, Pause, Restart, score, and session-best controls.
P pauses/resumes; R restarts. Switching away from the window pauses gameplay.
Closing the theater cancels its animation loop. Scores are kept only in memory
and reset on page reload. The application uses no localStorage, sessionStorage,
or cookies.

Roblox remains an explicitly labeled external app because it requires its own
website/client. Its launcher is separate from the five in-page games.

## Site controls

Enter **1313** and press **Enter** or **=** to open the dashboard. The code is a
view switch, not authentication. The calculator, four tab presets, about:blank
launcher, Panic controls, browser, and session lock remain available.

The about:blank launcher opens a full-window iframe, then replaces the original
tab's current history entry. It does not erase browser/network records or bypass
external sites' embedding policies. Escape/tilde work while these original games
have focus because they run in the parent document. They cannot be captured from
an unrelated cross-origin iframe; use the visible Panic button there.

## Implementation and verification

The root file contains the GAMES catalog and createArcade engine. This folder is
reserved for future game files; it is not a runtime dependency. The five games
share a bounded simulation loop and input lifecycle while using separate game
rules and artwork.

Validation: 30 calculator/dashboard DOM interaction checks plus 32 game checks
cover launch, input, collisions, scoring, pause/retry, touch steering, lifecycle,
and reset behavior. Native software Canvas rendered all five scenes for visual
inspection. Full browser layout and device interaction were not verified because
the managed browser-control tool was unavailable.

Publish the repository root through GitHub Pages; no build configuration is needed.
