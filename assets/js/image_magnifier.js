function closeImageModal() {
  const modal = document.getElementById('image-modal');
  const modalImg = document.getElementById('image-modal-img');
  if (modal) modal.style.display = 'none';
  if (modalImg) modalImg.setAttribute('src', '');
}

// Global Escape key handler
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') closeImageModal();
});

// Global click delegation for modal overlay and close button
document.addEventListener('click', (e) => {
  const modal = document.getElementById('image-modal');
  if (!modal) return;
  // Click directly on overlay (not on children)
  if (e.target === modal) closeImageModal();
  // Click on close button
  if (e.target.id === 'image-modal-close') closeImageModal();
});

const ImageMagnifier = {
  mounted() {
    this.handleImageClick = (e) => {
      if (e.target.tagName === 'IMG') {
        const src = e.target.getAttribute('src');
        if (src) {
          const modal = document.getElementById('image-modal');
          const modalImg = document.getElementById('image-modal-img');
          if (modal && modalImg) {
            modalImg.setAttribute('src', src);
            modal.style.display = 'flex';
          }
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
