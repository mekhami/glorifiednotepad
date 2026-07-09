// Progressive enhancement for server-rendered <audio class="indie-audio">.
// On failure, native <audio controls> fallback remains functional.

const CLS = "iap"

function fmt(s) {
  if (isNaN(s) || !isFinite(s)) return "0:00"
  const m = Math.floor(s / 60)
  const sec = Math.floor(s % 60)
  return m + ":" + sec.toString().padStart(2, "0")
}

function enhance(audio) {
  if (audio.nextElementSibling && audio.nextElementSibling.classList.contains(CLS)) return

  var c = document.createElement("div")
  c.className = CLS
  c.innerHTML =
    '<button class="iap-play">\u25b6</button>' +
    '<div class="iap-track"><div class="iap-fill"></div></div>' +
    '<span class="iap-time">0:00 / 0:00</span>' +
    '<button class="iap-vol">\uD83D\uDD0A</button>' +
    '<input type="range" class="iap-slider" min="0" max="1" step="0.01" value="' + audio.volume + '">'

  audio.parentNode.insertBefore(c, audio.nextSibling)
  audio.removeAttribute("controls")

  var play = c.querySelector(".iap-play")
  var fill = c.querySelector(".iap-fill")
  var timeEl = c.querySelector(".iap-time")
  var volBtn = c.querySelector(".iap-vol")
  var slider = c.querySelector(".iap-slider")

  play.onclick = function () {
    if (audio.paused) audio.play()
    else audio.pause()
  }

  audio.onplay = function () { play.textContent = "\u23f8" }
  audio.onpause = function () { play.textContent = "\u25b6" }

  audio.ontimeupdate = function () {
    fill.style.width = (audio.currentTime / audio.duration) * 100 + "%"
    timeEl.textContent = fmt(audio.currentTime) + " / " + fmt(audio.duration)
  }

  audio.onloadedmetadata = function () {
    timeEl.textContent = "0:00 / " + fmt(audio.duration)
  }

  audio.onended = function () {
    fill.style.width = "0%"
    timeEl.textContent = "0:00 / " + fmt(audio.duration)
  }

  c.querySelector(".iap-track").onclick = function (e) {
    var r = this.getBoundingClientRect()
    audio.currentTime = ((e.clientX - r.left) / r.width) * audio.duration
  }

  function setVolIcon() {
    if (audio.muted || +slider.value === 0) volBtn.innerHTML = "\uD83D\uDD07"
    else if (+slider.value < 0.5) volBtn.innerHTML = "\uD83D\uDD09"
    else volBtn.innerHTML = "\uD83D\uDD0A"
  }

  slider.oninput = function () {
    audio.volume = +slider.value
    setVolIcon()
  }

  volBtn.onclick = function () {
    audio.muted = !audio.muted
    setVolIcon()
  }

  audio.onvolumechange = setVolIcon
}

function scan() {
  var els = document.querySelectorAll(".indie-audio")
  for (var i = 0; i < els.length; i++) enhance(els[i])
}

if (document.readyState !== "loading") scan()
else document.addEventListener("DOMContentLoaded", scan)

window.addEventListener("phx:page-loading-stop", scan)
