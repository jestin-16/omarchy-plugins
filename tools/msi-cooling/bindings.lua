-- Add these lines to ~/.config/hypr/bindings.lua after backing it up.
-- Fn+F7 uses the model-specific scan-code mapping installed by setup.sh.
o.rebind("XF86Launch3", "Cycle cooling modes (Fn+F7)", "/home/jestin/.local/bin/msi-cooling cycle")
o.rebind("SUPER + F7", "Cycle cooling modes", "/home/jestin/.local/bin/msi-cooling cycle")
o.rebind("SUPER + SHIFT + F7", "Cycle cooling modes", "/home/jestin/.local/bin/msi-cooling cycle")
o.rebind("SUPER + CTRL + F7", "Dynamic cooling", "/home/jestin/.local/bin/msi-cooling dynamic")
o.rebind("SUPER + ALT + F7", "Cooling mode and temperature", "/home/jestin/.local/bin/msi-cooling status")
