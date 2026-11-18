-- ~/.config/hypr/regles.lua
-- Sélecteurs de fichiers du portail GTK : flottants, centrés, 40 % × 60 % de l'écran
hl.window_rule({
  name  = "portail-gtk-flottant",
  match = { class = "^(xdg-desktop-portal-gtk)$" },
  float  = true,
  center = true,
  size   = "(monitor_w*0.4) (monitor_h*0.6)",
})


-- Fenêtre principale de Thunderbird
hl.window_rule({
  name  = "thunderbird-principal",
  match = {
    class         = "^(org\\.mozilla\\.thunderbird.*|thunderbird)$",
    initial_title = "^Mozilla Thunderbird$",
  },
  workspace = "special:magic",
  float     = true,
  size      = { 2000, 1080 },
  center    = true,
})

-- Fenêtre de rédaction
hl.window_rule({
  name  = "thunderbird-redaction",
  match = {
    class         = "^(org\\.mozilla\\.thunderbird.*|thunderbird)$",
    initial_title = "^Rédaction du message$",
  },
  float  = true,
  size   = { 1200, 900 },
  center = true,
})
