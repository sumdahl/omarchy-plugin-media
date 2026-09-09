import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Stand-in for the first-party omarchy.media service.
//
// Omarchy 4.0.3 scoped what a plugin may reach: a plugin's shell only exposes
// omarchy.media when the manifest declares kind "bar" (shell.qml,
// pluginHasBarCapabilities), and this is a bar-widget. So the host service can
// simply be absent, and when it is, the widget has to get its players
// somewhere else or it renders nothing at all.
//
// This talks to Quickshell's MPRIS binding directly, which is a Quickshell API
// rather than an Omarchy one and so is not subject to the plugin sandbox. It
// implements only the surface Panel.qml actually consumes — activePlayer,
// sourcePlayers, playerKey, selectPlayer, runAction — and hands back the same
// MprisPlayer objects the host service does, so every binding on a player's
// metadata, position and capabilities keeps working unchanged.
//
// It is deliberately not a reimplementation of omarchy.media: the host also
// weighs Pipewire playback streams and drives the OSD. Whenever the host
// service IS reachable it wins, and this is never constructed.
QtObject {
  id: fallback

  // Mirrors the host's own preference: an explicit pick from the source list
  // outranks whatever is merely playing.
  property string preferredPlayerKey: ""

  readonly property var players: Mpris.players ? Mpris.players.values : []

  // Same formula as the host's MediaModel.playerKey, so keys minted here mean
  // the same thing as keys minted there.
  function playerKey(player) {
    if (!player) return ""
    return String(player.dbusName || player.desktopEntry || player.identity || "")
  }

  function hasTrackMetadata(player) {
    return !!(player && (player.trackTitle || player.trackArtist))
  }

  // A player only counts as a source once it reports something nameable,
  // matching the host so the picker does not list empty rows.
  readonly property var sourcePlayers: {
    var out = []
    for (var i = 0; i < players.length; i++)
      if (hasTrackMetadata(players[i])) out.push(players[i])
    return out
  }

  readonly property var activePlayer: {
    var list = sourcePlayers
    if (list.length === 0) return null
    if (preferredPlayerKey) {
      for (var i = 0; i < list.length; i++)
        if (playerKey(list[i]) === preferredPlayerKey) return list[i]
    }
    for (var j = 0; j < list.length; j++)
      if (list[j].isPlaying) return list[j]
    return list[0]
  }

  function playerForKey(key) {
    var wanted = String(key || "")
    if (!wanted) return null
    var list = sourcePlayers
    for (var i = 0; i < list.length; i++)
      if (playerKey(list[i]) === wanted) return list[i]
    return null
  }

  function selectPlayer(key) {
    var player = playerForKey(key)
    if (!player) return false
    preferredPlayerKey = playerKey(player)
    return true
  }

  // Signature mirrors the host's runAction(action, showFeedback, targetKey).
  // showFeedback is accepted and ignored: the OSD belongs to the host, and a
  // plugin drawing its own would double up wherever the host service is back.
  function runAction(action, showFeedback, targetKey) {
    var player = playerForKey(targetKey) || activePlayer
    if (!player) return false

    switch (String(action || "")) {
    case "next":
      if (!player.canGoNext) return false
      player.next()
      return true
    case "previous":
      if (!player.canGoPrevious) return false
      player.previous()
      return true
    case "play":
      if (!player.canPlay) return false
      player.play()
      return true
    case "pause":
      if (player.canPause) {
        player.pause()
        return true
      }
      if (player.canTogglePlaying && player.isPlaying) {
        player.togglePlaying()
        return true
      }
      return false
    default:
      // "playPause" and anything else the widget sends.
      if (!player.canTogglePlaying) return false
      player.togglePlaying()
      return true
    }
  }
}
