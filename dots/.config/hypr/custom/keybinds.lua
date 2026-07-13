-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter
-- See the corresponding files in ~/.config/hypr/hyprland for examples
hl.unbind("SUPER + E")
hl.bind("SUPER + E", hl.dsp.exec_cmd("nemo"))
hl.unbind("SUPER + B")
hl.bind("SUPER + B", hl.dsp.exec_cmd("zen-browser"))

hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("walker"))

-- qs_keybind_capture — capture submap used by the settings keybinds editor; do not remove
hl.define_submap("qs_keybind_capture", function()
    hl.bind("Escape", hl.dsp.submap("reset"))
end)
