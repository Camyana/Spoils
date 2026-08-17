# Spoils

Copy for the CurseForge project page. Kept in the repo so the store listing and
the README stay in sync.

## One line

Your loot, shown as animated cards that float up around your cursor.

## Short (CurseForge summary field, 200 char limit)

Spoils turns loot into animated cards that float up around your cursor or from a
fixed spot on your screen. Quality coloured, hoverable for tooltips, and quiet
enough to leave on in raid.

## Full description

Loot in World of Warcraft scrolls past in the chat frame and is gone before you
read it. Spoils puts it where you are already looking.

Every item you pick up spawns a small card next to your cursor. The card carries
the item icon, its name in the item quality colour, and the stack size. It pops
in, drifts outward, and fades. Rare and better items get a brief flourish on
arrival, so a purple drop is obvious without you having to read anything.

### Three layouts

**Fan** alternates cards to either side of the anchor point and stacks them
outward, so a big loot pull spreads across your screen instead of piling up.

**Radial** bursts them out around the anchor in a ring.

**List** keeps a single tidy column. Rows are ordered newest first, so the most
recent drop always sits on the anchor and older rows get pushed away. When a row
expires out of the middle, the rows below it close the gap smoothly rather than
jumping.

### Put it where you want it

By default cards spawn at your cursor and stay pinned where the loot happened, so
you can look back at what dropped. You can also switch them to trail the cursor
as it moves.

If you would rather keep loot out of the middle of the action, type
`/spoils anchor` to drop a draggable anchor anywhere on screen. Sample loot keeps
flowing while the anchor is open so you can position it against real cards
instead of guessing. The list layout can grow upward or downward and align to
either edge, so it works anchored at the top, bottom, left, or right.

### Hover for the full tooltip

Hovering a card shows the normal Blizzard item tooltip, with all the stats and
comparisons you expect. Hovering also freezes that card in place, so catching one
mid fade rewinds it to full opacity instead of dissolving while you read.

Cards report hover but pass clicks straight through to the world. They will never
eat a target click or swallow a ground targeted cast, which matters when they are
sitting under your cursor in combat.

### Details that keep it quiet

Looting the same item twice bumps the existing card's count and gives it a small
pulse instead of spawning a duplicate, so gathering forty herbs leaves you with
one card reading x40.

Money and currency get their own cards, with proper coin textures. You can set a
minimum item quality to hide vendor trash, cap how many cards appear at once, and
tune lifetime, fade duration, and scale to taste. Crafted items, currency, money,
tooltips, and a chime for epic drops can each be turned off.

### Commands

    /spoils test [n]    preview with fake loot
    /spoils anchor      place a fixed screen anchor
    /spoils cursor      go back to spawning at the cursor
    /spoils style       fan, radial, or list
    /spoils config      open settings
    /spoils toggle      turn on or off
    /spoils clear       clear cards on screen
    /spoils reset       restore defaults

`/sp` works as a short form. Everything is also available in the standard
Settings panel, under AddOns.

### Notes

Built for retail patch 12.1. No dependencies and no external libraries.

Source, issues, and feature requests live on GitHub:
https://github.com/Camyana/Spoils
