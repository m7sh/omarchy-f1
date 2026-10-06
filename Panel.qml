import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "mush.f1"
  ipcTarget: "mush.f1"
  manageIpc: true

  property var anchorItem: null
  property bool openedFromHotkey: false
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property string scriptPath: Qt.resolvedUrl("fetch_f1.py").toString().replace(/^file:\/\//, "")
  readonly property string cachePath: Quickshell.env("HOME") + "/.cache/omarchy-f1/data.json"
  readonly property string settingsPath: Quickshell.env("HOME") + "/.config/omarchy/settings/f1.json"

  property var f1Data: ({})
  property var settingsData: ({ "notifications_enabled": true, "notify_15m": true, "notify_live": true })
  property string activeTab: "schedule"
  property string standingsTab: "drivers"
  property bool isRefreshing: false

  function parseData(jsonStr) {
    try {
      if (!jsonStr || jsonStr.trim().length === 0) return
      root.f1Data = JSON.parse(jsonStr)
    } catch (err) {
      console.warn("F1 Panel: Error parsing data.json:", err)
    }
  }

  function parseSettings(jsonStr) {
    try {
      if (!jsonStr || jsonStr.trim().length === 0) return
      root.settingsData = JSON.parse(jsonStr)
    } catch (err) {
      console.warn("F1 Panel: Error parsing settings:", err)
    }
  }

  function refresh() {
    if (proc.running) return
    root.isRefreshing = true
    proc.command = [root.scriptPath, "fetch"]
    proc.running = true
  }

  function runPythonAction(action) {
    if (actionProc.running) return
    actionProc.command = [root.scriptPath, action]
    actionProc.running = true
  }

  function toggleNotifications() {
    runPythonAction("toggle-notify")
  }

  function open() {
    openedFromHotkey = false
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
    dataFile.reload()
    settingsFile.reload()
  }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    dataFile.reload()
    settingsFile.reload()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (!root.bar) return
    if (typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
    else if ("centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  FileView {
    id: dataFile
    path: root.cachePath
    watchChanges: true
    printErrors: false
    onLoaded: root.parseData(text())
    onFileChanged: reload()
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onLoaded: root.parseSettings(text())
    onFileChanged: reload()
  }

  Process {
    id: proc
    command: []
    onExited: function(code) {
      root.isRefreshing = false
      dataFile.reload()
    }
  }

  Process {
    id: actionProc
    command: []
    onExited: function(code) {
      dataFile.reload()
      settingsFile.reload()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(Math.max(Style.space(380), Math.min(mainColumn.implicitHeight, Style.space(540))))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -Style.spacing.popupPadding
        anchors.rightMargin: -Style.spacing.popupPadding
        anchors.topMargin: -Style.spacing.popupPadding
        anchors.bottomMargin: -Style.spacing.popupPadding
        color: Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 1.0)
        radius: Style.cornerRadius
        z: -1
      }

      Flickable {
        id: scrollArea
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: mainColumn
          width: scrollArea.width
          spacing: Style.space(12)

          // ---------------- HERO CARD ----------------
          Rectangle {
            width: parent.width
            implicitHeight: heroCol.implicitHeight + Style.space(20)
            radius: Style.cornerRadius
            color: Style.hoverFillFor(Color.foreground, Color.accent)
            border.width: 1
            border.color: !!root.f1Data.isLive ? Color.urgent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)

            Column {
              id: heroCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(12)
              spacing: Style.space(8)

              Row {
                width: parent.width
                spacing: Style.space(10)

                Text {
                  text: root.f1Data.countryFlag || "🏁"
                  font.pixelSize: Style.space(32)
                  anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(2)

                  Text {
                    textFormat: Text.PlainText
                    text: root.f1Data.raceName || "Formula 1 Grand Prix"
                    color: Color.foreground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.title
                    font.bold: true
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: (root.f1Data.round ? ("Round " + root.f1Data.round + " · ") : "")
                          + (root.f1Data.circuitName || "Circuit")
                          + (root.f1Data.locality ? (" · " + root.f1Data.locality + ", " + root.f1Data.country) : "")
                    color: Qt.darker(Color.foreground, 1.4)
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                  }
                }
              }

              // Status Banner
              Rectangle {
                width: parent.width
                implicitHeight: Style.space(28)
                radius: Math.min(Style.cornerRadius, Style.space(6))
                color: !!root.f1Data.isLive
                  ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.2)
                  : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)

                Row {
                  anchors.centerIn: parent
                  spacing: Style.space(8)

                  Rectangle {
                    visible: !!root.f1Data.isLive
                    width: Style.space(8)
                    height: Style.space(8)
                    radius: Style.space(4)
                    color: Color.urgent
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on opacity {
                      running: !!root.f1Data.isLive
                      loops: Animation.Infinite
                      NumberAnimation { to: 0.3; duration: 500 }
                      NumberAnimation { to: 1.0; duration: 500 }
                    }
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: !!root.f1Data.isLive
                      ? ("🔴 LIVE NOW · " + (root.f1Data.activeSession ? root.f1Data.activeSession.name : "Session in progress"))
                      : (root.f1Data.nextSession
                          ? ("Next: " + root.f1Data.nextSession.name + " (" + root.f1Data.nextSession.localTimeFull + ")  ·  in " + root.f1Data.nextSession.countdownStr)
                          : "Race weekend completed")
                    color: !!root.f1Data.isLive ? Color.urgent : Color.foreground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }
            }
          }

          // ---------------- TAB BAR ----------------
          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(8)

            ButtonGroup {
              options: [
                { value: "schedule", label: "Schedule 🏎️" },
                { value: "standings", label: "Standings 🏆" },
                { value: "alerts", label: "Alerts 🔔" }
              ]
              value: root.activeTab
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onChanged: function(val) { root.activeTab = val }
            }
          }

          // ---------------- SCHEDULE TAB ----------------
          Column {
            visible: root.activeTab === "schedule"
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              text: "WEEKEND SESSIONS (LOCAL TIME)"
              foreground: Color.foreground
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            }

            Repeater {
              model: root.f1Data.sessions || []

              Rectangle {
                required property var modelData
                required property int index

                width: parent.width
                implicitHeight: Math.max(sessionLeftRow.implicitHeight, statusPill.implicitHeight) + Style.space(16)
                radius: Math.min(Style.cornerRadius, 6)
                color: modelData.status === "live"
                  ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.18)
                  : Style.hoverFillFor(Color.foreground, Color.accent)
                border.width: modelData.status === "live" ? 1 : 0
                border.color: Color.urgent

                Row {
                  id: sessionLeftRow
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(12)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(12)

                  Text {
                    text: modelData.type === "race" ? "🏁" : (modelData.type === "qualifying" ? "⏱️" : "🏎️")
                    font.pixelSize: Style.space(20)
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(2)

                    Text {
                      textFormat: Text.PlainText
                      text: modelData.name
                      color: Color.foreground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: modelData.status === "live" || modelData.type === "race"
                    }

                    Text {
                      textFormat: Text.PlainText
                      text: modelData.localTimeFull
                      color: Qt.darker(Color.foreground, 1.5)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                    }
                  }
                }

                Rectangle {
                  id: statusPill
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(12)
                  anchors.verticalCenter: parent.verticalCenter
                  implicitWidth: statusText.implicitWidth + Style.space(14)
                  implicitHeight: Style.space(24)
                  radius: Style.space(12)
                  color: modelData.status === "live"
                    ? Color.urgent
                    : (modelData.status === "upcoming"
                        ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
                        : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))

                  Text {
                    id: statusText
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: modelData.status === "live"
                      ? "LIVE NOW"
                      : (modelData.status === "upcoming" ? ("in " + modelData.countdownStr) : "✓ Done")
                    color: modelData.status === "live" ? "#ffffff" : (modelData.status === "upcoming" ? Color.accent : Qt.darker(Color.foreground, 1.6))
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }
            }
          }

          // ---------------- STANDINGS TAB ----------------
          Column {
            visible: root.activeTab === "standings"
            width: parent.width
            spacing: Style.space(6)

            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(8)

              ButtonGroup {
                options: [
                  { value: "drivers", label: "Drivers" },
                  { value: "constructors", label: "Constructors" }
                ]
                value: root.standingsTab
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                onChanged: function(val) { root.standingsTab = val }
              }
            }

            // DRIVERS LIST
            Column {
              visible: root.standingsTab === "drivers"
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: root.f1Data.drivers || []

                Rectangle {
                  required property var modelData
                  required property int index

                  width: parent.width
                  implicitHeight: Style.space(36)
                  radius: Math.min(Style.cornerRadius, 4)
                  color: index % 2 === 0 ? "transparent" : Style.hoverFillFor(Color.foreground, Color.accent)

                  Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(10)

                    Text {
                      width: Style.space(24)
                      text: index === 0 ? "🥇" : (index === 1 ? "🥈" : (index === 2 ? "🥉" : (index + 1)))
                      color: Color.foreground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: index < 3
                      horizontalAlignment: Text.AlignHCenter
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                      width: Style.space(3)
                      height: Style.space(18)
                      radius: Style.space(1.5)
                      color: modelData.teamColor || Color.accent
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(1)

                      Row {
                        spacing: Style.space(6)
                        Text {
                          textFormat: Text.PlainText
                          text: modelData.code
                          color: Color.foreground
                          font.family: root.bar ? root.bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.body
                          font.bold: true
                        }
                        Text {
                          textFormat: Text.PlainText
                          text: modelData.name
                          color: Color.foreground
                          font.family: root.bar ? root.bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.bodySmall
                        }
                      }

                      Text {
                        textFormat: Text.PlainText
                        text: modelData.team
                        color: Qt.darker(Color.foreground, 1.6)
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                      }
                    }
                  }

                  Column {
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(1)

                    Text {
                      textFormat: Text.PlainText
                      text: modelData.points + " pts"
                      color: Color.foreground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: true
                      horizontalAlignment: Text.AlignRight
                      anchors.right: parent.right
                    }

                    Text {
                      textFormat: Text.PlainText
                      text: modelData.wins + " wins"
                      color: Qt.darker(Color.foreground, 1.6)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      horizontalAlignment: Text.AlignRight
                      anchors.right: parent.right
                    }
                  }
                }
              }
            }

            // CONSTRUCTORS LIST
            Column {
              visible: root.standingsTab === "constructors"
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: root.f1Data.constructors || []

                Rectangle {
                  required property var modelData
                  required property int index

                  width: parent.width
                  implicitHeight: Style.space(36)
                  radius: Math.min(Style.cornerRadius, 4)
                  color: index % 2 === 0 ? "transparent" : Style.hoverFillFor(Color.foreground, Color.accent)

                  Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(10)

                    Text {
                      width: Style.space(24)
                      text: index === 0 ? "🥇" : (index === 1 ? "🥈" : (index === 2 ? "🥉" : (index + 1)))
                      color: Color.foreground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: index < 3
                      horizontalAlignment: Text.AlignHCenter
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                      width: Style.space(4)
                      height: Style.space(18)
                      radius: Style.space(2)
                      color: modelData.teamColor || Color.accent
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                      textFormat: Text.PlainText
                      text: modelData.name
                      color: Color.foreground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: true
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  Column {
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(1)

                    Text {
                      textFormat: Text.PlainText
                      text: modelData.points + " pts"
                      color: Color.foreground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: true
                      horizontalAlignment: Text.AlignRight
                      anchors.right: parent.right
                    }

                    Text {
                      textFormat: Text.PlainText
                      text: modelData.wins + " wins"
                      color: Qt.darker(Color.foreground, 1.6)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      horizontalAlignment: Text.AlignRight
                      anchors.right: parent.right
                    }
                  }
                }
              }
            }
          }

          // ---------------- ALERTS TAB ----------------
          Column {
            visible: root.activeTab === "alerts"
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "RACE NOTIFICATIONS & REMINDERS"
              foreground: Color.foreground
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            }

            Rectangle {
              width: parent.width
              implicitHeight: Style.space(60)
              radius: Math.min(Style.cornerRadius, 6)
              color: Style.hoverFillFor(Color.foreground, Color.accent)

              Column {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(12)
                anchors.right: toggleSwitch.left
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Text {
                  textFormat: Text.PlainText
                  text: "Session Alerts (15m & Lights Out)"
                  color: Color.foreground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                Text {
                  textFormat: Text.PlainText
                  text: "Get native desktop notifications 15 minutes before Practice, Quali & Race start, and when the session goes live."
                  color: Qt.darker(Color.foreground, 1.5)
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                  width: parent.width
                }
              }

              ToggleSwitch {
                id: toggleSwitch
                anchors.right: parent.right
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                checked: root.settingsData.notifications_enabled !== false
                onToggled: root.toggleNotifications()
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(10)

              Button {
                text: "Send Test Alert 🔔"
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                onClicked: root.runPythonAction("notify-test")
              }

              Button {
                text: "Send Race Summary 🏎️"
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                onClicked: root.runPythonAction("quick-notify")
              }
            }
          }

          // ---------------- FOOTER ----------------
          PanelSeparator {
            foreground: Color.foreground
          }

          Item {
            width: parent.width
            implicitHeight: refreshBtn.implicitHeight

            Text {
              textFormat: Text.PlainText
              text: "Updated: " + (root.f1Data.lastUpdated || "—") + "  ·  Press Esc to close"
              color: Qt.darker(Color.foreground, 1.6)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Button {
              id: refreshBtn
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.isRefreshing ? "Refreshing…" : "Refresh ⟳"
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: root.refresh()
            }
          }
        }
      }
    }
  }
}
