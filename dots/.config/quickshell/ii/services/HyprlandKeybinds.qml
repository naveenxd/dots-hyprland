pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * A service that provides access to Hyprland keybinds.
 * Uses the `get_keybinds.py` script to parse comments in config files in a certain format and convert to JSON.
 */
Singleton {
    id: root
    property var keybinds: []
    property var keybindCategories: []

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name == "configreloaded") {
                getKeybinds.running = true
            }
        }
    }

    Process {
        id: getKeybinds
        running: true
        command: ["hyprctl", "binds"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.keybinds = root.parseBinds(text)
                    var groups = []
                    for (var i = 0; i < root.keybinds.length; i++) {
                        var bind = root.keybinds[i].description
                        if (!bind || typeof bind !== "string") continue
                        var colonIdx = bind.indexOf(":")
                        if (colonIdx > 0) {
                            var group = bind.substring(0, colonIdx).trim()
                            if (!groups.includes(group) && group.length > 0) {
                                groups.push(group)
                            }
                        }
                    }
                    root.keybindCategories = groups
                } catch (e) {
                    console.error("[CheatsheetKeybinds] Error parsing keybinds:", e)
                }
            }
        }
    }

    function parseBinds(text) {
        if (!text) return []

        var trimmed = text.trim()
        if (trimmed.startsWith("[")) {
            try {
                var parsed = JSON.parse(trimmed)
                if (Array.isArray(parsed) && parsed.length > 0 && typeof parsed[0].modmask === "number") {
                    return parsed
                }
            } catch (e) {
                // Fall through to plain text parsing if JSON is malformed
            }
        }

        var binds = []
        var lines = text.split("\n")
        var curr = null

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (!line.startsWith("\t") && line.trim().length > 0) {
                if (curr) binds.push(curr)
                curr = { bindtype: line.trim(), modmask: 0, description: "", key: "" }
            } else if (line.startsWith("\t") && curr) {
                var idx = line.indexOf(":")
                if (idx !== -1) {
                    var k = line.substring(0, idx).trim()
                    var v = line.substring(idx + 1).trim()
                    if (k === "modmask") {
                        curr.modmask = parseInt(v) || 0
                    } else {
                        curr[k] = v
                    }
                }
            }
        }
        if (curr) binds.push(curr)
        return binds
    }
}

