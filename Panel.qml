import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui
import "MediaPanelModel.js" as Model

// Now-playing bar widget. Sits in the bar as a single icon like Audio and
// Network, and opens a panel with the full track detail and transport
// controls. All MPRIS work is delegated to the first-party omarchy.media
// service; this plugin owns presentation only, so the service keeps getting
// upstream fixes.
Panel {
  id: root
  moduleName: "io.github.sumdahl.media"
  ipcTarget: "io.github.sumdahl.media"

  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("omarchy.media")
  readonly property var activePlayer: mediaService ? mediaService.activePlayer : null
  readonly property var sourcePlayers: mediaService ? mediaService.sourcePlayers : []

  // Same condition the built-in media widget uses: a player is only "media"
  // once it reports something nameable. A paused track still counts, so the
  // icon does not vanish from under the cursor mid-pause.
  readonly property bool hasMedia: !!(activePlayer && (activePlayer.trackTitle || activePlayer.trackArtist))
  readonly property bool playing: !!(activePlayer && activePlayer.isPlaying)
  readonly property bool spotify: Model.isSpotify(activePlayer)

  readonly property int artSize: Number(setting("artSize", 96))
  readonly property bool showProgress: setting("showProgress", true) === true
  readonly property bool showSourcePicker: setting("showSourcePicker", true) === true
  readonly property bool spotifyAccent: setting("spotifyAccent", true) === true

  // Spotify green, resolved once here so every accent-tinted element agrees.
  readonly property color accentColor: spotify && spotifyAccent ? "#1db954" : Color.accent

  readonly property string title: Model.displayTitle(activePlayer)
  readonly property string artist: activePlayer ? String(activePlayer.trackArtist || "") : ""
  readonly property string album: activePlayer ? String(activePlayer.trackAlbum || "") : ""
  readonly property string secondary: Model.secondaryLine(activePlayer)
  readonly property string artUrl: activePlayer ? String(activePlayer.trackArtUrl || "") : ""

  readonly property bool canSeek: !!(activePlayer && activePlayer.canSeek && Model.hasPosition(activePlayer))
  readonly property bool hasProgress: showProgress && Model.hasPosition(activePlayer)
  readonly property real trackLength: activePlayer && activePlayer.length ? Number(activePlayer.length) : 0

  // Mirrored rather than bound: Quickshell only refreshes MprisPlayer.position
  // when asked, and Spotify never emits Seeked, so a timer drives it while the
  // panel is open. Bindings straight to activePlayer.position would sit still.
  property real livePosition: 0
  property bool seeking: false

  // Keyboard cursor over the source rows, mirroring the audio panel.
  property bool cursorActive: false
  property int selectedSource: 0

  visible: hasMedia
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function syncPosition() {
    if (seeking) return
    livePosition = activePlayer && activePlayer.positionSupported ? Number(activePlayer.position) : 0
  }

  function runAction(action) {
    if (!mediaService || !activePlayer) return
    mediaService.runAction(action, false, mediaService.playerKey(activePlayer))
  }

  function seekTo(seconds) {
    if (!canSeek) return
    activePlayer.position = seconds
    // Spotify advertises CanSeek but its Linux client often ignores the write.
    // Re-reading on the next tick lets the bar snap back to the truth rather
    // than sitting on a position the player never accepted.
    positionTimer.restart()
  }

  function toggleShuffle() {
    if (activePlayer && activePlayer.shuffleSupported) activePlayer.shuffle = !activePlayer.shuffle
  }

  function cycleLoop() {
    if (activePlayer && activePlayer.loopSupported)
      activePlayer.loopState = Model.nextLoopState(activePlayer.loopState)
  }

  // Focus the player's own window; fall back to its web URL when the player
  // cannot be raised (browser-backed players, mostly).
  function focusPlayer() {
    if (activePlayer && activePlayer.canRaise) {
      activePlayer.raise()
      root.close()
      return
    }
    var url = Model.trackUrl(activePlayer)
    if (url !== "" && bar) {
      bar.run("xdg-open " + bar.shellQuote(url))
      root.close()
    }
  }

  function moveSourceCursor(delta) {
    if (sourcePlayers.length === 0) return
    var next = selectedSource + delta
    if (next < 0) next = 0
    if (next > sourcePlayers.length - 1) next = sourcePlayers.length - 1
    selectedSource = next
  }

  function activateSelectedSource() {
    if (!mediaService) return
    if (selectedSource < 0 || selectedSource >= sourcePlayers.length) return
    mediaService.selectPlayer(mediaService.playerKey(sourcePlayers[selectedSource]))
  }

  onOpenedChanged: {
    if (opened) {
      cursorActive = false
      selectedSource = 0
      syncPosition()
    }
  }

  onActivePlayerChanged: syncPosition()

  Timer {
    id: positionTimer
    interval: 1000
    repeat: true
    running: root.opened && root.hasMedia && root.playing && root.hasProgress
    triggeredOnStart: true
    onTriggered: root.syncPosition()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.playing ? "󰎈" : "󰏤"
    active: root.opened
    // Paused media stays visible but recedes, so a glance at the bar still
    // tells you whether anything is actually playing.
    opacity: root.playing ? 1.0 : 0.55
    tooltipText: root.artist !== "" ? root.title + " — " + root.artist : root.title

    Behavior on opacity {
      NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }

    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.runAction("playPause")
      else root.toggle()
    }
    onWheelMoved: function(delta) {
      if (delta > 0) root.runAction("previous")
      else if (delta < 0) root.runAction("next")
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened && root.hasMedia
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dx !== 0) {
          if (dx > 0) root.runAction("next")
          else root.runAction("previous")
          return
        }
        if (dy === 0) return
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveSourceCursor(dy)
      }
      onActivateRequested: {
        if (root.cursorActive) root.activateSelectedSource()
        else root.runAction("playPause")
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // ---------- Hero: album art · title / artist / album ----------
        Row {
          width: parent.width
          spacing: Style.space(12)

          BorderSurface {
            id: artTile
            width: Style.space(root.artSize)
            height: Style.space(root.artSize)
            radius: Style.spacing.labelGap
            color: Style.normalFillFor(root.bar.foreground, root.accentColor)
            borderSpec: Border.controlSpec("normal", root.bar.foreground, root.accentColor)

            Image {
              id: art
              anchors.fill: parent
              anchors.margins: Style.space(2)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: true
              source: root.artUrl
              visible: status === Image.Ready
              // Spotify serves 640px covers; decode at physical pixels instead
              // of holding the full-size image for a small tile.
              sourceSize.width: width * Screen.devicePixelRatio
              sourceSize.height: height * Screen.devicePixelRatio
            }

            // Keyed on the image status, not on the URL, so an offline or 404
            // fetch shows the placeholder rather than an empty tile.
            Text {
              anchors.centerIn: parent
              visible: art.status !== Image.Ready
              text: art.status === Image.Loading ? "󰧑" : "󰝚"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.displayLarge
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: root.activePlayer && (root.activePlayer.canRaise || Model.trackUrl(root.activePlayer) !== "")
                ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: root.focusPlayer()
            }
          }

          Column {
            width: parent.width - artTile.width - Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(3)

            Text {
              text: root.title
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
              elide: Text.ElideRight
              maximumLineCount: 2
              wrapMode: Text.WordWrap
              width: parent.width
            }

            Text {
              text: root.artist
              color: Qt.darker(root.bar.foreground, 1.3)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              width: parent.width
              visible: text !== ""
            }

            Text {
              text: root.album
              color: Qt.darker(root.bar.foreground, 1.6)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
              visible: text !== ""
            }

            Text {
              text: root.secondary
              color: Qt.darker(root.bar.foreground, 1.8)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
              visible: text !== ""
            }
          }
        }

        // ---------- Progress ----------
        Column {
          width: parent.width
          spacing: Style.space(2)
          visible: root.hasProgress

          PanelSlider {
            id: seekBar
            width: parent.width
            bar: root.bar
            minimum: 0
            maximum: Math.max(1, root.trackLength)
            step: Math.max(1, root.trackLength / 200)
            value: root.livePosition
            fillColor: root.accentColor
            enabled: root.canSeek

            onDraggingChanged: root.seeking = dragging
            onMoved: function(v) { root.livePosition = v }
            onReleased: function(v) { root.seekTo(v) }
          }

          Item {
            width: parent.width
            implicitHeight: elapsedLabel.implicitHeight

            Text {
              id: elapsedLabel
              anchors.left: parent.left
              text: Model.formatTime(root.livePosition)
              color: Qt.darker(root.bar.foreground, 1.5)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              anchors.right: parent.right
              text: Model.formatTime(root.trackLength)
              color: Qt.darker(root.bar.foreground, 1.5)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        // ---------- Transport ----------
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(4)

          Button {
            iconText: "󰒝"
            tooltipText: root.activePlayer && root.activePlayer.shuffle ? "Shuffle on" : "Shuffle off"
            foreground: root.bar.foreground
            accent: root.accentColor
            selected: !!(root.activePlayer && root.activePlayer.shuffle)
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            visible: !!(root.activePlayer && root.activePlayer.shuffleSupported)
            onClicked: root.toggleShuffle()
          }

          Button {
            iconText: "󰒮"
            tooltipText: "Previous"
            foreground: root.bar.foreground
            accent: root.accentColor
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            enabled: !!(root.activePlayer && root.activePlayer.canGoPrevious)
            opacity: enabled ? 1.0 : 0.4
            onClicked: root.runAction("previous")
          }

          Button {
            iconText: root.playing ? "󰏤" : "󰐊"
            tooltipText: root.playing ? "Pause" : "Play"
            foreground: root.bar.foreground
            accent: root.accentColor
            iconSize: Style.font.iconLarge
            horizontalPadding: Style.spacing.panelGap
            verticalPadding: Style.spacing.controlPaddingY
            enabled: !!(root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause))
            opacity: enabled ? 1.0 : 0.4
            onClicked: root.runAction("playPause")
          }

          Button {
            iconText: "󰒭"
            tooltipText: "Next"
            foreground: root.bar.foreground
            accent: root.accentColor
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            enabled: !!(root.activePlayer && root.activePlayer.canGoNext)
            opacity: enabled ? 1.0 : 0.4
            onClicked: root.runAction("next")
          }

          Button {
            iconText: Model.loopGlyph(root.activePlayer ? root.activePlayer.loopState : 0)
            tooltipText: Model.loopLabel(root.activePlayer ? root.activePlayer.loopState : 0)
            foreground: root.bar.foreground
            accent: root.accentColor
            selected: !!(root.activePlayer && root.activePlayer.loopState !== 0)
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            visible: !!(root.activePlayer && root.activePlayer.loopSupported)
            onClicked: root.cycleLoop()
          }
        }

        // ---------- Sources ----------
        PanelSeparator {
          width: parent.width
          foreground: root.bar.foreground
          visible: sourceList.visible
        }

        PanelSectionHeader {
          text: "SOURCES"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          visible: sourceList.visible
        }

        Column {
          id: sourceList
          width: parent.width
          spacing: Style.space(2)
          visible: root.showSourcePicker && root.sourcePlayers.length > 1

          Repeater {
            model: root.sourcePlayers

            CursorSurface {
              id: sourceRow
              required property var modelData
              required property int index

              readonly property var player: modelData
              readonly property bool isActive: !!(root.activePlayer && player && root.mediaService
                && root.mediaService.playerKey(root.activePlayer) === root.mediaService.playerKey(player))

              width: sourceList.width
              implicitHeight: sourceInner.implicitHeight + Style.space(10)
              hasCursor: root.cursorActive && root.selectedSource === index
              current: isActive
              foreground: root.bar.foreground
              accent: root.accentColor

              Row {
                id: sourceInner
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(18)
                  horizontalAlignment: Text.AlignHCenter
                  text: sourceRow.player && sourceRow.player.isPlaying ? "󰏤" : "󰐊"
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.body
                }

                Column {
                  width: parent.width - Style.space(26)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(1)

                  Text {
                    text: Model.displayTitle(sourceRow.player)
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: sourceRow.isActive
                    elide: Text.ElideRight
                    width: parent.width
                  }

                  Text {
                    text: Model.playerLabel(sourceRow.player)
                    color: Qt.darker(root.bar.foreground, 1.5)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    width: parent.width
                    visible: text !== ""
                  }
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                  root.cursorActive = true
                  root.selectedSource = sourceRow.index
                }
                onClicked: if (root.mediaService) root.mediaService.selectPlayer(root.mediaService.playerKey(sourceRow.player))
              }
            }
          }
        }
      }
    }
  }
}
