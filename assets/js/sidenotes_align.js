// assets/js/sidenotes_align.js
//
// SidenotesAlign hook: positions each .sidenote-entry in the panel to align
// vertically with its .sn-anchor span in the post body.
//
// Expects DOM structure:
//   .post-sidenotes-wrapper
//     .post-column           ← this.el.previousElementSibling
//       .post-content
//         <span class="sn-anchor" id="sn-{post_id}-{n}">
//     .sidenotes-panel       ← this.el (has phx-hook)
//       .sidenotes-body
//         div.sidenote-entry[data-sn="{post_id}-{n}"]

const SidenotesAlign = {
  mounted() {
    this._align = () => this.align()
    window.addEventListener("resize", this._align)
    // Wait one frame for layout to settle before first alignment
    requestAnimationFrame(() => requestAnimationFrame(() => this.align()))
  },

  updated() {
    requestAnimationFrame(() => this.align())
  },

  destroyed() {
    window.removeEventListener("resize", this._align)
  },

  align() {
    const postCol = this.el.previousElementSibling
    if (!postCol) return

    const panelBody = this.el.querySelector(".sidenotes-body")
    if (!panelBody) return

    const panelBodyTop = panelBody.getBoundingClientRect().top
    const GAP = 4 // minimum px gap between stacked notes

    // Compute desired top for each entry
    const entries = Array.from(this.el.querySelectorAll(".sidenote-entry"))
    const positions = entries.map(snEl => {
      const snKey = snEl.dataset.sn
      const anchor = postCol.querySelector(`[id="sn-${snKey}"]`)
      const desired = anchor
        ? Math.max(0, anchor.getBoundingClientRect().top - panelBodyTop)
        : 0
      return { el: snEl, desired }
    })

    // Anti-overlap pass: nudge each entry down if it would overlap the previous
    let prevBottom = -Infinity
    positions.forEach(({ el, desired }) => {
      const top = Math.max(desired, prevBottom + GAP)
      el.style.top = top + "px"
      prevBottom = top + el.getBoundingClientRect().height
    })
  }
}

export default SidenotesAlign
