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

    this.el.querySelectorAll(".sidenote-entry").forEach(snEl => {
      const snKey = snEl.dataset.sn  // e.g. "my-post-1"
      const anchor = postCol.querySelector(`[id="sn-${snKey}"]`)
      if (!anchor) return

      const anchorTop = anchor.getBoundingClientRect().top
      const offset = anchorTop - panelBodyTop
      snEl.style.top = Math.max(0, offset) + "px"
    })
  }
}

export default SidenotesAlign
