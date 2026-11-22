-- Locales.lua: English keys, Spanish translations. A missing key shows the English text.
local _, ns = ...

local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

local locale = GetLocale and GetLocale() or "enUS"
if locale ~= "esES" and locale ~= "esMX" then return end

-- templates
L["Enemy, or my friend's target"] = "Enemigo, o el objetivo de mi aliado"
L["Mouseover, else target"] = "Ratón encima, si no el objetivo"
L["Friend, else myself"] = "Aliado, si no yo mismo"
L["Friend, else my enemy's target, else myself"] = "Aliado, si no el objetivo de mi enemigo, si no yo"
L["Always myself"] = "Siempre yo mismo"
L["Don't touch"] = "No tocar"
L["Default (%s)"] = "Por defecto (%s)"

-- kinds
L["Harmful"] = "Dañino"
L["Helpful"] = "De ayuda"
L["Other"] = "Otro"

-- bars
L["Action Bar 1"] = "Barra de acción 1"
L["Action Bar 1 (page 2)"] = "Barra de acción 1 (pág. 2)"
L["Action Bar %d"] = "Barra de acción %d"
L["Form / stance bar %d"] = "Barra de forma / actitud %d"

-- window
L["Harmful spells"] = "Hechizos dañinos"
L["Helpful spells"] = "Hechizos de ayuda"
L["Other spells"] = "Otros hechizos"
L["Default rules"] = "Reglas por defecto"
L["Don't cancel if already active (!)"] = "No cancelar si ya está activo (!)"
L["Hide macro names on the buttons"] = "Ocultar el nombre de las macros en los botones"
L["Your bars"] = "Tus barras"
L["Click a button to set it up."] = "Haz clic en un botón para configurarlo."
L["Rule"] = "Regla"
L["Rank"] = "Rango"
L["Highest known"] = "El más alto que conozcas"
L["Shift: cast on myself"] = "Mayús: lanzar en mí"
L["Macro preview"] = "Vista previa de la macro"
L["Apply"] = "Aplicar"
L["Undo all"] = "Deshacer todo"
L["Converted: %d   Pending: %d   Character macros: %d / %d"] = "Convertidos: %d   Pendientes: %d   Macros de personaje: %d / %d"
L["Not a spell: SmartCast leaves it alone."] = "No es un hechizo: SmartCast no lo toca."
L["Empty slot"] = "Hueco vacío"
L["Converted"] = "Convertido"
L["Pending: Apply to convert"] = "Pendiente: pulsa Aplicar para convertirlo"
L["Left as it is"] = "Se queda como está"
L["Changed: Apply to update"] = "Cambiado: pulsa Aplicar para actualizarlo"

-- messages
L["Done: %d converted, %d restored."] = "Hecho: %d convertidos, %d restaurados."
L["Undone: %d spells put back."] = "Deshecho: %d hechizos devueltos a su sitio."
L["In combat: it will run when combat ends."] = "En combate: se hará al terminar el combate."
L["Character macros are full: %d buttons left as they were."] = "Las macros de personaje están llenas: %d botones se han quedado como estaban."
L["Commands: /scf (window), /scf apply, /scf undo"] = "Comandos: /scf (ventana), /scf apply, /scf undo"

-- minimap
L["Left-click: settings"] = "Clic izquierdo: ajustes"
L["Right-click: apply"] = "Clic derecho: aplicar"
L["Shift + right-click: undo all"] = "Mayús + clic derecho: deshacer todo"
L["Drag: move this button"] = "Arrastrar: mover este botón"
