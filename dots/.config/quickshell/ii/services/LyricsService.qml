pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    property string currentTrackName: ""
    property string currentArtistName: ""

    property int currentFetchId: 0
    property bool loading: false
    property string currentLyricLine: ""
    property string nextLyricLine: ""
    property bool isMultiLineJoined: false
    property var lyricLines: [] // Array of { time: seconds, text: string }
    property var groupedLyricLines: []

    onLyricLinesChanged: rebuildGroups()
    Connections {
        target: GlobalStates
        function onTopBarMediaWidthChanged() { rebuildGroups() }
    }
    property string plainLyrics: ""

    property real lastKnownPosition: 0
    property real lastKnownTimestamp: 0

    // Per-phase watchdog identities — separate IDs prevent a late GET response
    // from cancelling the search-phase watchdog (or vice versa).
    property int _wdGetFetchId: -1
    property int _wdSearchFetchId: -1
    property string _wdCleanTrack: ""
    property string _wdCleanArtist: ""
    property int _wdTargetDuration: 0
    property string _wdCacheKey: ""

    Timer {
        id: getRequestWatchdog
        interval: 10000
        repeat: false
        onTriggered: {
            let id = root._wdGetFetchId;
            if (id !== root.currentFetchId) return;
            // Invalidate GET phase so any late XHR callback is ignored
            root._wdGetFetchId = -1;
            root.searchLyricsFallback(id, root._wdCleanTrack, root._wdCleanArtist, root._wdTargetDuration, root._wdCacheKey);
        }
    }

    Timer {
        id: searchRequestWatchdog
        interval: 10000
        repeat: false
        onTriggered: {
            if (root._wdSearchFetchId !== root.currentFetchId) return;
            root.loading = false;
        }
    }

    function normalizeStr(s) {
        if (!s) return "";
        // Use QML-compatible character class instead of Unicode property escapes (\p{L}\p{N})
        // which are unsupported in Qt's V4 JS engine.
        return String(s).toLowerCase().normalize("NFC").replace(/[^a-z0-9\u00C0-\u024F\u0370-\u03FF\u0400-\u04FF\u4E00-\u9FFF\u3040-\u30FF]/g, "");
    }

    function findBestResult(results, targetTrack, targetArtist, targetDuration) {
        if (!results || !Array.isArray(results) || results.length === 0) return null;
        let normTrack = root.normalizeStr(targetTrack);
        let normArtist = root.normalizeStr(targetArtist);

        let bestResult = null;
        let bestScore = -9999;

        for (let i = 0; i < results.length; i++) {
            let r = results[i];
            if (!r || !r.syncedLyrics) continue;
            let rTrack = root.normalizeStr(r.trackName);
            let rArtist = root.normalizeStr(r.artistName);

            let score = 0;
            if (rTrack === normTrack) score += 50;
            else if (normTrack.length > 2 && (rTrack.includes(normTrack) || normTrack.includes(rTrack))) score += 25;

            if (rArtist === normArtist) score += 40;
            else if (!normArtist || rArtist.includes(normArtist) || normArtist.includes(rArtist)) score += 20;

            if (targetDuration > 0 && r.duration) {
                let diff = Math.abs(r.duration - targetDuration);
                if (diff <= 2) score += 35;
                else if (diff <= 5) score += 20;
                else if (diff > 15) score -= 30;
            }

            if (score > bestScore) {
                bestScore = score;
                bestResult = r;
            }
        }

        if (bestResult) return bestResult;

        for (let i = 0; i < results.length; i++) {
            if (results[i] && results[i].syncedLyrics) return results[i];
        }
        return results[0];
    }

    property var lyricCache: ({})

    function fetchLyrics(track, artist) {
        root.currentFetchId++;
        let myFetchId = root.currentFetchId;

        if (!track || track === "") {
            root.lyricLines = [];
            root.plainLyrics = "";
            root.currentLyricLine = "";
            return;
        }
        root.loading = true;
        root.lyricLines = [];
        root.plainLyrics = "";
        root.currentLyricLine = "";
        root.nextLyricLine = "";
        root.isMultiLineJoined = false;

        let cleanTrack = StringUtils.cleanMusicTitle(track);
        let cleanArtist = artist || "";
        let cacheKey = (cleanTrack + "___" + cleanArtist).toLowerCase();

        if (root.lyricCache[cacheKey]) {
            root.loading = false;
            root.parseLyricsResponse(root.lyricCache[cacheKey]);
            return;
        }

        let targetDuration = Math.round(activePlayer?.length || 0);

        if (targetDuration > 0) {
            let getUrl = `https://lrclib.net/api/get?track_name=${encodeURIComponent(cleanTrack)}&artist_name=${encodeURIComponent(cleanArtist)}&duration=${targetDuration}`;
            var getXhr = new XMLHttpRequest();
            root._wdGetFetchId = myFetchId;
            root._wdCleanTrack = cleanTrack;
            root._wdCleanArtist = cleanArtist;
            root._wdTargetDuration = targetDuration;
            root._wdCacheKey = cacheKey;
            getRequestWatchdog.restart();
            getXhr.onreadystatechange = function() {
                if (getXhr.readyState === XMLHttpRequest.DONE) {
                    // If the watchdog already fired and handed off to search,
                    // _wdGetFetchId will be -1 — discard this late response entirely.
                    if (root._wdGetFetchId !== myFetchId) return;
                    getRequestWatchdog.stop();
                    root._wdGetFetchId = -1; // consume the GET slot
                    if (myFetchId !== root.currentFetchId) return;
                    if (getXhr.status === 200) {
                        try {
                            var data = JSON.parse(getXhr.responseText);
                            if (data && (data.syncedLyrics || data.plainLyrics)) {
                                root.loading = false;
                                root.lyricCache[cacheKey] = data;
                                root.parseLyricsResponse(data);
                                return;
                            }
                        } catch(e) {}
                    }
                    root.searchLyricsFallback(myFetchId, cleanTrack, cleanArtist, targetDuration, cacheKey);
                }
            };
            getXhr.open("GET", getUrl, true);
            getXhr.send();
        } else {
            root.searchLyricsFallback(myFetchId, cleanTrack, cleanArtist, targetDuration, cacheKey);
        }
    }

    function searchLyricsFallback(fetchId, cleanTrack, cleanArtist, targetDuration, cacheKey) {
        let query = `${cleanTrack} ${cleanArtist}`.trim();
        let url = `https://lrclib.net/api/search?q=${encodeURIComponent(query)}`;
        var xhr = new XMLHttpRequest();
        root._wdSearchFetchId = fetchId;
        searchRequestWatchdog.restart();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                // Only stop if OUR watchdog is still the current one
                if (root._wdSearchFetchId === fetchId) searchRequestWatchdog.stop();
                if (fetchId !== root.currentFetchId) return;
                root.loading = false;
                if (xhr.status === 200) {
                    try {
                        var results = JSON.parse(xhr.responseText);
                        let best = root.findBestResult(results, cleanTrack, cleanArtist, targetDuration);
                        if (best) {
                            root.lyricCache[cacheKey] = best;
                            root.parseLyricsResponse(best);
                        }
                    } catch(e) {}
                }
            }
        };
        xhr.open("GET", url, true);
        xhr.send();
    }

    function parseLyricsResponse(data) {
        if (!data) return;
        root.plainLyrics = data.plainLyrics || "";
        let synced = data.syncedLyrics;
        if (synced && synced.length > 0) {
            let lines = synced.split("\n");
            let parsed = [];
            let regex = /\[((?:\d+:)?\d+:\d+(?:\.\d+)?)\](.*)/;
            for (let i = 0; i < lines.length; i++) {
                let match = regex.exec(lines[i]);
                if (match) {
                    let timeParts = match[1].split(":");
                    let timeSec = 0;
                    if (timeParts.length === 3) {
                        timeSec = (parseFloat(timeParts[0]) || 0) * 3600.0 + (parseFloat(timeParts[1]) || 0) * 60.0 + (parseFloat(timeParts[2]) || 0);
                    } else {
                        timeSec = (parseFloat(timeParts[0]) || 0) * 60.0 + (parseFloat(timeParts[1]) || 0);
                    }
                    let text = match[2].trim();
                    parsed.push({ time: timeSec, text: text });
                }
            }
            root.lyricLines = parsed;
        }
    }

    function isSupportedPlayer(player) {
        if (!player) return false;
        let id = (player.identity || "").toLowerCase();
        let entry = (player.desktopEntry || "").toLowerCase();
        let bus = (player.dbusName || "").toLowerCase();
        let isSpotify = id.includes("spotify") || entry.includes("spotify") || bus.includes("spotify");
        let isAudacious = id.includes("audacious") || entry.includes("audacious") || bus.includes("audacious");
        return isSpotify || isAudacious;
    }

    function syncTrackChange() {
        let newTitle = activePlayer?.trackTitle || "";
        let newArtist = activePlayer?.trackArtist || "";
        if (newTitle !== root.currentTrackName || newArtist !== root.currentArtistName) {
            root.currentTrackName = newTitle;
            root.currentArtistName = newArtist;
            root.lastKnownPosition = activePlayer?.position || 0;
            root.lastKnownTimestamp = Date.now();
            if (root.isSupportedPlayer(activePlayer)) {
                root.fetchLyrics(root.currentTrackName, root.currentArtistName);
            } else {
                root.lyricLines = [];
                root.plainLyrics = "";
                root.currentLyricLine = "";
                root.nextLyricLine = "";
                root.isMultiLineJoined = false;
            }
        }
    }

    Connections {
        target: activePlayer
        function onTrackTitleChanged() { root.syncTrackChange(); }
        function onTrackArtistChanged() { root.syncTrackChange(); }
        function onPositionChanged() {
            root.lastKnownPosition = activePlayer?.position || 0;
            root.lastKnownTimestamp = Date.now();
        }
    }

    Connections {
        target: MprisController
        function onActivePlayerChanged() { root.syncTrackChange(); }
    }

    TextMetrics {
        id: lyricMetrics
        font.family: Appearance?.font?.family?.main ?? ""
        font.pixelSize: Appearance?.font?.pixelSize?.small ?? 15
    }

    function measurePixelWidth(str) {
        if (!str) return 0;
        lyricMetrics.text = str;
        return lyricMetrics.advanceWidth;
    }

    function rebuildGroups() {
        let lines = root.lyricLines;
        if (!lines || lines.length === 0) {
            root.groupedLyricLines = [];
            return;
        }
        let maxAllowedPx = Math.max(140, (GlobalStates?.topBarMediaWidth ?? 440) - 150);
        let groups = [];
        let i = 0;
        while (i < lines.length) {
            let start = i;
            let groupText = lines[i].text;
            let currentPx = root.measurePixelWidth(groupText);
            let j = i + 1;

            if (groupText !== "" && currentPx < maxAllowedPx * 0.65) {
                while (j < lines.length) {
                    let nextText = lines[j].text;
                    if (nextText === "") break;
                    let candidateText = groupText + " • " + nextText;
                    let candidatePx = root.measurePixelWidth(candidateText);
                    let gap = lines[j].time - lines[j - 1].time;
                    let totalSpan = lines[j].time - lines[start].time;
                    if (gap <= 3.4 && totalSpan <= 7.0 && candidatePx <= maxAllowedPx) {
                        groupText = candidateText;
                        currentPx = candidatePx;
                        j++;
                    } else {
                        break;
                    }
                }
            }

            let group = { startIdx: start, endIdx: j - 1, text: groupText, nextStartIdx: j };
            for (let k = start; k < j; k++) {
                groups[k] = group;
            }
            i = j;
        }
        root.groupedLyricLines = groups;
    }

    function findGroupForIndex(lines, targetIdx) {
        if (!root.groupedLyricLines || targetIdx < 0 || targetIdx >= root.groupedLyricLines.length) {
            return { startIdx: -1, endIdx: -1, text: "", nextStartIdx: -1 };
        }
        return root.groupedLyricLines[targetIdx];
    }

    Timer {
        interval: 100
        repeat: true
        running: activePlayer?.playbackState === MprisPlaybackState.Playing && root.lyricLines.length > 0
        onTriggered: {
            let pos = activePlayer?.position || 0;
            let elapsedSec = (Date.now() - root.lastKnownTimestamp) / 1000.0;

            if (Math.abs(pos - (root.lastKnownPosition + elapsedSec)) > 1.5) {
                root.lastKnownPosition = pos;
                root.lastKnownTimestamp = Date.now();
                elapsedSec = 0;
            }

            let currentPos = root.lastKnownPosition + elapsedSec;
            let audioSyncPos = Math.max(0, currentPos - 0.3);

            let lines = root.lyricLines;
            let currIdx = -1;
            for (let i = 0; i < lines.length; i++) {
                if (audioSyncPos >= lines[i].time) {
                    currIdx = i;
                } else {
                    break;
                }
            }

            let newCurrentLine = "";
            let newNextLine = "";
            let isJoined = false;

            if (currIdx >= 0) {
                let currGroup = root.findGroupForIndex(lines, currIdx);
                newCurrentLine = currGroup.text;
                isJoined = (currGroup.endIdx > currGroup.startIdx);

                if (currGroup.nextStartIdx < lines.length) {
                    let nextGroup = root.findGroupForIndex(lines, currGroup.nextStartIdx);
                    newNextLine = nextGroup.text;
                }
            } else if (lines.length > 0) {
                let firstGroup = root.findGroupForIndex(lines, 0);
                newNextLine = firstGroup.text;
            }

            if (root.currentLyricLine !== newCurrentLine) root.currentLyricLine = newCurrentLine;
            if (root.nextLyricLine !== newNextLine) root.nextLyricLine = newNextLine;
            if (root.isMultiLineJoined !== isJoined) root.isMultiLineJoined = isJoined;
        }
    }

    Component.onCompleted: {
        root.syncTrackChange();
    }
}
