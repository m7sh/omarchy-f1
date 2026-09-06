import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "mush.f1"

  readonly property string scriptPath: Qt.resolvedUrl("fetch_f1.py").toString().replace(/^file:\/\//, "")
  readonly property string cachePath: Quickshell.env("HOME") + "/.cache/omarchy-f1/data.json"

  property var f1Data: ({})
  property string barText: "🏎️  F1"
  property string tooltipText: "Formula 1 Hub"
  property bool isLive: false
  property string pillStatus: "idle"

  function parseData(jsonStr) {
    try {
      if (!jsonStr || jsonStr.trim().length === 0) return
      var parsed = JSON.parse(jsonStr)
      root.f1Data = parsed
      root.barText = parsed.barText || "🏎️  F1"
      root.tooltipText = parsed.tooltip || "Formula 1 Hub"
      root.isLive = !!parsed.isLive
      root.pillStatus = parsed.pillStatus || "idle"
    } catch (err) {
      console.warn("F1 BarWidget: Error parsing data.json:", err)
    }
  }

  function refresh() {
    if (!fetchProcess.running) {
      fetchProcess.command = [root.scriptPath, "fetch"]
      fetchProcess.running = true
    }
  }

  function sendQuickNotification() {
    if (!notifyProcess.running) {
      notifyProcess.command = [root.scriptPath, "quick-notify"]
      notifyProcess.running = true
    }
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item && panelLoader.item.closeForPopoutSwitch) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Component.onCompleted: {
    injectPanel()
    Qt.callLater(injectPanel)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  FileView {
    path: root.cachePath
    watchChanges: true
    printErrors: false
    onLoaded: root.parseData(text())
    onFileChanged: reload()
  }

  Process {
    id: fetchProcess
    command: []
  }

  Process {
    id: notifyProcess
    command: []
  }

  // Auto-refresh every 5 minutes
  Timer {
    interval: 5 * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barText
    active: root.isLive
    activeColor: Color.urgent
    tooltipText: root.tooltipText

    Component.onCompleted: root.injectPanel()

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) {
        root.sendQuickNotification()
      } else if (mouseButton === Qt.MiddleButton) {
        root.refresh()
      } else {
        root.togglePanel()
      }
    }
  }
}
