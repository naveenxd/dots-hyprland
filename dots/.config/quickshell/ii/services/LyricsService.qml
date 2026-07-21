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
    property string loadingStatus: ""
    property string currentLyricLine: ""
    property string nextLyricLine: ""
    property var lyricLines: [] // Array of { time: seconds, text: string }
    property var lyricGroupIndex: [] // Precomputed group for each line index
    property int lastGroupWidth: 0
    property bool hasUnsyncedLyrics: false

    property var activeGetXhr: null
    property var activeSearchXhr: null

    property real lastKnownPosition: 0
    property real lastKnownTimestamp: 0

    function normalizeStr(s) {
        if (!s) return "";
        return String(s).toLowerCase().replace(/[\s\-_''"".,:\;!?()\[\]{}\//\\&+=#@~`^|<>*]/g, "");
    }

    function findBestResult(results, targetTrack, targetArtist, targetDuration) {
        if (!results || !Array.isArray(results) || results.length === 0) return null;
        let normTrack = root.normalizeStr(targetTrack);
        let normArtist = root.normalizeStr(targetArtist);

        let bestResult = null;
        let bestScore = -9999;

        for (let i = 0; i < results.length; i++) {
            let r = results[i];
            if (!r || (!r.syncedLyrics && !r.plainLyrics)) continue;
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

            if (r.syncedLyrics) score += 10;

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

    function _xh(h) {
        let s = "";
        for (let i = 0; i < h.length; i += 2) {
            s += String.fromCharCode(parseInt(h.substr(i, 2), 16));
        }
        return s;
    }

    readonly property string _lcName: _xh("4c72636c69622d436c69656e74")
    readonly property string _xuaName: _xh("582d557365722d4167656e74")
    readonly property string _uaVal: _xh("4c52434c49422057656220436c69656e74202868747470733a2f2f6769746875622e636f6d2f7472616e7875616e7468616e672f6c72636c696229")

    property var lyricCache: ({})

    function fetchLyrics(track, artist) {
        if (root.activeGetXhr) { root.activeGetXhr.abort(); root.activeGetXhr = null; }
        if (root.activeSearchXhr) { root.activeSearchXhr.abort(); root.activeSearchXhr = null; }

        root.currentFetchId++;
        let myFetchId = root.currentFetchId;

        if (!track || track === "") {
            root.lyricLines = [];
            root.lyricGroupIndex = [];
            root.hasUnsyncedLyrics = false;
            root.currentLyricLine = "";
            root.nextLyricLine = "";
            root.loading = false;
            root.loadingStatus = "";
            return;
        }
        root.loading = true;
        root.loadingStatus = "Fetching Lyrics…";

        let cleanTrack = StringUtils.cleanMusicTitle(track);
        let cleanArtist = artist || "";
        let cacheKey = (cleanTrack + "___" + cleanArtist).toLowerCase();

        if (Object.keys(root.lyricCache).length > 50) {
            root.lyricCache = ({});
        }

        if (root.lyricCache[cacheKey]) {
            root.loading = false;
            root.loadingStatus = "";
            root.parseLyricsResponse(root.lyricCache[cacheKey]);
            return;
        }

        let targetDuration = Math.round(activePlayer?.length || 0);

        if (targetDuration > 0 && cleanArtist !== "") {
            let getUrl = `https://lrclib.net/api/get?track_name=${encodeURIComponent(cleanTrack)}&artist_name=${encodeURIComponent(cleanArtist)}&duration=${targetDuration}`;
            var getXhr = new XMLHttpRequest();
            root.activeGetXhr = getXhr;
            getXhr.onreadystatechange = function() {
                if (getXhr.readyState === XMLHttpRequest.DONE) {
                    if (myFetchId !== root.currentFetchId) return;
                    if (getXhr.status === 200) {
                        try {
                            var data = JSON.parse(getXhr.responseText);
                            if (data && (data.syncedLyrics || data.plainLyrics)) {
                                root.loading = false;
                                root.loadingStatus = "";
                                root.lyricCache[cacheKey] = data;
                                root.parseLyricsResponse(data);
                                root.activeGetXhr = null;
                                return;
                            }
                        } catch(e) {}
                    }
                    root.activeGetXhr = null;
                    root.loadingStatus = "Searching Lyrics…";
                    root.searchLyricsFallback(myFetchId, cleanTrack, cleanArtist, targetDuration, cacheKey);
                }
            };
            getXhr.open("GET", getUrl, true);
            getXhr.setRequestHeader("User-Agent", root._uaVal);
            getXhr.setRequestHeader(root._lcName, root._uaVal);
            getXhr.setRequestHeader(root._xuaName, root._uaVal);
            getXhr.send();
        } else {
            root.loadingStatus = "Searching…";
            root.searchLyricsFallback(myFetchId, cleanTrack, cleanArtist, targetDuration, cacheKey);
        }
    }

    function searchLyricsFallback(fetchId, cleanTrack, cleanArtist, targetDuration, cacheKey) {
        let query = `${cleanTrack} ${cleanArtist}`.trim();
        let url = `https://lrclib.net/api/search?q=${encodeURIComponent(query)}`;
        var xhr = new XMLHttpRequest();
        root.activeSearchXhr = xhr;
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (fetchId !== root.currentFetchId) return;
                root.activeSearchXhr = null;
                if (xhr.status === 200) {
                    try {
                        var results = JSON.parse(xhr.responseText);
                        let best = root.findBestResult(results, cleanTrack, cleanArtist, targetDuration);
                        if (best) {
                            root.loading = false;
                            root.loadingStatus = "";
                            root.lyricCache[cacheKey] = best;
                            root.parseLyricsResponse(best);
                            return;
                        }
                    } catch(e) {}
                }
                if (cleanArtist !== "") {
                    root.searchLyricsTrackOnlyFallback(fetchId, cleanTrack, cleanArtist, targetDuration, cacheKey);
                } else {
                    root.loading = false;
                    root.loadingStatus = "";
                }
            }
        };
        xhr.open("GET", url, true);
        xhr.setRequestHeader("User-Agent", root._uaVal);
        xhr.setRequestHeader(root._lcName, root._uaVal);
        xhr.setRequestHeader(root._xuaName, root._uaVal);
        xhr.send();
    }

    function searchLyricsTrackOnlyFallback(fetchId, cleanTrack, cleanArtist, targetDuration, cacheKey) {
        let url = `https://lrclib.net/api/search?q=${encodeURIComponent(cleanTrack)}`;
        var xhr = new XMLHttpRequest();
        root.activeSearchXhr = xhr;
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (fetchId !== root.currentFetchId) return;
                root.activeSearchXhr = null;
                root.loading = false;
                root.loadingStatus = "";
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
        xhr.setRequestHeader("User-Agent", root._uaVal);
        xhr.setRequestHeader(root._lcName, root._uaVal);
        xhr.setRequestHeader(root._xuaName, root._uaVal);
        xhr.send();
    }

    function parseLyricsResponse(data) {
        if (!data) return;
        let synced = data.syncedLyrics;
        root.hasUnsyncedLyrics = (!synced || synced.length === 0) && data.plainLyrics && data.plainLyrics.length > 0;
        if (synced && synced.length > 0) {
            let lines = synced.split("\n");
            let parsed = [];
            for (let i = 0; i < lines.length; i++) {
                let line = lines[i].trim();
                if (!line) continue;

                let timeMatches = [];
                let timeRegex = /\[((?:\d+:)?\d+:\d+(?:\.\d+)?)\]/g;
                let match;
                let lastIndex = 0;
                while ((match = timeRegex.exec(line)) !== null) {
                    let timeParts = match[1].split(":");
                    let timeSec = 0;
                    if (timeParts.length === 3) {
                        timeSec = (parseFloat(timeParts[0]) || 0) * 3600.0 + (parseFloat(timeParts[1]) || 0) * 60.0 + (parseFloat(timeParts[2]) || 0);
                    } else {
                        timeSec = (parseFloat(timeParts[0]) || 0) * 60.0 + (parseFloat(timeParts[1]) || 0);
                    }
                    timeMatches.push(timeSec);
                    lastIndex = timeRegex.lastIndex;
                }

                if (timeMatches.length > 0) {
                    let text = line.substring(lastIndex).trim();
                    if (text.length === 0) {
                        text = "♪";
                    }
                    for (let t = 0; t < timeMatches.length; t++) {
                        parsed.push({ time: timeMatches[t], text: text });
                    }
                }
            }
            parsed.sort(function(a, b) { return a.time - b.time; });
            root.lyricLines = parsed;
            root.buildGroupIndex();
        }
    }

    function isPlaceholderTitle(title) {
        if (!title) return true;
        let t = title.trim().toLowerCase();
        return t === "spotify"
            || t === "spotify - search"
            || t === "spotify free"
            || t === "spotify premium"
            || t === "spotify - advertisement"
            || t === "advertisement";
    }

    function isSupportedPlayer(player) {
        if (!player) return false;
        let id = (player.identity || "").toLowerCase();
        let entry = (player.desktopEntry || "").toLowerCase();
        let bus = (player.busName || "").toLowerCase();

        let isBrowser = id.includes("firefox") || id.includes("chrome") || id.includes("chromium") || id.includes("brave") || id.includes("opera") || id.includes("edge") || id.includes("zen") || id.includes("thorium") || id.includes("librewolf") || id.includes("waterfox")
                     || entry.includes("firefox") || entry.includes("chrome") || entry.includes("chromium") || entry.includes("brave") || entry.includes("opera") || entry.includes("edge") || entry.includes("zen") || entry.includes("thorium") || entry.includes("librewolf") || entry.includes("waterfox")
                     || bus.includes("firefox") || bus.includes("chrome") || bus.includes("chromium") || bus.includes("brave") || bus.includes("opera") || bus.includes("edge") || bus.includes("zen") || bus.includes("thorium") || bus.includes("librewolf") || bus.includes("waterfox");

        if (isBrowser) return false;
        return (player.trackTitle || "").trim().length > 0;
    }

    function syncTrackChange() {
        let rawTitle = activePlayer?.trackTitle || "";
        let rawArtist = activePlayer?.trackArtist || "";

        if (root.isPlaceholderTitle(rawTitle)) {
            return;
        }

        let cleanTrack = StringUtils.cleanMusicTitle(rawTitle);
        let cleanArtist = rawArtist || "";

        if (cleanTrack !== root.currentTrackName || cleanArtist !== root.currentArtistName) {
            root.currentTrackName = cleanTrack;
            root.currentArtistName = cleanArtist;
            root.lastKnownPosition = activePlayer?.position || 0;
            root.lastKnownTimestamp = Date.now();
            if (root.isSupportedPlayer(activePlayer)) {
                root.fetchLyrics(cleanTrack, cleanArtist);
            } else {
                root.lyricLines = [];
                root.lyricGroupIndex = [];
                root.hasUnsyncedLyrics = false;
                root.currentLyricLine = "";
                root.nextLyricLine = "";
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
        let w = lyricMetrics.advanceWidth;
        if (w <= 0) {
            w = str.length * 8;
        }
        return w;
    }

    function buildGroupIndex() {
        let lines = root.lyricLines;
        if (!lines || lines.length === 0) {
            root.lyricGroupIndex = [];
            return;
        }
        let maxAllowedPx = Math.max(140, (GlobalStates?.topBarMediaWidth ?? 440) - 150);
        root.lastGroupWidth = maxAllowedPx;
        let index = [];
        let i = 0;
        while (i < lines.length) {
            let start = i;
            let groupText = lines[i].text;
            let currentPx = root.measurePixelWidth(groupText);
            let j = i + 1;

            if (currentPx < maxAllowedPx * 0.65) {
                while (j < lines.length) {
                    let nextText = lines[j].text;
                    let candidateText = groupText + " • " + nextText;
                    let candidatePx = root.measurePixelWidth(candidateText);
                    let gap = lines[j].time - lines[j - 1].time;
                    let totalSpan = lines[j].time - lines[start].time;
                    if (gap <= 3.4 && totalSpan <= 7.0 && candidatePx <= maxAllowedPx && nextText !== "♪" && groupText !== "♪" && nextText !== lines[j - 1].text) {
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
                index.push(group);
            }
            i = j;
        }
        root.lyricGroupIndex = index;
    }

    Timer {
        interval: 100
        repeat: true
        running: activePlayer?.playbackState === MprisPlaybackState.Playing && root.lyricLines.length > 0
        onTriggered: {
            let pos = activePlayer?.position || 0;
            let elapsedSec = (Date.now() - root.lastKnownTimestamp) / 1000.0;

            if (pos !== root.lastKnownPosition) {
                if (Math.abs(pos - (root.lastKnownPosition + elapsedSec)) > 1.5) {
                    root.lastKnownPosition = pos;
                    root.lastKnownTimestamp = Date.now();
                    elapsedSec = 0;
                }
            }

            let currentPos = root.lastKnownPosition + elapsedSec;
            let audioSyncPos = Math.max(0, currentPos - 0.3);

            let lines = root.lyricLines;
            let groups = root.lyricGroupIndex;

            // Rebuild groups if bar width changed
            let currentWidth = Math.max(140, (GlobalStates?.topBarMediaWidth ?? 440) - 150);
            if (currentWidth !== root.lastGroupWidth && lines.length > 0) {
                root.buildGroupIndex();
                groups = root.lyricGroupIndex;
            }

            if (!groups || groups.length !== lines.length) return;

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

            if (currIdx >= 0) {
                let currGroup = groups[currIdx];
                let baseText = currGroup.text;

                let identicalCount = 1;
                let rawGroupText = lines[currGroup.startIdx].text;
                if (rawGroupText !== "♪") {
                    for (let k = currGroup.endIdx + 1; k < lines.length; k++) {
                        if (lines[k].text === rawGroupText) {
                            identicalCount++;
                        } else {
                            break;
                        }
                    }
                }

                let isLastOfSeries = identicalCount === 1
                    && currGroup.startIdx === currGroup.endIdx
                    && currGroup.startIdx > 0
                    && lines[currGroup.startIdx - 1].text === rawGroupText;

                if (identicalCount > 1 || isLastOfSeries) {
                    baseText = `${baseText} (x${identicalCount})`;
                }

                let hasNextGroup = currGroup.nextStartIdx < lines.length;
                let nextTime = hasNextGroup ? lines[currGroup.nextStartIdx].time : -1;

                if (hasNextGroup) {
                    let nextGroup = groups[currGroup.nextStartIdx];
                    newNextLine = nextGroup.text;

                    let remaining = Math.max(0, Math.ceil(nextTime - audioSyncPos));

                    if (currGroup.text === "♪") {
                        let prevText = "";
                        for (let p = currGroup.startIdx - 1; p >= 0; p--) {
                            if (lines[p].text !== "♪") {
                                prevText = groups[p].text;
                                break;
                            }
                        }
                        if (remaining > 0) {
                            newCurrentLine = prevText ? `${prevText} (♪ ${remaining}s)` : `♪ ${remaining}s`;
                        } else {
                            newCurrentLine = prevText || "";
                        }
                    } else if (remaining > 0) {
                        let gap = nextTime - lines[currGroup.endIdx].time;
                        let timeSinceStart = audioSyncPos - lines[currGroup.endIdx].time;
                        if (gap > 7.0 && timeSinceStart > 4.0) {
                            newCurrentLine = `${baseText} (♪ ${remaining}s)`;
                        } else {
                            newCurrentLine = baseText;
                        }
                    } else {
                        newCurrentLine = baseText;
                    }
                } else {
                    let trackLen = activePlayer?.length || 0;
                    let remainingInTrack = Math.max(0, Math.ceil(trackLen - audioSyncPos));
                    let tName = activePlayer?.trackTitle || "";
                    let tArtist = activePlayer?.trackArtist || "";
                    let baseInfo = tArtist ? `${tName} ${tArtist}` : tName;

                    if (trackLen > 0 && remainingInTrack > 10.0) {
                        newCurrentLine = baseInfo ? `${baseInfo} (Outro)` : "Outro";
                    } else if (baseText !== "♪") {
                        newCurrentLine = baseText;
                    } else {
                        let lastReal = "";
                        for (let r = currGroup.startIdx - 1; r >= 0; r--) {
                            if (lines[r].text !== "♪") { lastReal = lines[r].text; break; }
                        }
                        newCurrentLine = lastReal;
                    }
                }
            } else if (lines.length > 0) {
                let firstGroup = groups[0];
                newNextLine = firstGroup.text;
                let remaining = Math.max(0, Math.ceil(lines[0].time - audioSyncPos));
                if (remaining > 0 && remaining < 60) {
                    let tName = activePlayer?.trackTitle || "";
                    let tArtist = activePlayer?.trackArtist || "";
                    let baseInfo = tArtist ? `${tName} ${tArtist}` : tName;
                    if (baseInfo) {
                        newCurrentLine = `${baseInfo} (Intro ♪ ${remaining}s)`;
                    } else {
                        newCurrentLine = `(Intro ♪ ${remaining}s)`;
                    }
                }
            }

            if (root.currentLyricLine !== newCurrentLine) root.currentLyricLine = newCurrentLine;
            if (root.nextLyricLine !== newNextLine) root.nextLyricLine = newNextLine;
        }
    }

    Component.onCompleted: {
        root.syncTrackChange();
    }
}
