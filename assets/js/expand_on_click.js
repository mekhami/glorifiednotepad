const ExpandOnClick = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      // Only expand if currently collapsed
      if (this.el.classList.contains("collapsed")) {
        const btnId = this.el.dataset.btnId;
        this.el.classList.remove("collapsed");
        if (btnId) {
          const btn = document.getElementById(btnId);
          if (btn) btn.classList.add("expanded");
        }
      }
    });
  }
};

export default ExpandOnClick;
