# ChromieTransmog

Transmog overlay addon for ChromieCraft.

Talk to Warpweaver to open a full preview UI instead of the default gossip/vendor list.

Based on Stefan2102/mod-transmog-plus, adapted for azerothcore/mod-transmog (gossip/vendor), not the plus addon protocol.

Features
--------
- Overlay transmog window with a 3D paperdoll (pending looks before you pay)
- Click a slot to browse unlocked appearances; apply, hide, or revert
- Warpweaver sets: save, apply, delete (server limit 10)
- Home tab: last 4 used sets with 3D previews and Apply Set
- Cache tab: appearance unlock cache per equipped item; drop cache if previews look wrong
- Character info and inspect screen equipped items show the original item icon (no more empty icons for hidden items); tooltips show Transmogrified names
- Per-character cache (`ChromieTransmogDB`)
- `/ct on` / `/ct off` (also `/ctm`, `/chromietransmog`) to use this UI or the original NPC window

Notes
-----
- Stay in gossip mode (`.t i off`). Vendor item list (`.t i on`) is not supported for browsing/applying. The addon will notify you of this.
- Home set previews need each set cached once (apply the set with the window open).
- Incomplete cache can make the dummy look wrong until you scan those slots on the Cache tab.

Screenshots
--------

<p align="center">
  <img width="826" height="692" alt="image" src="" />
  <br>
  <em>Home tab: last used sets with 3D previews, Apply Set, and cache status</em>
</p>

<br>

<p align="center">
  <img width="826" height="692" alt="image" src="" />
  <br>
  <em>Slot appearance grid and left-side paperdoll preview</em>
</p>

<br>

<p align="center">
  <img width="587" height="338" alt="image" src="" />
  <br>
  <em>Sets tab: Warpweaver set list, save, apply, delete</em>
</p>

<br>

<p align="center">
  <img width="587" height="338" alt="image" src="" />
  <br>
  <em>Cache tab: per-slot unlock status and Drop cache</em>
</p>

<br>

<p align="center">
  <img width="446" height="80" alt="image" src="" />
  <br>
  <em>Character sheet tooltip: Transmogrified appearance name</em>
</p>
