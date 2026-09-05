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
- Optional "You haven't collected this appearance" on item tooltips (Settings; account-wide after Warpweaver scans)
- Per-character cache (`ChromieTransmogDB`)
- `/ct on` / `/ct off` (also `/ctm`, `/chromietransmog`) to use this UI or the original NPC window

UI fixes
--------
- Character and inspect slot icons show the original item (no empty icons for hidden transmogs)
- Tooltips show the Transmogrified appearance name
- Set bonuses in tooltips stay correct while transmogged (count and green/grey bonus lines; 10/25 variants mix, e.g. Heroes'/Valorous)

Notes
-----
- Stay in gossip mode (`.t i off`). Vendor item list (`.t i on`) is not supported for browsing/applying. The addon will notify you of this.
- Home set previews need each set cached once (apply the set with the window open).
- Incomplete cache can make the dummy look wrong until you scan those slots on the Cache tab.
- Not-collected tooltips are wrong for a slot/type until that type is scanned at a Warpweaver.

Screenshots
--------

<p align="center">
  <img width="932" height="637" alt="image" src="https://github.com/user-attachments/assets/02efd2c6-80ba-4213-8815-fd44cdeb6a40" />
  <br>
  <em>Home tab: last used sets with 3D previews, Apply Set, and cache status</em>
</p>

<br>

<p align="center">
  <img width="924" height="632" alt="image" src="https://github.com/user-attachments/assets/b41d4c9a-af68-4d2a-87d3-842d1cb1164a" />
  <br>
  <em>Slot appearance grid and left-side paperdoll preview</em>
</p>

<br>

<p align="center">
  <img width="403" height="330" alt="image" src="https://github.com/user-attachments/assets/b3bbc3bd-a560-48fb-8548-ec011477e695" />
  <br>
  <em>Character sheet tooltip and icon: Transmogrified appearance name and the icon shows the original item</em>
</p>
