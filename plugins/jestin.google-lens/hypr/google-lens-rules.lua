-- Hyprland window rule for Google Lens floating overlay
-- Add this to ~/.config/hypr/hyprland.lua

o.window("(^chrome-lens\\.google\\.com__.*$|^chrome-images\\.google\\.com__.*$|^chrome-www\\.google\\.com__.*$)", {
  tag = "-chromium-based-browser",
  float = true,
  pin = true,
  size = { "(monitor_w*0.42)", "(monitor_h*0.88)" },
  move = { "(monitor_w*0.58-20)", "(monitor_h*0.06)" },
})
