import QtQuick
import Quickshell.Io
import qs.Ui
import qs.Commons

Item {
  id: root

  property var bar: null
  property string moduleName: ""
  property var settings: null

  property bool connected: false
  property string activeId: ""
  property string selectedId: ""
  property bool busy: false
  property var servers: []
  property string errorText: ""
  property var stats: ({})
  property bool autoconnectTried: false

  implicitWidth: iconButton.implicitWidth
  implicitHeight: iconButton.implicitHeight

  function labelFor(id) {
    for (var i = 0; i < servers.length; i++) {
      if (servers[i].id === id) return servers[i].label
    }
    return id
  }

  function formatBytes(n) {
    n = Number(n) || 0
    var units = ["Б", "КБ", "МБ", "ГБ", "ТБ"]
    var i = 0
    while (n >= 1024 && i < units.length - 1) { n /= 1024; i++ }
    return (i === 0 ? n.toFixed(0) : n.toFixed(1)) + " " + units[i]
  }

  function formatHandshake(ts) {
    ts = Number(ts) || 0
    if (ts === 0) return ""
    var secs = Math.max(0, Math.floor(Date.now() / 1000 - ts))
    if (secs < 60) return secs + "с"
    if (secs < 3600) return Math.floor(secs / 60) + "м"
    return Math.floor(secs / 3600) + "ч"
  }

  // root.bar has no shellQuote (despite the plugin docs) -- quote locally.
  function shq(value) {
    return "'" + String(value || "").replace(/'/g, "'\\''") + "'"
  }

  function notify(summary, body, urgency) {
    if (!root.bar) return
    var args = "-a " + root.shq("OmneziaVpn")
      + " -i network-vpn"
      + " -u " + root.shq(urgency || "normal")
      + " " + root.shq(summary)
      + " " + root.shq(body || "")
    root.bar.run("notify-send " + args)
  }

  function refreshServers() {
    if (!serversProc.running) serversProc.running = true
  }

  function refreshStatus() {
    if (!statusProc.running) statusProc.running = true
  }

  Process {
    id: serversProc
    command: ["/usr/local/bin/omarchy-vpn-servers", "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        var list = []
        try { list = JSON.parse(text || "[]") } catch (e) { list = [] }
        root.servers = list
        if (root.selectedId === "" && list.length > 0) root.selectedId = list[0].id
      }
    }
  }

  Process {
    id: statusProc
    command: ["/usr/bin/sudo", "-n", "/usr/local/bin/omarchy-vpn-ctl", "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        var data = {}
        try { data = JSON.parse(text || "{}") } catch (e) { data = {} }
        var id = data.iface || ""
        var wasConnected = root.connected
        root.connected = id !== ""
        root.activeId = id
        if (id !== "") root.selectedId = id
        root.stats = root.connected ? data : {}
        if (!wasConnected && !root.connected) root.maybeAutoconnect()
      }
    }
  }

  function connectTo(id) {
    if (root.busy || !id) return
    root.busy = true
    root.selectedId = id
    toggleProc.intent = "up"
    toggleProc.intentId = id
    toggleProc.command = ["/usr/bin/sudo", "-n", "/usr/local/bin/omarchy-vpn-ctl", "up", id]
    toggleProc.running = true
  }

  function disconnectVpn() {
    if (root.busy) return
    root.busy = true
    toggleProc.intent = "down"
    toggleProc.intentId = ""
    toggleProc.command = ["/usr/bin/sudo", "-n", "/usr/local/bin/omarchy-vpn-ctl", "down"]
    toggleProc.running = true
  }

  function maybeAutoconnect() {
    if (root.autoconnectTried) return
    // Manifest-plugin settings use the enum convention ("On"/"Off"); the
    // legacy custom-module path in shell.json is free-form JSON and
    // typically carries a plain boolean. Accept either.
    var v = root.settings && root.settings.autoconnect
    if (!(v === true || v === "On")) return
    root.autoconnectTried = true
    lastProc.running = true
  }

  Process {
    id: lastProc
    command: ["/usr/bin/sudo", "-n", "/usr/local/bin/omarchy-vpn-ctl", "last"]
    stdout: StdioCollector {
      onStreamFinished: {
        var id = text.trim()
        if (id && !root.connected) root.connectTo(id)
      }
    }
  }

  function toggle() {
    if (root.connected) {
      root.disconnectVpn()
      return
    }
    var id = root.selectedId || (root.servers.length > 0 ? root.servers[0].id : "")
    if (!id) root.openAdd()
    else root.connectTo(id)
  }

  Process {
    id: toggleProc
    property string intent: ""
    property string intentId: ""
    stderr: StdioCollector { id: toggleErr; waitForEnd: true }
    onExited: function(code) {
      root.busy = false
      var ok = code === 0
      root.errorText = ok ? "" : (toggleErr.text.trim() || "Ошибка VPN")
      if (intent === "up") {
        if (ok) root.notify("VPN подключён", root.labelFor(intentId))
        else root.notify("Не удалось подключиться", root.errorText, "critical")
      } else if (intent === "down") {
        if (ok) root.notify("VPN отключён", "")
        else root.notify("Ошибка отключения", root.errorText, "critical")
      }
      root.refreshStatus()
    }
  }

  function renameServer(id) {
    popup.open = false
    if (root.bar) root.bar.run("omarchy-launch-floating-terminal-with-presentation omarchy-vpn-rename-server " + id)
  }

  function removeServer(id) {
    if (removeMetaProc.running || removeConfProc.running) return
    removeMetaProc.pendingId = id
    removeMetaProc.command = ["/usr/local/bin/omarchy-vpn-servers", "remove", id]
    removeMetaProc.running = true
  }

  Process {
    id: removeMetaProc
    property string pendingId: ""
    onExited: function(code) {
      root.refreshServers()
      removeConfProc.command = ["/usr/bin/sudo", "-n", "/usr/local/bin/omarchy-vpn-ctl", "remove", removeMetaProc.pendingId]
      removeConfProc.running = true
    }
  }

  Process {
    id: removeConfProc
    onExited: root.refreshStatus()
  }

  function openAdd() {
    popup.open = false
    if (root.bar) root.bar.run("omarchy-launch-floating-terminal-with-presentation omarchy-vpn-add-server")
  }

  // Poll gently while idle in the bar; speed up only while the popup is
  // actually open, where a live-feeling refresh is worth the extra polls.
  Timer {
    interval: popup.open ? 3000 : 20000
    running: true
    repeat: true
    onTriggered: {
      root.refreshStatus()
      if (popup.open) root.refreshServers()
    }
  }

  Component.onCompleted: {
    root.refreshServers()
    root.refreshStatus()
  }

  IpcHandler {
    target: "vpn"

    function open(): void { popup.open = true; root.refreshServers(); root.refreshStatus() }
    function close(): void { popup.open = false }
    function toggle(): void {
      popup.open = !popup.open
      if (popup.open) { root.refreshServers(); root.refreshStatus() }
    }
    function toggleVpn(): void { root.toggle() }
  }

  BarIconButton {
    id: iconButton
    anchors.fill: parent
    bar: root.bar
    text: "󰌆"
    active: root.connected
    tooltipText: root.busy
      ? "AmneziaWG: переключение…"
      : (root.connected ? "AmneziaWG: " + root.labelFor(root.activeId) : "AmneziaWG: отключено")

    onPressed: function(b) {
      if (b === Qt.LeftButton) {
        popup.open = !popup.open
        if (popup.open) { root.refreshServers(); root.refreshStatus() }
      } else if (b === Qt.MiddleButton) {
        root.toggle()
      } else if (b === Qt.RightButton) {
        root.refreshServers()
        root.refreshStatus()
      }
    }
  }

  PopupCard {
    id: popup
    anchorItem: iconButton
    bar: root.bar
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(body.implicitHeight)

    Column {
      id: body
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: Style.space(12)

      Item {
        width: parent.width
        implicitHeight: Math.max(statusIcon.implicitHeight, statusCol.implicitHeight, mainSwitch.implicitHeight)

        Text {
          id: statusIcon
          textFormat: Text.PlainText
          text: "󰌆"
          color: root.connected ? root.bar.urgent : root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.display
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
        }

        ToggleSwitch {
          id: mainSwitch
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          checked: root.connected
          busy: root.busy
          foreground: root.bar.foreground
          onToggled: root.toggle()
        }

        Column {
          id: statusCol
          anchors.left: statusIcon.right
          anchors.leftMargin: Style.space(12)
          anchors.right: mainSwitch.left
          anchors.rightMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            textFormat: Text.PlainText
            text: root.connected ? "Подключено" : "Отключено"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            text: root.busy
              ? "переключение…"
              : (root.connected ? root.labelFor(root.activeId) : (root.errorText || "AmneziaWG"))
            color: root.errorText !== "" && !root.connected ? root.bar.urgent : Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            visible: root.connected && !root.busy && (root.stats.rx !== undefined || root.stats.tx !== undefined)
            text: "↓" + root.formatBytes(root.stats.rx) + " ↑" + root.formatBytes(root.stats.tx)
              + (root.formatHandshake(root.stats.handshake) ? " · " + root.formatHandshake(root.stats.handshake) : "")
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      PanelSeparator { foreground: root.bar.foreground }

      PanelSectionHeader {
        text: "СЕРВЕРЫ"
        foreground: root.bar.foreground
        fontFamily: root.bar.fontFamily
      }

      Column {
        width: parent.width
        spacing: Style.space(4)
        visible: root.servers.length > 0

        Repeater {
          model: root.servers

          Item {
            id: rowItem
            required property var modelData
            width: body.width
            implicitHeight: Style.spacing.controlHeight

            Rectangle {
              anchors.fill: parent
              radius: Style.cornerRadius
              color: rowItem.modelData.id === root.selectedId
                ? Style.selectedFillFor(root.bar.foreground, Color.accent)
                : (rowHover.hovered ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent")
            }

            HoverHandler { id: rowHover }

            Rectangle {
              id: dot
              width: Style.space(8)
              height: width
              radius: width / 2
              anchors.left: parent.left
              anchors.leftMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              color: rowItem.modelData.id === root.activeId
                ? root.bar.urgent
                : Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.25)
            }

            Text {
              textFormat: Text.PlainText
              text: rowItem.modelData.label
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
              anchors.left: dot.right
              anchors.leftMargin: Style.space(8)
              anchors.right: renameBtn.left
              anchors.rightMargin: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
            }

            Button {
              id: renameBtn
              text: "✎"
              tooltipText: "Переименовать"
              foreground: root.bar.foreground
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(2)
              anchors.right: removeBtn.left
              anchors.rightMargin: Style.space(2)
              anchors.verticalCenter: parent.verticalCenter
              onClicked: root.renameServer(rowItem.modelData.id)
            }

            Button {
              id: removeBtn
              text: "×"
              tooltipText: "Удалить сервер"
              foreground: root.bar.foreground
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(2)
              anchors.right: parent.right
              anchors.rightMargin: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              onClicked: root.removeServer(rowItem.modelData.id)
            }

            MouseArea {
              anchors.fill: parent
              anchors.rightMargin: renameBtn.width + removeBtn.width + Style.space(10)
              cursorShape: Qt.PointingHandCursor
              onClicked: root.connectTo(rowItem.modelData.id)
            }
          }
        }
      }

      Text {
        visible: root.servers.length === 0
        textFormat: Text.PlainText
        text: "Серверы не настроены"
        color: Qt.darker(root.bar.foreground, 1.4)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
      }

      PanelSeparator { foreground: root.bar.foreground }

      Button {
        text: "+ Добавить сервер"
        foreground: root.bar.foreground
        bordered: true
        width: parent.width
        onClicked: root.openAdd()
      }
    }
  }
}
