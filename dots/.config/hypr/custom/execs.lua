-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter
-- See the corresponding files in ~/.config/hypr/hyprland for examples

hl.on("hyprland.start", function ()
    hl.exec_cmd("elephant")
    hl.exec_cmd("killall xdg-desktop-portal-hyprland")
    hl.exec_cmd("killall xdg-desktop-portal")
    hl.exec_cmd("/usr/lib/xdg-desktop-portal-hyprland &")
end)

-- Surface friendly desktop notifications when title bars are temporarily
-- off (after a Hyprland update) or come back. Reads /var/lib/hyprbars/status
-- written by the system-side hyprbars-rebuild service.
hl.on("hyprland.start", function() hl.exec_cmd("/usr/local/bin/hyprbars-status-notify") end)

-- Surface friendly desktop notifications when the workspace overview is
-- temporarily off (after a Hyprland update) or comes back. Reads
-- /var/lib/scrolloverview/status written by the system-side
-- scrolloverview-rebuild service.
hl.on("hyprland.start", function() hl.exec_cmd("/usr/local/bin/scrolloverview-status-notify") end)
