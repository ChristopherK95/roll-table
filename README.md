# Roll Table

A small World of Warcraft: Forever addon that shows who chose **Need**, **Greed** or **Pass** on group loot, and what they rolled.

When an item is rolled on, a window opens listing every player who has chosen, sorted Need first, then Greed, then Pass, with the highest roll on top. When the roll ends, the winner is marked and the item folds into a one-line summary. The window closes itself a while after the last roll finishes.

## Features

- Every group loot roll you can see, not just the ones you were offered.
- Player names in class colours, dice and coin icons for Need and Greed, and the roll number.
- Several items at once, each in its own section. Click an item to fold or unfold it; shift-click to link it in chat; hover for its tooltip.
- The last 10 finished items stay in the window until you log out.
- Two looks: a minimal dark box, or a Blizzard-style window like the game's own Professions frame.
- A minimap button and an entry in the game's AddOns menu.

## Commands

| Command | What it does |
| --- | --- |
| `/rolltable` | Show or hide the window |
| `/rolltable config` | Open the settings |
| `/rolltable style` | Switch between the minimal and Blizzard look |
| `/rolltable minimap` | Show or hide the minimap button |
| `/rolltable test` | Fill the window with made-up rolls, to check how it looks |

Minimap button: **left-click** shows or hides the window, **right-click** opens the settings.

## Settings

Found under **Options → AddOns → Roll Table**:

- **Style**: Minimal or Blizzard.
- **Auto-close delay**: how long the window stays open after the last roll ends (0 keeps it open).
- **Lock position**: stops the window from being dragged.
- **Scale**: the size of the window.
- **Show minimap button**.

## Installing

Install it from CurseForge, or copy the `roll-table` folder into
`World of Warcraft\_forever_\Interface\AddOns\`.

## Notes

- The roll data comes from the game's loot history and its loot chat messages. A roll stays open until the game reports the winner, or that everyone passed.
- Only English clients are tested. Other languages should work, since the addon reads the game's own text, but haven't been tried.
- Players are told apart by first name, because Forever surnames only appear in some of the game's messages. Two players in the same group with the same first name show up as one.
