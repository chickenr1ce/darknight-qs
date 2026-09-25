# 07: Dashboard placeholders plus final layout

**What to build:** The dashboard gains its remaining blocks as fixed placeholders with no network calls and no secrets. Weather stub, GPU stub, Spotify Connect device list inside the player block with phone plus PC entries, and theme picker stub. Final block order follows the reference picture stored beside the spec with volume stretching into freed calendar space and palette tokens throughout.

**Blocked by:** 06 Dashboard live blocks

**Status:** ready-for-agent

- [ ] Order from top is weather plus fastfetch plus CPU RAM plus volume plus player with Spotify devices inside, calendar dropped
- [ ] Weather plus GPU plus Spotify switch plus theme picker render fixed stub content and fire no network traffic
- [ ] Block styling matches the reference picture layout with palette tokens only and no reference cream or peach
- [ ] Layout holds at dashboard width with no overlap and no clipping
- [ ] Type lint plus review lint gates pass and sight verification runs on a test instance
