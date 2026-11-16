-- ~/.config/hypr/regles.lua
-- Sélecteurs de fichiers du portail GTK : flottants, centrés, 40 % × 60 % de l'écran
hl.window_rule({
  name  = "portail-gtk-flottant",
  match = { class = "^(xdg-desktop-portal-gtk)$" },
  float  = true,
  center = true,
  size   = "(monitor_w*0.4) (monitor_h*0.6)",
})
