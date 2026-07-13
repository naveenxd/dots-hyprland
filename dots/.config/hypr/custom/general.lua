-- scrolloverview plugin load directive (built from source at install time)
hl.plugin.load("/home/naveenxd/.local/share/hyprland/plugins/scrolloverview.so")

-- hyprbars plugin load directive (built from source at install time)
-- hl.plugin.load("/home/naveenxd/.local/share/hyprland/plugins/hyprbars.so")

-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter
-- See the corresponding files in ~/.config/hypr/hyprland for examples

-- UI & DECORATION
hl.config({
    decoration = {
        rounding = 18,
        active_opacity = 0.90,
        inactive_opacity = 0.80,
        blur = {
            enabled = true,
            size = 6,
            passes = 3,
            ignore_opacity = true,
            new_optimizations = true,
            xray = false,
            vibrancy = 0.16,
            brightness = 1.0,
            contrast = 1.0,
            popups = true,
        },
        shadow = {
            enabled = true,
            range = 20,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },
    },
})

-- ANIMATIONS
hl.config({
    bezier = {
        "easeOut,      0.0,  0.0,  0.2,  1.0",
        "easeInOut,    0.4,  0.0,  0.2,  1.0",
        "overshoot,    0.05, 0.9,  0.1,  1.05",
        "smoothSnap,   0.4,  0.0,  0.6,  1.0",
    },
})

hl.config({
    animations = {
        enabled = true,
        animation = {
            "windows,         1, 4,  overshoot,  slide",
            "windowsIn,       1, 4,  overshoot,  slide",
            "windowsOut,      1, 4,  easeOut,    slide",
            "windowsMove,     1, 4,  smoothSnap",
            "border,          1, 8,  easeInOut",
            "borderangle,     1, 8,  easeInOut",
            "fade,            1, 5,  easeOut",
            "fadeIn,          1, 5,  easeOut",
            "fadeOut,         1, 4,  easeOut",
            "workspaces,      1, 5,  smoothSnap, slidevert",
            "specialWorkspace,1, 5,  overshoot,  slidevert",
        },
    },
})
