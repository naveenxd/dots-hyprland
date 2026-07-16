pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs
import qs.modules.common
import qs.modules.common.functions

/**
 * Global singleton that manages a single cava process.
 * Prevents multiple cava instances from spawning on multi-monitor setups.
 *
 * Uses restartPending to gate the running: binding — when cava exits
 * unexpectedly during playback, restartPending temporarily forces the
 * binding to false, then the restartTimer re-enables it after a short
 * delay, restarting the process without breaking the declarative binding.
 */
Singleton {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool isPlaying: activePlayer?.playbackState === MprisPlaybackState.Playing

    property list<real> points: []
    property bool restartPending: false

    Timer {
        id: restartTimer
        interval: 250
        repeat: false
        onTriggered: {
            root.restartPending = false;
            // The running: binding now re-evaluates to isPlaying, restarting cava
        }
    }

    Process {
        id: cavaProc
        running: root.isPlaying && !root.restartPending
        onRunningChanged: {
            if (!running) {
                root.points = [];
                // If still supposed to be playing, schedule a restart
                if (root.isPlaying && !root.restartPending) {
                    root.restartPending = true;
                    restartTimer.restart();
                }
            }
        }
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/raw_output_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                let pts = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p));
                root.points = pts;
            }
        }
    }
}
