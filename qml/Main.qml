import QtQuick

Window {
    id: root
    flags: Qt.FramelessWindowHint
    color: "#111111"
    // 初始不显示；全屏显示由 C++ 端 showFullScreen() 控制
    // (避免 visible 与 visibility 属性冲突)

    // ---------- 状态 ----------
    readonly property int cols: 7
    readonly property int rows: 5
    readonly property int perPage: cols * rows
    property int revealId: 0
    property bool dragActive: false
    property int dragRow: -1
    property string filterText: ""
    readonly property bool searching: filterText !== ""
    property int pageCount: Math.max(1, Math.ceil(AppListModel.count / perPage))
    property string wpUrl: ""

    readonly property real cellW: pagesArea.width / cols
    readonly property real cellH: pagesArea.height / rows
    readonly property real iconSize: Math.max(64, Math.min(112, Math.min(cellW, cellH) * 0.54))

    function closeWindow() { root.visible = false }

    function reveal() {
        bgImage.opacity = 0
        bgFade.restart()
        revealId++
    }

    // 壁纸异步就绪后加载
    Connections {
        target: WallpaperBackend
        function onReady() {
            root.wpUrl = WallpaperBackend.url()
            if (root.visible) bgFade.restart()
        }
    }

    // ---------- 拖拽 ----------
    function startDrag(row, icon, name, pt) {
        dragActive = true
        dragRow = row
        ghost.iconSource = icon
        ghost.labelText = name
        ghost.visible = true
        ghost.x = pt.x - ghost.width / 2
        ghost.y = pt.y - ghost.height / 2
    }

    function dragMove(pt) {
        ghost.x = pt.x - ghost.width / 2
        ghost.y = pt.y - ghost.height / 2

        // 拖到屏幕左右边缘 → 自动翻页
        const margin = 70
        if (pt.x < margin && pageView.currentIndex > 0) {
            if (edgeTimer.dir !== -1) { edgeTimer.dir = -1; edgeTimer.restart() }
        } else if (pt.x > root.width - margin && pageView.currentIndex < pageCount - 1) {
            if (edgeTimer.dir !== 1) { edgeTimer.dir = 1; edgeTimer.restart() }
        } else {
            edgeTimer.dir = 0
            edgeTimer.stop()
        }

        // 计算落点格子
        const localX = pt.x - pagesArea.x
        const localY = pt.y - pagesArea.y
        if (localX < 0 || localY < 0 || localX > pagesArea.width || localY > pagesArea.height)
            return
        let col = Math.max(0, Math.min(cols - 1, Math.floor(localX / cellW)))
        let r = Math.max(0, Math.min(rows - 1, Math.floor(localY / cellH)))
        const to = Math.min(pageView.currentIndex * perPage + r * cols + col,
                            AppListModel.count - 1)
        if (to !== dragRow && to >= 0) {
            AppListModel.move(dragRow, to)
            dragRow = to
        }
    }

    function endDrag() {
        ghost.visible = false
        dragActive = false
        dragRow = -1
        edgeTimer.stop()
        edgeTimer.dir = 0
        AppListModel.saveOrder()
    }

    onVisibleChanged: {
        if (visible) {
            AppListModel.ensureLoaded()
            wpUrl = WallpaperBackend.url()
            searchInput.text = ""
            filterText = ""
            AppListModel.filter = ""
            pageView.currentIndex = 0
            reveal()
        } else {
            edgeTimer.stop()
            if (dragActive) { dragActive = false; dragRow = -1; ghost.visible = false }
        }
    }

    // ---------- 背景：模糊壁纸 + 压暗 ----------
    Image {
        id: bgImage
        anchors.fill: parent
        source: root.wpUrl
        fillMode: Image.PreserveAspectCrop
        smooth: true
        opacity: 0
    }
    NumberAnimation {
        id: bgFade
        target: bgImage
        property: "opacity"
        from: 0; to: 1
        duration: 380
        easing.type: Easing.OutCubic
    }
    // 顶部/底部轻微渐变，突出中间内容
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0,0,0,0.28) }
            GradientStop { position: 0.35; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.32) }
        }
    }

    // 最底层空白点击（页眉/页脚区域）关闭
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: if (!root.dragActive) root.closeWindow()
    }

    // ---------- 搜索框 ----------
    Rectangle {
        id: searchBox
        visible: !root.dragActive
        width: 236; height: 34; radius: 17
        color: Qt.rgba(0, 0, 0, 0.30)
        anchors.top: parent.top
        anchors.topMargin: 26
        anchors.horizontalCenter: parent.horizontalCenter

        // 放大镜
        Item {
            x: 12; y: 10; width: 14; height: 14
            Rectangle { width: 10; height: 10; radius: 5; color: "transparent"; border.color: "#c8c8c8"; border.width: 1.4 }
            Rectangle { x: 8; y: 8; width: 6; height: 1.6; radius: 1; color: "#c8c8c8"; rotation: 45 }
        }
        TextInput {
            id: searchInput
            anchors.left: parent.left; anchors.leftMargin: 34
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            color: "white"
            font.pixelSize: 14
            clip: true
            selectByMouse: true
            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: "搜索"
                color: Qt.rgba(1, 1, 1, 0.55)
                font.pixelSize: 14
                visible: searchInput.text === "" && !searchInput.activeFocus
            }
            onTextChanged: { root.filterText = text; AppListModel.filter = text }
            onAccepted: {
                if (AppListModel.count > 0) {
                    AppListModel.launch(AppListModel.idAt(0))
                    root.closeWindow()
                }
            }
        }
    }

    // ---------- 内容区 ----------
    Item {
        id: pagesArea
        anchors.top: parent.top
        anchors.topMargin: 86
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 64
        anchors.left: parent.left
        anchors.leftMargin: 60
        anchors.right: parent.right
        anchors.rightMargin: 60

        // 横向翻页
        ListView {
            id: pageView
            anchors.fill: parent
            visible: !root.searching
            model: root.pageCount
            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: 0
            preferredHighlightEnd: width
            highlightMoveDuration: 420
            maximumFlickVelocity: 2400
            boundsBehavior: Flickable.StopAtBounds
            interactive: !root.dragActive
            clip: true

            delegate: Item {
                width: pageView.width
                height: pageView.height

                // 空白处点击关闭（位移超过 8px 视为滑动不关闭）
                MouseArea {
                    id: blankArea
                    anchors.fill: parent
                    property real px; property real py; property bool moved
                    onPressed: (m) => { px = m.x; py = m.y; moved = false }
                    onPositionChanged: (m) => {
                        if (Math.abs(m.x - px) > 8 || Math.abs(m.y - py) > 8) moved = true
                    }
                    onReleased: if (!moved && !root.dragActive) root.closeWindow()
                    onCanceled: moved = true
                }

                GridView {
                    id: gv
                    anchors.fill: parent
                    interactive: false
                    model: AppListModel.pageModel(index)
                    cellWidth: root.cellW
                    cellHeight: root.cellH
                    clip: true

                    delegate: IconDelegate {}
                    move: Transition {
                        NumberAnimation { properties: "x,y"; duration: 280; easing.type: Easing.OutCubic }
                    }
                    moveDisplaced: Transition {
                        NumberAnimation { properties: "x,y"; duration: 280; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        // 鼠标滚轮 / 触控板滑动翻页（不拦截点击）
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            property double lastFlip: 0
            onWheel: (w) => {
                if (root.searching || root.dragActive) return
                const now = Date.now()
                if (now - lastFlip < 240) return
                const dx = w.angleDelta.x, dy = w.angleDelta.y
                let dir = 0
                if (Math.abs(dx) >= Math.abs(dy)) dir = dx > 0 ? -1 : 1
                else dir = dy > 0 ? -1 : 1
                if (dir < 0 && pageView.currentIndex > 0) {
                    pageView.currentIndex--
                    lastFlip = now
                } else if (dir > 0 && pageView.currentIndex < root.pageCount - 1) {
                    pageView.currentIndex++
                    lastFlip = now
                }
            }
        }

        // 搜索结果
        GridView {
            id: resultsGrid
            anchors.fill: parent
            visible: root.searching
            model: AppListModel
            cellWidth: root.cellW
            cellHeight: root.cellH
            clip: true
            delegate: IconDelegate {}
        }

        Text {
            anchors.centerIn: parent
            visible: root.searching && AppListModel.count === 0
            text: "无结果"
            color: Qt.rgba(1, 1, 1, 0.7)
            font.pixelSize: 22
        }
    }

    // ---------- 底部圆点 ----------
    Row {
        visible: !root.searching && pageCount > 1
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 11

        Repeater {
            model: root.pageCount
            Rectangle {
                width: 8; height: 8; radius: 4
                color: "white"
                opacity: index === pageView.currentIndex ? 0.95 : 0.32
                Behavior on opacity { NumberAnimation { duration: 220 } }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -7
                    onClicked: pageView.currentIndex = index
                }
            }
        }
    }

    // ---------- 拖拽跟随的"幽灵"图标 ----------
    Item {
        id: ghost
        visible: false
        width: root.cellW
        height: root.cellH
        z: 100
        opacity: 0.92
        property string iconSource
        property string labelText

        Column {
            anchors.centerIn: parent
            spacing: 7
            Item {
                width: root.iconSize + 6; height: root.iconSize + 6
                anchors.horizontalCenter: parent.horizontalCenter
                Image {
                    anchors.fill: parent
                    source: ghost.iconSource ? "image://appicon/" + encodeURIComponent(ghost.iconSource) : ""
                    sourceSize: Qt.size(128, 128)
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                }
            }
            Text {
                text: ghost.labelText
                color: "white"
                font.pixelSize: 13
                width: root.cellW * 0.92
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }

    // 边缘自动翻页计时器
    Timer {
        id: edgeTimer
        interval: 420
        property int dir: 0
        onTriggered: {
            if (dir < 0 && pageView.currentIndex > 0)
                pageView.currentIndex--
            else if (dir > 0 && pageView.currentIndex < pageCount - 1)
                pageView.currentIndex++
            dir = 0
        }
    }

    // Esc：有搜索先清空，否则关闭
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (root.filterText !== "") { searchInput.text = "" }
            else root.closeWindow()
        }
    }

    // ---------- 图标组件 ----------
    component IconDelegate: Item {
        width: root.cellW
        height: root.cellH
        opacity: root.dragActive && model.row === root.dragRow ? 0.12 : 1
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Column {
            id: content
            anchors.centerIn: parent
            spacing: 7
            opacity: 0
            scale: 1.16

            Item {
                width: root.iconSize
                height: root.iconSize
                anchors.horizontalCenter: parent.horizontalCenter
                Image {
                    anchors.fill: parent
                    source: "image://appicon/" + encodeURIComponent(model.appIcon)
                    sourceSize: Qt.size(96, 96)
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    smooth: true
                }
            }
            Text {
                text: model.appName
                color: "white"
                font.pixelSize: 13
                width: root.cellW * 0.94
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.55)
            }
        }

        ParallelAnimation {
            id: popIn
            NumberAnimation {
                target: content; property: "opacity"
                from: 0; to: 1; duration: 250; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: content; property: "scale"
                from: 1.16; to: 1; duration: 280; easing.type: Easing.OutCubic
            }
        }
        Timer {
            id: popTimer
            interval: 24 + (model.row % root.perPage) * 15
            onTriggered: popIn.start()
        }
        Connections {
            target: root
            function onRevealIdChanged() { popTimer.restart() }
        }
        // 窗口已可见时创建的委托（如首次显示、翻页新建）也要播放弹出动画
        Component.onCompleted: {
            if (root.visible) popTimer.restart()
        }

        MouseArea {
            id: iconMA
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            hoverEnabled: false
            pressAndHoldInterval: 320
            preventStealing: iconMA.held   // 按住进入拖拽后，阻止翻页手势抢夺事件

            property bool held: false
            property bool moved: false
            property real pressX; property real pressY

            onPressed: (m) => {
                pressX = m.x; pressY = m.y; moved = false
                if (root.dragActive) return
            }
            onPositionChanged: (m) => {
                if (!held && (Math.abs(m.x - pressX) > 6 || Math.abs(m.y - pressY) > 6))
                    moved = true
                if (held)
                    root.dragMove(mapToItem(root, m.x, m.y))
            }
            onPressAndHold: (m) => {
                if (root.dragActive || root.searching) return
                held = true
                root.startDrag(model.row, model.appIcon, model.appName,
                               mapToItem(root, m.x, m.y))
            }
            onReleased: {
                if (held) {
                    held = false
                    root.endDrag()
                } else if (!moved && !root.dragActive) {
                    AppListModel.launch(model.appId)
                    root.closeWindow()
                }
            }
            onCanceled: {
                if (held) { held = false; root.endDrag() }
            }
        }
    }
}
