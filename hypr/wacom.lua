-- ~/.config/hypr/wacom.lua
-- Wacom Intuos 4 (wacom-intuos4-wl-pen) : tablette active uniquement dans Rnote,
-- zone de la tablette = fenêtre Rnote (1728×1080, format 16:10 de la tablette).

local RNOTE = "com.github.flxzt.rnote"
local ECRAN = "DP-1"
local TABLETTE = "wacom-intuos4-wl-pen"

-- Rnote : flottant, 1728×1080, centré, dans le scratchpad "magic"
hl.window_rule({
  name      = "rnote-flottant",
  match     = { class = "^(com\\.github\\.flxzt\\.rnote)$" },
  -- workspace = "special:magic",
  float     = true,
  size      = { 1728, 1080 },
  center    = true,
})

-- Tablette active uniquement quand Rnote a le focus
local last = ""

local function maj_tablette()
  local w = hl.get_active_window()
  local actif = w ~= nil and w.class == RNOTE
  local x, y, l, h = 0, 0, 1, 1
  if actif then
    x, y, l, h = w.at.x, w.at.y, w.size.x, w.size.y
  end

  local key = tostring(actif) .. " " .. x .. " " .. y .. " " .. l .. " " .. h
  if key == last then return end          -- n'écrit que si ça change
  last = key

  hl.config({ input = { tablet = {
    output          = ECRAN,
    region_position = { x, y },
    region_size     = { l, h },
  }}})

  -- "enabled" n'existe que dans la config par appareil
  pcall(hl.device, { name = TABLETTE, enabled = actif })
end

hl.on("window.active", maj_tablette)                       -- changement de focus
hl.timer(maj_tablette, { timeout = 200, type = "repeat" })  -- suit les déplacements de Rnote
