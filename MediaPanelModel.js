// Pure helpers for the Now Playing panel. Kept out of Panel.qml so the QML
// stays declarative, matching the Model.js / MediaModel.js split every other
// Omarchy plugin uses.

// Quickshell reports MPRIS position and length in seconds; MPRIS itself speaks
// microseconds. Everything below assumes the Quickshell units.
function formatTime(seconds) {
  var total = Math.floor(Number(seconds))
  if (!isFinite(total) || total < 0) return "0:00"

  var hours = Math.floor(total / 3600)
  var minutes = Math.floor((total % 3600) / 60)
  var secs = total % 60
  var padded = secs < 10 ? "0" + secs : String(secs)

  if (hours > 0) {
    var paddedMinutes = minutes < 10 ? "0" + minutes : String(minutes)
    return hours + ":" + paddedMinutes + ":" + padded
  }
  return minutes + ":" + padded
}

function metadataValue(player, key) {
  if (!player || !player.metadata) return undefined
  return player.metadata[key]
}

function isSpotify(player) {
  if (!player) return false
  var identity = String(player.identity || "").toLowerCase()
  var desktop = String(player.desktopEntry || "").toLowerCase()
  var dbus = String(player.dbusName || "").toLowerCase()
  return identity === "spotify"
    || desktop === "spotify"
    || dbus.indexOf("spotify") !== -1
}

// Spotify blanks or genericizes the title during an ad break. Falling back to
// the player name beats rendering an empty panel.
function displayTitle(player) {
  if (!player) return ""
  var title = String(player.trackTitle || "").trim()
  if (title !== "") return title
  return String(player.identity || player.desktopEntry || "")
}

function playerLabel(player) {
  if (!player) return ""
  return String(player.identity || player.desktopEntry || "")
}

// Only worth showing when it actually differs from the track artist —
// otherwise every single-artist album repeats itself.
function albumArtistLabel(player) {
  if (!player) return ""
  var albumArtist = String(player.trackAlbumArtist || "").trim()
  if (albumArtist === "") return ""
  if (albumArtist === String(player.trackArtist || "").trim()) return ""
  return albumArtist
}

function trackNumberLabel(player) {
  var track = metadataValue(player, "xesam:trackNumber")
  if (track === undefined || track === null) return ""

  var number = Number(track)
  if (!isFinite(number) || number <= 0) return ""

  var disc = Number(metadataValue(player, "xesam:discNumber"))
  if (isFinite(disc) && disc > 1) return "Disc " + disc + " · Track " + number
  return "Track " + number
}

// The dim third line under the metadata: album artist and track number, only
// the parts that exist.
function secondaryLine(player) {
  var parts = []
  var albumArtist = albumArtistLabel(player)
  var track = trackNumberLabel(player)
  if (albumArtist !== "") parts.push(albumArtist)
  if (track !== "") parts.push(track)
  return parts.join(" · ")
}

function trackUrl(player) {
  var url = metadataValue(player, "xesam:url")
  if (url === undefined || url === null) return ""
  var text = String(url)
  return text.indexOf("http://") === 0 || text.indexOf("https://") === 0 ? text : ""
}

function hasPosition(player) {
  return !!(player && player.positionSupported && player.lengthSupported && Number(player.length) > 0)
}

function progressFraction(position, length) {
  var total = Number(length)
  if (!isFinite(total) || total <= 0) return 0
  var elapsed = Number(position)
  if (!isFinite(elapsed) || elapsed < 0) elapsed = 0
  if (elapsed > total) return 1
  return elapsed / total
}

function loopGlyph(loopState) {
  // MprisLoopState: 0 None, 1 Track, 2 Playlist
  if (loopState === 1) return "󰑘"
  return "󰑖"
}

function loopLabel(loopState) {
  if (loopState === 1) return "Repeat track"
  if (loopState === 2) return "Repeat playlist"
  return "Repeat off"
}

// None -> Playlist -> Track -> None. Matches how Spotify's own control cycles.
function nextLoopState(loopState) {
  if (loopState === 0) return 2
  if (loopState === 2) return 1
  return 0
}

if (typeof module !== "undefined") {
  module.exports = {
    formatTime: formatTime,
    metadataValue: metadataValue,
    isSpotify: isSpotify,
    displayTitle: displayTitle,
    playerLabel: playerLabel,
    albumArtistLabel: albumArtistLabel,
    trackNumberLabel: trackNumberLabel,
    secondaryLine: secondaryLine,
    trackUrl: trackUrl,
    hasPosition: hasPosition,
    progressFraction: progressFraction,
    loopGlyph: loopGlyph,
    loopLabel: loopLabel,
    nextLoopState: nextLoopState
  }
}
