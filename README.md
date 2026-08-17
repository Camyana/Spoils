<img src="design/curseforge-avatar.png" alt="Spoils" width="128" align="right">

# Spoils

Your loot, shown as animated cards that float up around your cursor. Each card
carries the item icon, its name in the item quality colour, and the stack size,
then drifts and fades away.

> **CurseForge:** _not published yet._ Replace this line with
> `[![CurseForge](https://img.shields.io/curseforge/dt/PROJECT_ID)](https://www.curseforge.com/wow/addons/SLUG)`
> once the project exists. See [Publishing](#publishing) below.

## Features

- **Three layouts.** `fan` alternates cards either side of the anchor and stacks them
  outward, `radial` bursts them around it, and `list` keeps a single tidy column.
- **Anchor anywhere.** Cards spawn at your cursor by default, or from a fixed screen
  point you place with a draggable mover.
- **Hover for tooltips.** Cards report hover but pass clicks straight through, so they
  can never eat a target click or a ground-targeted cast. Hovering also freezes the
  card's timer — catch one mid-fade and it rewinds to full opacity rather than
  dissolving while you read it.
- **Quality-aware.** Accent bar, icon border, name colour, and a gradient wash all
  follow item quality. Rare and better get a spawn flourish.
- **Stacks, not spam.** Looting the same item twice bumps the existing card's count
  and pulses it instead of spawning a duplicate.
- **Money and currency** get their own cards, with coin textures.

## Install

Drop the `Spoils` folder into `World of Warcraft/_retail_/Interface/AddOns/`.

Built for Interface `120100` (patch 12.1).

## Usage

    /spoils test [n]    preview with fake loot
    /spoils anchor      place a fixed screen anchor (switches to list layout)
    /spoils cursor      go back to spawning at the cursor
    /spoils style       fan | radial | list
    /spoils config      open settings
    /spoils toggle      turn on/off
    /spoils clear       clear cards on screen
    /spoils reset       restore defaults

`/sp` works as a short form. Everything is also in Settings → AddOns → Spoils:
layout, list grow direction and alignment, card lifetime, fade duration, scale,
maximum cards, minimum item quality, and toggles for money, currency, crafted
items, tooltips, and sound.

## Publishing

Releases are cut by the [BigWigs packager][packager] on tag push — see
[`.github/workflows/release.yml`](.github/workflows/release.yml). It always builds a
GitHub Release, and additionally uploads to CurseForge when both of these are set:

1. `## X-Curse-Project-ID: <id>` in [`Spoils.toc`](Spoils.toc) — the numeric project ID
   from your CurseForge project page.
2. A `CF_API_KEY` repository secret — generate one at
   <https://legacy.curseforge.com/account/api-tokens>.

With neither configured the workflow still succeeds; it just skips the CurseForge step.

To cut a release:

    git tag v0.4.0 && git push origin v0.4.0

[packager]: https://github.com/BigWigsMods/packager

## Licence

MIT — see [LICENSE](LICENSE).
