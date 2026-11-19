-- ~/.config/hypr/regles.lua
-- Sélecteurs de fichiers du portail GTK : flottants, centrés, 40 % × 60 % de l'écran
hl.window_rule({
  name  = "portail-gtk-flottant",
  match = { class = "^(xdg-desktop-portal-gtk)$" },
  float  = true,
  center = true,
  size   = "(monitor_w*0.4) (monitor_h*0.6)",
})

-- Spotify : espace spécial dédié, flottant, centré
hl.window_rule({
  name  = "spotify-special",
  match = { class = "^([Ss]potify)$" },
  workspace = "special:spotify",
  float     = true,
  size      = { 1600, 1000 },
  center    = true,
})


-- Fenêtre principale de Thunderbird
hl.window_rule({
  name  = "thunderbird-principal",
  match = {
    class         = "^(org\\.mozilla\\.thunderbird.*|thunderbird)$",
    initial_title = "^Mozilla Thunderbird$",
  },
  workspace = "special:thunderbird",
  float     = true,
  size      = { 2000, 1280 },
  center    = true,
})

-- Fenêtre de rédaction : espace spécial dédié
hl.window_rule({
  name  = "thunderbird-redaction",
  match = {
    class         = "^(org\\.mozilla\\.thunderbird.*|thunderbird)$",
    initial_title = "^Rédaction du message$",
  },
  workspace  = "special:thunderbird-edit",
  float      = true,
  size       = { 1200, 900 },
  center     = true,
  dim_around = true,
})
