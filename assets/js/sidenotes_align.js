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

    // Watch for collapsed/expanded class changes on .post-content so we
    // re-align after JS.toggle_class (which never triggers updated()).
    const postCol = this.el.previousElementSibling
    const postContent = postCol?.querySelector(".post-content")
    if (postContent) {
      this._observer = new MutationObserver(() => {
        requestAnimationFrame(() => this.align())
      })
      this._observer.observe(postContent, { attributes: true, attributeFilter: ["class"] })
    }

    // Wait one frame for layout to settle before first alignment
    requestAnimationFrame(() => requestAnimationFrame(() => this.align()))
  },

  updated() {
    requestAnimationFrame(() => this.align())
  },

  destroyed() {
    window.removeEventListener("resize", this._align)
    if (this._observer) this._observer.disconnect()
  },

  align() {
    const postCol = this.el.previousElementSibling
    if (!postCol) return

    const wrapper = this.el.parentElement
    const panelBody = this.el.querySelector(".sidenotes-body")
    if (!panelBody) return

    // Reset any previously forced min-height so we measure natural post height
    if (wrapper) wrapper.style.minHeight = ""

    // When collapsed, anchors below the fold still report their true DOM
    // positions via getBoundingClientRect, which would produce bogus large
    // offsets and force the wrapper to expand. Skip minHeight expansion when
    // the post is collapsed; the wrapper stays at its natural height.
    const postContent = postCol.querySelector(".post-content")
    const isCollapsed = postContent ? postContent.classList.contains("collapsed") : false

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

    // Expand wrapper if sidenotes are taller than the post column — but only
    // when expanded. When collapsed the wrapper must stay short.
    if (!isCollapsed && wrapper && prevBottom > 0) {
      const wrapperTop = wrapper.getBoundingClientRect().top
      const neededWrapperHeight = (panelBodyTop - wrapperTop) + prevBottom + GAP
      const currentWrapperHeight = wrapper.getBoundingClientRect().height
      if (neededWrapperHeight > currentWrapperHeight) {
        wrapper.style.minHeight = neededWrapperHeight + "px"
      }
    }
  }
}

export default SidenotesAlign
