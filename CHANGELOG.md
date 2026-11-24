# Changelog

## 0.1.6

- Fixed: moving a converted button by hand no longer confuses SmartCast. Its spell and its settings now follow the button to its new place, so *Apply* and *Undo all* no longer put the old macro back where the button used to be.

## 0.1.5

- New per-button option: *Switch my target*, for the rules that look at someone else's target. That target becomes yours before casting, so the wand and Auto Shot keep shooting instead of firing once. On heals it works the other way round: select the enemy and you switch to whoever it is hitting.
- Tooltips on every rule and option, with what each one is for.

## 0.1.4

- "Stop current cast first" is now a choice with three values: *Don't stop*, *Stop channels* (cuts Arcane Missiles, Blizzard... but never the spell itself, so a second press doesn't restart it) and *Stop everything* (cuts anything, a wand shot too). Buttons already set keep cutting everything.

## 0.1.3

- New per-button option: *Stop current cast first*. Adds `/stopcasting` so the spell goes out at once, cutting a wand shot. It also cuts your own cast, so it's best on instant spells and heals.

## 0.1.2

- Spells that need no target (Arcane Explosion, Frost Nova, armors...) count as *Other* and are left alone by the default rules: a targeting macro could stop them from casting. Press Apply once to give them back their plain button.

## 0.1.1

- *Enemy, or my friend's target*: with no target at all, the button now does what a plain spell button does (the game's error or its own auto-targeting) instead of nothing. Press Apply once to update your converted buttons.
- The macro preview in the window wraps instead of being cut short.

## 0.1.0

First release.

- Turns the spells on your action bars into smart macros, in the same buttons, so your keybinds stay.
- Targeting rules: *Enemy, or my friend's target*; *Mouseover, else target*; *Friend, else myself*; *Friend, enemy's target or me*; *Always myself*; or leave the button alone.
- Default rules for harmful, helpful and other spells, plus per-button choices.
- Rank control: follow the highest rank you know, or keep a fixed one.
- Older ranks on your bars: detected, with a choice to use the highest or keep them. Plain spells on your bars can follow new ranks by themselves.
- Options: don't cancel a spell that is already active (`!`), Shift to cast on yourself, hide macro names on the buttons.
- Undo all: puts the original spells back and deletes SmartCast's macros. Never touches macros you made.
- Waits for the end of combat. Minimap button. Preview mode (`/scf demo`): example buttons from your own spells; your bars are not changed.
- English, Español, Deutsch, Français, Italiano, Português, Русский, 한국어, 简体中文, 繁體中文.
