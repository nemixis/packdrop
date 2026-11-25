# The Atelier is on standby

The card-grading mini-game is **parked, not deleted**. It is unreachable from the game and no part of
it runs; every line of it is still in `index.html` and one flag brings it back.

## What was removed

- The `Atelier` entry in the More menu (`data-more-tab="mint-screen"`).

## What was changed

- `renderMintScreen()` now returns on its first line when `ATELIER_PARKED` is true.

That function is the **only** entry point to the feature: it renders the board, the builder and the
run view. With it inert, the engine (`atelierScore`, `atelierGrade`), the commission config
(`ATELIER_FAMILIES`, `ATELIER_SPEC`, `atelierCommissions()`), the picker, the reveal FX, the CSS and
the whole `#mint-screen` markup all stay in the file but can never reach the DOM.

State already saved on players (`mint` in the profile snapshot: finishes, grades, `mint.active`) is
left untouched — it is still written back on save, so a restored Atelier finds every finish intact.

## Restoring it

1. Delete the `if (ATELIER_PARKED) return;` line in `renderMintScreen()`.
2. Put the menu entry back:

```html
<button class="more-item" data-more-tab="mint-screen" role="menuitem">
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 2l2.4 4.9 5.4.8-3.9 3.8.9 5.4-4.8-2.5-4.8 2.5.9-5.4L4.2 7.7l5.4-.8L12 2z"/></svg>
  <span data-i18n="mint">Atelier</span>
</button>
```

3. Set `ATELIER_PARKED = false` (and remove the guard, if you removed the flag).

## What replaces it

The Atelier tab becomes the **personalisation store**: cosmetics bought with shards, applied to the
public profile and to binders.
