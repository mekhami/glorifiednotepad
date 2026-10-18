// Shows a small card with a character's description when hovering (or
// focusing) a `.character-mention` inside the hooked element.
const OFFSET = 14

const CharacterTooltip = {
  mounted() {
    this.tip = document.createElement("div")
    this.tip.className = "character-tooltip"
    this.tip.setAttribute("role", "tooltip")
    document.body.appendChild(this.tip)

    this.onOver = e => {
      const mention = e.target.closest(".character-mention")
      if (mention && this.el.contains(mention)) this.show(mention, e.clientX, e.clientY)
    }
    this.onMove = e => {
      if (this.current) this.place(e.clientX, e.clientY)
    }
    this.onOut = e => {
      const mention = e.target.closest(".character-mention")
      if (mention && !mention.contains(e.relatedTarget)) this.hide()
    }
    this.onFocus = e => {
      const mention = e.target.closest(".character-mention")
      if (!mention) return
      const rect = mention.getBoundingClientRect()
      this.show(mention, rect.left, rect.bottom)
    }
    this.onBlur = () => this.hide()

    this.el.addEventListener("mouseover", this.onOver)
    this.el.addEventListener("mousemove", this.onMove)
    this.el.addEventListener("mouseout", this.onOut)
    this.el.addEventListener("focusin", this.onFocus)
    this.el.addEventListener("focusout", this.onBlur)
  },

  updated() {
    this.hide()
  },

  destroyed() {
    this.tip.remove()
  },

  show(mention, x, y) {
    this.current = mention
    this.tip.replaceChildren()

    const name = document.createElement("strong")
    name.className = "character-tooltip-name"
    name.textContent = mention.dataset.name
    this.tip.appendChild(name)

    const kind = mention.dataset.kind
    if (kind) {
      const tag = document.createElement("span")
      tag.className = `character-tooltip-kind is-${kind}`
      tag.textContent = kind.toUpperCase()
      name.appendChild(tag)
    }

    const description = document.createElement("p")
    description.className = "character-tooltip-description"
    description.textContent = mention.dataset.description || "A soul of Stonetop, as yet undescribed."
    this.tip.appendChild(description)

    this.tip.classList.add("is-visible")
    this.place(x, y)
  },

  place(x, y) {
    const {offsetWidth: w, offsetHeight: h} = this.tip
    let left = x + OFFSET
    let top = y + OFFSET
    if (left + w > window.innerWidth - 8) left = x - w - OFFSET
    if (top + h > window.innerHeight - 8) top = y - h - OFFSET
    this.tip.style.left = `${Math.max(8, left)}px`
    this.tip.style.top = `${Math.max(8, top)}px`
  },

  hide() {
    this.current = null
    this.tip.classList.remove("is-visible")
  },
}

export default CharacterTooltip
