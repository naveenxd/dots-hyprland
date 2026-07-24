pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.common.functions as CF
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.modules.ii.background.widgets
import qs.modules.ii.background.widgets.clock
import qs.modules.ii.background.widgets.weather
import qs.modules.ii.background.widgets.visualizer
import qs.modules.ii.background.widgets.media
import qs.modules.ii.background.widgets.resources
import qs.modules.ii.background.widgets.usercard
import qs.modules.ii.background.widgets.calendar
import qs.modules.ii.background.widgets.images
import qs.modules.ii.background.widgets.worldclock

Scope {
    id: root

    property list<real> visualizerPoints: Array.from({length: 50}, () => 0)

    // shut off cava when no monitor is showing the BG
    readonly property bool anyMonitorShowingBackground: {
        return Quickshell.screens.some(screen => {
            const monitor = Hyprland.monitorFor(screen);
            const workspaces = Hyprland.workspaces.values.filter(ws => ws.monitor && ws.monitor.name === monitor.name);
            const activeWS = workspaces.find(ws => ws.active);
            if (!activeWS) return true;

            const hasFullscreen = activeWS.toplevels.values.some(win => win.wayland?.fullscreen);
            return GlobalStates.screenLocked || !hasFullscreen || !Config?.options.background.hideWhenFullscreen;
        });
    }

    // Cava process
    Process {
        id: cavaProc
        running: (Config?.options?.background?.widgets?.visualizer?.enable ?? false) && root.anyMonitorShowingBackground
        onRunningChanged: {
            // Reset bars to zero when cava stops
            if (!cavaProc.running)
                root.visualizerPoints = Array.from({length: 50}, () => 0);
        }
        command: ["cava", "-p", `${CF.FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/raw_output_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                const points = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p));
                if (points.length > 0)
                    root.visualizerPoints = points;
            }
        }
    }

    Variants {
        id: screens
        model: Quickshell.screens

    PanelWindow {
        id: bgRoot

        required property var modelData

        // Hide when fullscreen
        property list<HyprlandWorkspace> workspacesForMonitor: Hyprland.workspaces.values.filter(workspace => workspace.monitor && workspace.monitor.name == monitor.name)
        property var activeWorkspaceWithFullscreen: workspacesForMonitor.filter(workspace => ((workspace.toplevels.values.filter(window => window.wayland?.fullscreen)[0] != undefined) && workspace.active))[0]
        visible: GlobalStates.screenLocked || (!(activeWorkspaceWithFullscreen != undefined)) || !Config?.options.background.hideWhenFullscreen

        // Workspaces
        property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)
        property list<var> relevantWindows: HyprlandData.windowList.filter(win => win.monitor == monitor?.id && win.workspace.id >= 0).sort((a, b) => a.workspace.id - b.workspace.id)
        property int firstWorkspaceId: relevantWindows[0]?.workspace.id || 1
        property int lastWorkspaceId: relevantWindows[relevantWindows.length - 1]?.workspace.id || 10
        property int workspaceChunkSize: Config?.options.bar.workspaces.shown ?? 10
        property int totalWorkspaces: Math.ceil(lastWorkspaceId / workspaceChunkSize) * workspaceChunkSize
        // Wallpaper
        property var shaderList: ["circlePit", "circleSelect", "magic", "Doom", "Peel", "transition", "pixelate", "stripes"]
        property string currentShader: "pixelate"
        property string wallpaperAnimation: Config.options.background.wallpaperAnimation ?? "random"
        property string currentWallpaperSource: Config.options.background.wallpaperPath
        property string previousWallpaperSource: ""
        property real transitionProgress: 1.0

        property bool wallpaperIsVideo: resolvedPath.endsWith(".mp4") || resolvedPath.endsWith(".webm") || resolvedPath.endsWith(".mkv") || resolvedPath.endsWith(".avi") || resolvedPath.endsWith(".mov")
        property var wallpaperData: WallpaperListener.effectivePerMonitor[monitor.name] || { path: Config.options.background.wallpaperPath, workspaceFirst: 1, workspaceLast: 10 }
        property string resolvedPath: wallpaperData.path || Config.options.background.wallpaperPath
        property int wallpaperFirstWorkspace: wallpaperData.workspaceFirst || 1
        property int wallpaperLastWorkspace: wallpaperData.workspaceLast || 10
        property string wallpaperPath: wallpaperIsVideo ? Config.options.background.thumbnailPath : resolvedPath
        property bool wallpaperSafetyTriggered: {
            const enabled = Config.options.workSafety.enable.wallpaper;
            const sensitiveWallpaper = (CF.StringUtils.stringListContainsSubstring(wallpaperPath.toLowerCase(), Config.options.workSafety.triggerCondition.fileKeywords));
            const sensitiveNetwork = (CF.StringUtils.stringListContainsSubstring(Network.networkName.toLowerCase(), Config.options.workSafety.triggerCondition.networkNameKeywords));
            return enabled && sensitiveWallpaper && sensitiveNetwork;
        }

        onWallpaperPathChanged: {
            bgRoot.updateZoomScale();

            if (bgRoot.wallpaperAnimation === "" || bgRoot.wallpaperSafetyTriggered) {
                wallpaper.source = wallpaperPath
                bgRoot.currentWallpaperSource = wallpaperPath
                bgRoot.transitionProgress = 1.0
                return
            }

            previousWallpaper.source = bgRoot.currentWallpaperSource
            wallpaper.source = wallpaperPath
            bgRoot.currentWallpaperSource = wallpaperPath

            if (bgRoot.wallpaperAnimation === "random") {
                bgRoot.currentShader = bgRoot.shaderList[Math.floor(Math.random() * bgRoot.shaderList.length)]
            } else {
                bgRoot.currentShader = bgRoot.wallpaperAnimation
            }
            bgRoot.transitionProgress = 0.0
            transitionAnim.start()
        }

        NumberAnimation {
            id: transitionAnim
            target: bgRoot
            property: "transitionProgress"
            from: 0.0
            to: 1.0
            duration: 1200
            easing.type: Easing.InOutCubic
            onFinished: {
                previousWallpaper.source = ""
                bgRoot.previousWallpaperSource = ""
                bgRoot.transitionProgress = 1.0
            }
        }
        readonly property real parallaxRation: Config.options.background.parallax.workspaceZoom
        property real minSuitableScale: 1 // Some reasonable init, to be updated
        property real effectiveWallpaperScale: minSuitableScale * parallaxRation
        property int wallpaperWidth: modelData.width // Some reasonable init value, to be updated
        property int wallpaperHeight: modelData.height // Some reasonable init value, to be updated
        property real scaledWallpaperWidth: wallpaperWidth * effectiveWallpaperScale
        property real scaledWallpaperHeight: wallpaperHeight * effectiveWallpaperScale
        property real parallaxTotalPixelsX: Math.max(0, scaledWallpaperWidth - screen.width)
        property real parallaxTotalPixelsY: Math.max(0, scaledWallpaperHeight - screen.height)
        readonly property bool verticalParallax: (Config.options.background.parallax.autoVertical && wallpaperHeight > wallpaperWidth) || Config.options.background.parallax.vertical
        // Colors
        property bool shouldBlur: (GlobalStates.screenLocked && Config.options.lock.blur.enable)
        property color dominantColor: Appearance.colors.colPrimary // Default, to be changed
        property bool dominantColorIsDark: dominantColor.hslLightness < 0.5
        property color colText: {
            if (wallpaperSafetyTriggered)
                return CF.ColorUtils.mix(Appearance.colors.colOnLayer0, Appearance.colors.colPrimary, 0.75);
            return (GlobalStates.screenLocked && shouldBlur) ? Appearance.colors.colOnLayer0 : CF.ColorUtils.colorWithLightness(Appearance.colors.colPrimary, (dominantColorIsDark ? 0.8 : 0.12));
        }
        Behavior on colText {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        // Layer props
        screen: modelData
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: (GlobalStates.screenLocked && !(scaleAnim?.running ?? false)) ? WlrLayer.Overlay : WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:background"
        WlrLayershell.keyboardFocus: GlobalStates.desktopWidgetKeyboardFocus
            ? WlrKeyboardFocus.OnDemand
            : WlrKeyboardFocus.None
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: {
            if (!bgRoot.wallpaperSafetyTriggered || bgRoot.wallpaperIsVideo)
                return "transparent";
            return CF.ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colPrimary, 0.75);
        }
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        // Wallpaper zoom scale
        function updateZoomScale() {
            getWallpaperSizeProc.path = bgRoot.wallpaperPath;
            getWallpaperSizeProc.running = true;
        }
        Process {
            id: getWallpaperSizeProc
            property string path: bgRoot.wallpaperPath
            command: ["magick", "identify", "-format", "%w %h", path]
            stdout: StdioCollector {
                id: wallpaperSizeOutputCollector
                onStreamFinished: {
                    const output = wallpaperSizeOutputCollector.text;
                    const [width, height] = output.split(" ").map(Number);
                    const [screenWidth, screenHeight] = [bgRoot.screen.width, bgRoot.screen.height];
                    bgRoot.wallpaperWidth = width;
                    bgRoot.wallpaperHeight = height;

                    // Perfect image; scale = 1
                    // Small picture; scale > 1; will zoom in the picture
                    // Big picture; scale < 1; will zoom out the picture
                    // Choose max number so every side will fit
                    bgRoot.minSuitableScale = Math.max(screenWidth / width, screenHeight / height);
                }
            }
        }

        Item {
            anchors.fill: parent

            Image {
                id: previousWallpaper
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                cache: true
                smooth: true
                asynchronous: true
                layer.enabled: true
                visible: false
            }

            // Wallpaper
            StyledImage {
                id: wallpaper
                layer.enabled: true
                visible: (bgRoot.wallpaperAnimation === "" || bgRoot.transitionProgress >= 1.0) && opacity > 0 && !blurLoader.active
                opacity: (status === Image.Ready && !bgRoot.wallpaperIsVideo) ? 1 : 0
                cache: false
                smooth: false
                // Use per-monitor workspace range if multiMonitor is enabled, otherwise use dynamic global range
                property bool usePerMonitorRange: WallpaperListener.multiMonitorEnabled &&
                    (wallpaperData.workspaceFirst !== undefined && wallpaperData.workspaceLast !== undefined)
                property int lower: usePerMonitorRange ? bgRoot.wallpaperFirstWorkspace : bgRoot.firstWorkspaceId
                property int upper: usePerMonitorRange ? bgRoot.wallpaperLastWorkspace : bgRoot.lastWorkspaceId
                property int workspacesRange: upper - lower
                property int workspaceIndex: (bgRoot.monitor.activeWorkspace?.id ?? lower) - lower
                property real middleFraction: 0.5
                property real fraction: {
                    if (workspacesRange <= 0) {
                        return middleFraction;
                    }
                    return Math.max(0, Math.min(1, workspaceIndex / workspacesRange));
                }

                property real usedFractionX: {
                    let usedFraction = middleFraction;
                    if (Config.options.background.parallax.enableWorkspace && !bgRoot.verticalParallax) {
                        usedFraction = fraction;
                    }
                    if (Config.options.background.parallax.enableSidebar) {
                        let sidebarFraction = bgRoot.parallaxRation / bgRoot.workspaceChunkSize / 2;
                        usedFraction += (sidebarFraction * GlobalStates.sidebarRightOpen - sidebarFraction * GlobalStates.sidebarLeftOpen);
                    }
                    return Math.max(0, Math.min(1, usedFraction));
                }
                property real usedFractionY: {
                    let usedFraction = middleFraction;
                    if (Config.options.background.parallax.enableWorkspace && bgRoot.verticalParallax) {
                        usedFraction = fraction;
                    }
                    return Math.max(0, Math.min(1, usedFraction));
                }

                x: {
                    if (bgRoot.screen.width > width) {
                        // Center the picture
                        return (bgRoot.screen.width - width) / 2;
                    }
                    return - bgRoot.parallaxTotalPixelsX * usedFractionX;
                }
                y: {
                    if (bgRoot.screen.height > height) {
                        // Center the picture
                        return (bgRoot.screen.height - height) / 2;
                    }
                    return - bgRoot.parallaxTotalPixelsY * usedFractionY;
                }

                source: bgRoot.wallpaperSafetyTriggered ? "" : bgRoot.wallpaperPath
                fillMode: Image.PreserveAspectCrop
                Behavior on x {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
                width: bgRoot.scaledWallpaperWidth
                height: bgRoot.scaledWallpaperHeight
            }

            ShaderEffect {
                id: transitionEffect
                anchors.fill: parent
                visible: !blurLoader.active && bgRoot.wallpaperAnimation !== "" && bgRoot.transitionProgress < 1.0
                property var fromImage: previousWallpaper
                property var toImage: wallpaper
                property real progress: bgRoot.transitionProgress
                property real aspectX: width / height
                property real aspectY: 1.0
                property vector2d aspectRatio: Qt.vector2d(aspectX, aspectY)
                property vector2d origin: Qt.vector2d(0.5, 0.5)
                fragmentShader: bgRoot.wallpaperAnimation !== ""
                    ? Qt.resolvedUrl(`shaders/${bgRoot.currentShader}.frag.qsb`)
                    : ""
            }

            Loader {
                id: blurLoader
                active: Config.options.lock.blur.enable && (GlobalStates.screenLocked || scaleAnim.running)
                anchors.fill: wallpaper
                scale: GlobalStates.screenLocked ? Config.options.lock.blur.extraZoom : 1
                Behavior on scale {
                    NumberAnimation {
                        id: scaleAnim
                        duration: 400
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                    }
                }
                sourceComponent: GaussianBlur {
                    source: wallpaper
                    radius: GlobalStates.screenLocked ? Config.options.lock.blur.radius : 0
                    samples: radius * 2 + 1

                    Rectangle {
                        opacity: GlobalStates.screenLocked ? 1 : 0
                        anchors.fill: parent
                        color: CF.ColorUtils.transparentize(Appearance.colors.colLayer0, 0.7)
                    }
                }
            }

            WidgetCanvas {
                id: widgetCanvas
                z: 1
                width: parent.width
                height: parent.height
                readonly property real parallaxFactor: {
                    var f = Config.options.background.parallax.widgetsFactor;
                    return f / bgRoot.parallaxRation;
                }
                readonly property real baseWallpaperOffsetX: (bgRoot.screen.width - wallpaper.width) / 2
                readonly property real baseWallpaperOffsetY: (bgRoot.screen.height - wallpaper.height) / 2
                readonly property real wallpaperTotalOffsetX: wallpaper.x - baseWallpaperOffsetX
                readonly property real wallpaperTotalOffsetY: wallpaper.y - baseWallpaperOffsetY
                readonly property bool locked: GlobalStates.screenLocked
                x: wallpaperTotalOffsetX * parallaxFactor * !locked
                y: wallpaperTotalOffsetY * parallaxFactor * !locked

                transitions: Transition {
                    PropertyAnimation {
                        properties: "width,height"
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                    AnchorAnimation {
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.weather.enable
                    sourceComponent: WeatherWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.clock.enable
                    sourceComponent: ClockWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                        wallpaperSafetyTriggered: bgRoot.wallpaperSafetyTriggered
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.media?.enable ?? false
                    sourceComponent: MediaWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.resources?.enable ?? false
                    sourceComponent: ResourcesWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.userCard?.enable ?? false
                    sourceComponent: UserCardWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.calendar?.enable ?? false
                    sourceComponent: CalendarWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.customImage?.enable ?? false
                    sourceComponent: CustomImage {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.images?.enable ?? false
                    sourceComponent: ImageConverterWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.worldClock?.enable ?? false
                    sourceComponent: WorldClockWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }
            }

            FadeLoader {
                id: visualizerLoader
                z: 0

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: Config.options.background.widgets.visualizer.height

                readonly property var vizConfig: Config?.options?.background?.widgets?.visualizer
                shown: vizConfig?.enable && (!GlobalStates.screenLocked || vizConfig?.showWhenLocked)

                sourceComponent: VisualizerWidget {
                    anchors.fill: parent

                    points: root.visualizerPoints
                    primaryColor: Appearance.colors.colPrimary
                    shown: visualizerLoader.shown

                    scaledScreenWidth: bgRoot.screen.width / bgRoot.effectiveWallpaperScale
                    scaledScreenHeight: bgRoot.screen.height / bgRoot.effectiveWallpaperScale
                }
            }

            MouseArea {
                id: desktopRightClickArea
                anchors.fill: parent
                z: -2
                acceptedButtons: Qt.RightButton
                propagateComposedEvents: true
                onClicked: (mouse) => {
                    GlobalStates.desktopMenuScreen = bgRoot.screen
                    GlobalStates.desktopMenuX = mouse.x
                    GlobalStates.desktopMenuY = mouse.y
                    GlobalStates.desktopMenuOpen = true
                }
            }
        }
    }
}
}
