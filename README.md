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

UI fixes
--------
- Character and inspect slot icons show the original item (no empty icons for hidden transmogs)
- Tooltips show the Transmogrified appearance name
- Set bonuses in tooltips stay correct while transmogged (count and green/grey bonus lines; 10/25 variants mix, e.g. Heroes'/Valorous)

Notes
-----
- Home set previews need each set cached once (apply the set with the window open).
- Incomplete cache can make the dummy look wrong until you scan those slots on the Cache tab.
- Not-collected tooltips will be inaccurate for a slot/type until that type is scanned at a Warpweaver.

Screenshots
--------

<p align="center">
  <img width="932" height="637" alt="image" src="https://github.com/user-attachments/assets/02efd2c6-80ba-4213-8815-fd44cdeb6a40" />
  <br>
  <em>Home tab: last used sets with 3D previews, Apply Set, and cache status</em>
</p>

<br>

<p align="center">
  <img width="933" height="641" alt="image" src="https://github.com/user-attachments/assets/45d1742c-be8d-496a-94a5-35ecca9ccace" />
  <br>
  <em>Slot appearance grid and left-side paperdoll preview</em>
</p>

<br>

<p align="center">
  <img width="466" height="597" alt="image" src="https://github.com/user-attachments/assets/dd3ee5b9-6d09-46d2-ab93-b9fb78a38e18" />
  <br>
  <em>Transmogrified appearance name, original item icon, set bonuses count/show correctly</em>
</p>
<br>

<p align="center">
  <img width="365" height="291" alt="image" src="https://github.com/user-attachments/assets/5ee6f9d6-4651-4498-8bd8-23ebf9f7a7bf" />
  <br>
  <em>The missing appearance line</em>
</p>



