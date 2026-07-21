pragma Singleton
pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * A nice wrapper for date and time strings.
 */
Singleton {
    property var clock: SystemClock {
        id: clock
        precision: (Config.options?.time?.secondPrecision || Config.options?.bar?.showSeconds)
            ? SystemClock.Seconds
            : SystemClock.Minutes
    }
    function normalizeTimeFormat(fmt, enableSeconds) {
        if (!fmt) fmt = "hh:mm";

        const parts = fmt.split(/('[^']*')/);
        const stripped = parts.map(part => {
            if (part.startsWith("'") && part.endsWith("'")) return part;
            return part.replace(/:s{1,2}/g, "").replace(/\bs{1,2}\b/g, "");
        }).join("");

        if (!enableSeconds) return stripped;

        if (/(\s*[aA][pP])$/.test(stripped)) {
            return stripped.replace(/(\s*[aA][pP])$/, ":ss$1");
        }
        return stripped + ":ss";
    }

    property string time: {
        const fmt = Config.options?.time?.format ?? "hh:mm";
        const enableSec = Config.options?.time?.secondPrecision || Config.options?.bar?.showSeconds;
        return Qt.locale().toString(clock.date, normalizeTimeFormat(fmt, enableSec));
    }
    property string shortDate: Qt.locale().toString(clock.date, Config.options?.time?.shortDateFormat ?? "dd/MM")
    property string date: Qt.locale().toString(clock.date, Config.options?.time?.dateWithYearFormat ?? "dd/MM/yyyy")
    property string longDate: Qt.locale().toString(clock.date, Config.options?.time?.dateFormat ?? "dddd, dd/MM")
    property string collapsedCalendarFormat: Qt.locale().toString(clock.date, "dddd, MMMM dd")
    property string uptime: "0h, 0m"

    Timer {
        interval: 10
        running: true
        repeat: true
        onTriggered: {
            fileUptime.reload();
            const textUptime = fileUptime.text();
            const uptimeSeconds = Number(textUptime.split(" ")[0] ?? 0);

            // Convert seconds to days, hours, and minutes
            const days = Math.floor(uptimeSeconds / 86400);
            const hours = Math.floor((uptimeSeconds % 86400) / 3600);
            const minutes = Math.floor((uptimeSeconds % 3600) / 60);

            // Build the formatted uptime string
            let formatted = "";
            if (days > 0)
                formatted += `${days}d`;
            if (hours > 0)
                formatted += `${formatted ? ", " : ""}${hours}h`;
            if (minutes > 0 || !formatted)
                formatted += `${formatted ? ", " : ""}${minutes}m`;
            uptime = formatted;
            interval = Config.options?.resources?.updateInterval ?? 3000;
        }
    }

    FileView {
        id: fileUptime

        path: "/proc/uptime"
    }
}
