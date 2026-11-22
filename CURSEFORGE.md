# SmartCast Forever

**Smart targeting for the spells already on your bars. No macro writing, no moving buttons, one click to undo.**

Clicked your tank instead of the mob and your Fireball went nowhere? Hit an enemy when you meant to heal? SmartCast Forever turns the spells on your action bars into smart macros **in the same buttons**, so your keybinds and your layout stay exactly as they are.

## What it does

Pick a rule for your spells, press **Apply**, and each button becomes a macro that sends the spell where you mean it:

- **Enemy, or my friend's target**: a friend selected by mistake? The spell goes to whatever they are attacking. With no target at all, the button works like a plain one.
- **Mouseover, else target**: cast without changing your target.
- **Friend, else myself**: buffs and heals land on you when no friend is selected.
- **Friend, enemy's target or me**: an enemy selected by mistake? The heal goes to whoever it is hitting.
- **Always myself**.
- **Don't touch**: leave a button as it is.

Set a **default rule** for harmful, helpful and other spells, then change single buttons from a view of your own bars. Spells that need no target (Arcane Explosion, Frost Nova, armors...) are left alone by default.

## Stop casting

Each button can also cut what you are casting, so a heal or an emergency spell goes out at once:

- **Stop channels**: cuts a channeled spell (Arcane Missiles, Blizzard...), never the spell itself.
- **Stop everything**: cuts anything, a wand shot too. Pressing it twice restarts the spell, so it's best on instant spells and heals.

## Ranks, handled

- **Highest rank by default**: a macro without a rank always casts the best one you know, so new ranks just work.
- **Fixed rank** on any button, for mana-saving downranks.
- **Older ranks spotted**: buttons holding an older rank than you know are flagged. Use the highest, keep them, or let SmartCast ask you.
- **Plain spells too**: optionally, spells you didn't convert move up to each new rank you learn.

## Safe by design

- **Undo all** puts every original spell back and deletes SmartCast's macros.
- Only touches macros it made itself (named `SC ...`). Your own macros are never changed.
- Waits for the end of combat before changing anything.
- Hides macro names on converted buttons, so they look like the spell.
- Tooltips and icons stay those of the spell.

## Commands

- `/scf`: open the window (or left-click the minimap button)
- `/scf apply`: apply (or right-click the minimap button)
- `/scf undo`: undo all (or Shift + right-click the minimap button)
- `/scf demo`: preview with example buttons (changes nothing)

## Languages

English, Español, Deutsch, Français, Italiano, Português, Русский, 한국어, 简体中文, 繁體中文. Translations other than English and Spanish may need polishing. Corrections are welcome.

## Notes

- Settings are saved per character, and the macros are character macros. The window shows how many free macro slots you have left.
- Works with the default Blizzard action bars. Bar replacement addons (Bartender, Dominos...) aren't supported yet.
- Game limits that apply to every macro: *Press and Hold Casting* doesn't work on macro buttons, and right after cutting a cast the next spell may need a second press. Leave a button on *Don't touch* if you rely on holding its key.
- If you change the game's language, press **Undo all** and then **Apply**, so the macros use the new spell names.

Source code and issues: [github.com/noise-ep/SmartCastForever](https://github.com/noise-ep/SmartCastForever)

If SmartCast saves you some wasted casts, you can [buy me a coffee](https://ko-fi.com/noise_ep). Totally optional: it is and stays free. ☕

---

## Español

**Objetivos inteligentes para los hechizos que ya tienes en tus barras. Sin escribir macros, sin mover botones y con un clic para deshacer.**

SmartCast Forever convierte los hechizos de tus barras en macros inteligentes **en el mismo botón**, así que tus teclas y tu disposición no cambian. Elige una regla (enemigo o el objetivo de tu aliado, ratón encima, aliado o tú, siempre tú...), pulsa **Aplicar** y listo. Cada botón puede además cortar lo que estés lanzando. Controla los rangos (siempre el más alto o uno fijo), detecta rangos antiguos en tus barras y lo deshaces todo con **Deshacer todo**. Nunca toca tus propias macros. `/scf` abre la ventana.
