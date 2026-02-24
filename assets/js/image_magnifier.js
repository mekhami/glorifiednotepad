const ImageMagnifier = {
  mounted() {
    this.handleImageClick = (e) => {
      if (e.target.tagName === 'IMG') {
        const src = e.target.getAttribute('src');
        if (src) {
          this.pushEvent("open_image_modal", { src: src });
        }
      }
    };
    
    this.el.addEventListener("click", this.handleImageClick);
  },
  
  destroyed() {
    this.el.removeEventListener("click", this.handleImageClick);
  }
};

export default ImageMagnifier;
