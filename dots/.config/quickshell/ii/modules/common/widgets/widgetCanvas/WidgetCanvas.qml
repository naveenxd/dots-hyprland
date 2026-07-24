import QtQuick
import qs.modules.common

MouseArea {
    id: root
    property int gridSize: 24
    property bool showGrid: false
    readonly property bool isWidgetCanvas: true
    readonly property bool gridVisible: showGrid

    propagateComposedEvents: true
    onPressed: (mouse) => mouse.accepted = false

    property bool centerXActive: false
    property bool centerYActive: false
    property real activeLeft: -1
    property real activeRight: -1
    property real activeTop: -1
    property real activeBottom: -1

    function setDragging(active) {
        root.showGrid = active
        if (!active) {
            root.centerXActive = false
            root.centerYActive = false
            root.activeLeft = -1
            root.activeRight = -1
            root.activeTop = -1
            root.activeBottom = -1
        }
    }

    function setCenterActive(xActive, yActive) {
        root.centerXActive = xActive
        root.centerYActive = yActive
    }

    function updateActiveEdgeLines(left, right, top, bottom) {
        root.activeLeft = left
        root.activeRight = right
        root.activeTop = top
        root.activeBottom = bottom
    }

    Repeater {
        model: root.gridVisible ? Math.ceil(root.width / root.gridSize) : 0
        delegate: Rectangle {
            required property int index
            x: index * root.gridSize
            width: 1
            height: root.height
            color: Appearance.colors.colLayer0Border
        }
    }

    Repeater {
        model: root.gridVisible ? Math.ceil(root.height / root.gridSize) : 0
        delegate: Rectangle {
            required property int index
            y: index * root.gridSize
            width: root.width
            height: 1
            color: Appearance.colors.colLayer0Border
        }
    }

    Rectangle {
        id: centerLineV
        visible: root.gridVisible
        x: root.width / 2 - width / 2
        width: root.centerXActive ? 2 : 1
        height: root.height
        color: root.centerXActive ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
        opacity: root.centerXActive ? 1 : 0.6

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
        Behavior on width {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    Rectangle {
        id: centerLineH
        visible: root.gridVisible
        y: root.height / 2 - height / 2
        width: root.width
        height: root.centerYActive ? 2 : 1
        color: root.centerYActive ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
        opacity: root.centerYActive ? 1 : 0.6

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
        Behavior on height {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    Rectangle {
        visible: root.gridVisible && root.activeLeft >= 0
        x: root.activeLeft
        y: 0
        width: 1
        height: root.height
        color: Appearance.colors.colPrimary
        opacity: 0.6
    }
    Rectangle {
        visible: root.gridVisible && root.activeRight >= 0
        x: root.activeRight
        y: 0
        width: 1
        height: root.height
        color: Appearance.colors.colPrimary
        opacity: 0.6
    }
    Rectangle {
        visible: root.gridVisible && root.activeTop >= 0
        x: 0
        y: root.activeTop
        width: root.width
        height: 1
        color: Appearance.colors.colPrimary
        opacity: 0.6
    }
    Rectangle {
        visible: root.gridVisible && root.activeBottom >= 0
        x: 0
        y: root.activeBottom
        width: root.width
        height: 1
        color: Appearance.colors.colPrimary
        opacity: 0.6
    }

    Component {
        id: flashLineComponent
        Rectangle {
            id: flashLine
            property bool vertical: true
            property real linePos: 0
            color: Appearance.colors.colPrimary
            x: vertical ? linePos : 0
            y: vertical ? 0 : linePos
            width: vertical ? 2 : root.width
            height: vertical ? root.height : 2

            NumberAnimation on opacity {
                from: 0.9
                to: 0
                duration: 2000
                easing.type: Easing.OutCubic
                running: true
                onFinished: flashLine.destroy()
            }
        }
    }

    function flashLines(verticalPositions, horizontalPositions) {
        for (let i = 0; i < verticalPositions.length; i++)
            flashLineComponent.createObject(root, { vertical: true, linePos: verticalPositions[i] })
        for (let i = 0; i < horizontalPositions.length; i++)
            flashLineComponent.createObject(root, { vertical: false, linePos: horizontalPositions[i] })
    }
}
