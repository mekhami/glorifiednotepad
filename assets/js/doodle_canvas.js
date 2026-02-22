import 'vanilla-colorful/hex-color-picker.js';
import 'vanilla-colorful/hex-input.js';

const DoodleCanvas = {
  mounted() {
    console.log('DoodleCanvas hook mounted');
    const canvas = this.el;
    const ctx = canvas.getContext('2d');
    
    // Canvas configuration
    const PIXEL_SIZE = 2;
    const CANVAS_WIDTH = 1920;
    const CANVAS_HEIGHT = 1080;
    const BACKGROUND_COLOR = '#df9390';
    
    // Zoom/Pan state
    let scale = 2.0;
    let offsetX = 0;
    let offsetY = 0;
    const MIN_SCALE = 0.1;
    const MAX_SCALE = 10.0;
    
    // Drawing state
    let currentColor = '#000000';
    let isDrawing = false;
    let isPanning = false;
    let lastPanX = 0;
    let lastPanY = 0;
    let lastDrawX = null;
    let lastDrawY = null;
    
    // Color picker state
    let isPickerOpen = false;
    let isPipetteMode = false;
    let customColor = null;
    
    // Server sync state
    let pendingPixels = [];  // Batch of pixels to send to server
    let allPixels = new Map(); // Cache of all pixels (key: "x,y", value: color)
    
    // Store interval ID on the hook instance so destroyed() can access it
    this.syncInterval = null;

    console.log('Canvas element:', canvas);
    console.log('Canvas context:', ctx);

    // Draw a line between two grid points using Bresenham's algorithm
    const drawLine = (x0, y0, x1, y1, color) => {
      const dx = Math.abs(x1 - x0);
      const dy = Math.abs(y1 - y0);
      const sx = x0 < x1 ? 1 : -1;
      const sy = y0 < y1 ? 1 : -1;
      let err = dx - dy;

      while (true) {
        drawPixel(x0, y0, color);
        
        if (x0 === x1 && y0 === y1) break;
        
        const e2 = 2 * err;
        if (e2 > -dy) {
          err -= dy;
          x0 += sx;
        }
        if (e2 < dx) {
          err += dx;
          y0 += sy;
        }
      }
    };

    // Draw a pixel at grid coordinates
    const drawPixel = (gridX, gridY, color) => {
      if (gridX < 0 || gridX >= CANVAS_WIDTH || gridY < 0 || gridY >= CANVAS_HEIGHT) {
        return; // Out of bounds
      }
      ctx.fillStyle = color;
      ctx.fillRect(gridX * PIXEL_SIZE, gridY * PIXEL_SIZE, PIXEL_SIZE, PIXEL_SIZE);
      
      // Update our pixel cache
      const key = `${gridX},${gridY}`;
      allPixels.set(key, color);
    };

    // Convert mouse coordinates to grid coordinates (accounting for zoom/pan)
    const getGridCoords = (clientX, clientY) => {
      const rect = canvas.getBoundingClientRect();
      const x = clientX - rect.left;
      const y = clientY - rect.top;
      
      // Transform screen coordinates to canvas coordinates
      const canvasX = (x - offsetX) / scale;
      const canvasY = (y - offsetY) / scale;
      
      const coords = {
        gridX: Math.floor(canvasX / PIXEL_SIZE),
        gridY: Math.floor(canvasY / PIXEL_SIZE)
      };
      return coords;
    };

    // Load pixels from server (initial load)
    const loadPixelsFromServer = (pixels) => {
      console.log('Loading pixels from server:', pixels.length);
      pixels.forEach(pixel => {
        // Add to cache without drawing (redraw will handle rendering)
        const key = `${pixel.x},${pixel.y}`;
        allPixels.set(key, pixel.color);
      });
      // Redraw the canvas after loading all pixels
      redraw();
    };

    // Paint pixels received from other users
    const paintPixelsFromServer = (pixels) => {
      console.log('Received pixels from other users:', pixels.length);
      pixels.forEach(pixel => {
        // Add to cache without drawing (redraw will handle rendering)
        const key = `${pixel.x},${pixel.y}`;
        allPixels.set(key, pixel.color);
      });
      // Redraw to show the new pixels
      redraw();
    };

    // Sync pending pixels with server
    const syncPixels = () => {
      if (pendingPixels.length === 0) return;
      
      console.log('Syncing pixels to server:', pendingPixels.length);
      this.pushEventTo(this.el, "save_pixels", { pixels: pendingPixels });
      
      // Clear the batch
      pendingPixels = [];
    };

    // Add pixel to pending batch
    const batchPixel = (x, y, color) => {
      if (color === BACKGROUND_COLOR) {
        return; // Don't save background color pixels
      }
      pendingPixels.push({ x, y, color });
    };

    // Draw the canvas boundary box
    const drawBoundary = () => {
      if (scale < 1.0) {
        ctx.strokeStyle = '#000000';
        ctx.lineWidth = 2 / scale;
        ctx.strokeRect(0, 0, CANVAS_WIDTH * PIXEL_SIZE, CANVAS_HEIGHT * PIXEL_SIZE);
      }
    };

    // Redraw entire canvas
    const redraw = () => {
      // Clear the physical canvas
      const displayWidth = canvas.width;
      const displayHeight = canvas.height;
      ctx.clearRect(0, 0, displayWidth, displayHeight);
      
      // Save context state
      ctx.save();
      
      // Apply zoom and pan transformations
      ctx.translate(offsetX, offsetY);
      ctx.scale(scale, scale);
      
      // Draw background
      ctx.fillStyle = BACKGROUND_COLOR;
      ctx.fillRect(0, 0, CANVAS_WIDTH * PIXEL_SIZE, CANVAS_HEIGHT * PIXEL_SIZE);
      
      // Draw all cached pixels
      console.log('Redrawing canvas with', allPixels.size, 'pixels');
      allPixels.forEach((color, key) => {
        const [x, y] = key.split(',').map(Number);
        ctx.fillStyle = color;
        ctx.fillRect(x * PIXEL_SIZE, y * PIXEL_SIZE, PIXEL_SIZE, PIXEL_SIZE);
      });
      
      // Draw boundary if zoomed out
      drawBoundary();
      
      // Restore context state
      ctx.restore();
    };

    // Set canvas size to fill window
    const resizeCanvas = () => {
      const displayWidth = window.innerWidth;
      const displayHeight = window.innerHeight;
      canvas.width = displayWidth;
      canvas.height = displayHeight;
      console.log('Canvas resized to:', canvas.width, 'x', canvas.height);
      
      // Center the canvas view
      offsetX = displayWidth / 2 - (CANVAS_WIDTH * PIXEL_SIZE * scale) / 2;
      offsetY = displayHeight / 2 - (CANVAS_HEIGHT * PIXEL_SIZE * scale) / 2;
      
      redraw();
    };

    // Handle zoom
    const handleZoom = (e) => {
      e.preventDefault();
      
      const rect = canvas.getBoundingClientRect();
      const mouseX = e.clientX - rect.left;
      const mouseY = e.clientY - rect.top;
      
      // Calculate zoom direction (2% change per scroll for ultra-smooth control)
      const delta = e.deltaY > 0 ? 0.98 : 1.02;
      const newScale = Math.max(MIN_SCALE, Math.min(MAX_SCALE, scale * delta));
      
      // Zoom towards mouse cursor
      const scaleDiff = newScale - scale;
      offsetX -= (mouseX - offsetX) * (scaleDiff / scale);
      offsetY -= (mouseY - offsetY) * (scaleDiff / scale);
      
      scale = newScale;
      console.log('Zoom:', { scale, offsetX, offsetY });
      
      redraw();
    };

    // Handle drawing
    const draw = (e) => {
      const { gridX, gridY } = getGridCoords(e.clientX, e.clientY);
      
      ctx.save();
      ctx.translate(offsetX, offsetY);
      ctx.scale(scale, scale);
      
      // If we have a previous position, draw a line to connect
      if (lastDrawX !== null && lastDrawY !== null) {
        drawLine(lastDrawX, lastDrawY, gridX, gridY, currentColor);
        // Batch all pixels in the line
        const dx = Math.abs(gridX - lastDrawX);
        const dy = Math.abs(gridY - lastDrawY);
        const sx = lastDrawX < gridX ? 1 : -1;
        const sy = lastDrawY < gridY ? 1 : -1;
        let err = dx - dy;
        let x = lastDrawX;
        let y = lastDrawY;
        
        while (true) {
          batchPixel(x, y, currentColor);
          if (x === gridX && y === gridY) break;
          const e2 = 2 * err;
          if (e2 > -dy) {
            err -= dy;
            x += sx;
          }
          if (e2 < dx) {
            err += dx;
            y += sy;
          }
        }
      } else {
        // First pixel
        drawPixel(gridX, gridY, currentColor);
        batchPixel(gridX, gridY, currentColor);
      }
      
      ctx.restore();
      
      // Store current position for next draw
      lastDrawX = gridX;
      lastDrawY = gridY;
    };

    // ===== Color Picker Functions =====
    
    // Initialize vanilla-colorful hex color picker
    const initColorPicker = () => {
      const pickerContainer = document.getElementById('color-picker-container');
      const hexPicker = document.createElement('hex-color-picker');
      hexPicker.color = currentColor;
      pickerContainer.appendChild(hexPicker);
      
      // Listen for color changes
      hexPicker.addEventListener('color-changed', (e) => {
        const newColor = e.detail.value;
        applyCustomColor(newColor);
      });
      
      return hexPicker;
    };
    
    // Initialize vanilla-colorful hex input
    const initHexInput = () => {
      const inputContainer = document.getElementById('hex-input-container');
      const hexInput = document.createElement('hex-input');
      hexInput.color = currentColor;
      hexInput.setAttribute('prefixed', '');
      inputContainer.appendChild(hexInput);
      
      // Listen for color changes
      hexInput.addEventListener('color-changed', (e) => {
        const newColor = e.detail.value;
        applyCustomColor(newColor);
      });
      
      return hexInput;
    };
    
    // Setup color picker UI interactions
    const setupColorPickerUI = (hexPicker, hexInput) => {
      const pickerTrigger = document.getElementById('color-picker-trigger');
      const pickerPopup = document.getElementById('color-picker-popup');
      const closePicker = document.querySelector('.close-picker');
      const pipetteToggle = document.getElementById('pipette-mode-toggle');
      
      // Open color picker
      pickerTrigger.addEventListener('click', () => {
        if (isPickerOpen) {
          closeColorPicker();
        } else {
          openColorPicker(hexPicker, hexInput);
        }
      });
      
      // Close picker button
      closePicker.addEventListener('click', () => {
        closeColorPicker();
      });
      
      // Pipette mode toggle
      pipetteToggle.addEventListener('click', () => {
        togglePipetteMode();
      });
      
      // Close picker on outside click
      document.addEventListener('click', (e) => {
        if (isPickerOpen && 
            !pickerPopup.contains(e.target) && 
            !pickerTrigger.contains(e.target)) {
          closeColorPicker();
        }
      });
      
      // Close picker on Escape key
      document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && isPickerOpen) {
          closeColorPicker();
        }
      });
    };
    
    // Open color picker popup
    const openColorPicker = (hexPicker, hexInput) => {
      const pickerPopup = document.getElementById('color-picker-popup');
      pickerPopup.classList.remove('hidden');
      isPickerOpen = true;
      
      // Set picker to current custom color or current color
      const colorToShow = customColor || currentColor;
      hexPicker.color = colorToShow;
      hexInput.color = colorToShow;
    };
    
    // Close color picker popup
    const closeColorPicker = () => {
      const pickerPopup = document.getElementById('color-picker-popup');
      pickerPopup.classList.add('hidden');
      isPickerOpen = false;
      
      // Exit pipette mode if active
      if (isPipetteMode) {
        togglePipetteMode();
      }
    };
    
    // Apply custom color
    const applyCustomColor = (hexColor) => {
      currentColor = hexColor;
      customColor = hexColor;
      
      // Update picker trigger to show custom color
      const pickerTrigger = document.getElementById('color-picker-trigger');
      pickerTrigger.style.backgroundColor = hexColor;
      pickerTrigger.classList.add('has-custom-color');
      
      // Deselect all palette colors
      const colorOptions = document.querySelectorAll('.color-option:not(.picker-trigger)');
      colorOptions.forEach(opt => opt.classList.remove('selected'));
    };
    
    // Toggle pipette mode
    const togglePipetteMode = () => {
      isPipetteMode = !isPipetteMode;
      const pipetteToggle = document.getElementById('pipette-mode-toggle');
      
      if (isPipetteMode) {
        canvas.classList.add('pipette-mode');
        pipetteToggle.classList.add('active');
      } else {
        canvas.classList.remove('pipette-mode');
        pipetteToggle.classList.remove('active');
      }
    };
    
    // Handle canvas click in pipette mode
    const handleCanvasClickInPipetteMode = (gridX, gridY) => {
      const key = `${gridX},${gridY}`;
      const pixelColor = allPixels.get(key) || BACKGROUND_COLOR;
      
      applyCustomColor(pixelColor);
      closeColorPicker();
    };

    // Initialize canvas
    resizeCanvas();
    
    // Store resize handler so we can clean it up
    this.resizeHandler = () => resizeCanvas();
    window.addEventListener('resize', this.resizeHandler);
    
    // Start periodic sync every 2 seconds
    this.syncInterval = setInterval(() => {
      syncPixels();
    }, 2000);
    
    // Listen for pixel broadcasts from server
    this.handleEvent("load-pixels", ({ pixels }) => {
      loadPixelsFromServer(pixels);
    });
    
    this.handleEvent("receive-pixels", ({ pixels }) => {
      paintPixelsFromServer(pixels);
    });
    
    // Clear old localStorage data (cleanup)
    localStorage.removeItem('doodles');

    // Mouse event listeners
    const controls = document.getElementById('doodle-controls');
    
    canvas.addEventListener('mousedown', (e) => {
      if (e.button === 1 || e.button === 2) {
        // Middle or right click - start panning
        e.preventDefault();
        isPanning = true;
        lastPanX = e.clientX;
        lastPanY = e.clientY;
        canvas.style.cursor = 'grabbing';
      } else if (e.button === 0) {
        // Left click
        if (isPipetteMode) {
          // Pipette mode - pick color from canvas
          const { gridX, gridY } = getGridCoords(e.clientX, e.clientY);
          handleCanvasClickInPipetteMode(gridX, gridY);
        } else {
          // Normal drawing mode
          isDrawing = true;
          lastDrawX = null;
          lastDrawY = null;
          // Disable pointer events on content so dragging works through it
          document.body.style.pointerEvents = 'none';
          canvas.style.pointerEvents = 'auto';
          controls.style.pointerEvents = 'auto';
          draw(e);
        }
      }
    });

    // Listen on document for mousemove so it works even over content
    document.addEventListener('mousemove', (e) => {
      if (isPanning) {
        const dx = e.clientX - lastPanX;
        const dy = e.clientY - lastPanY;
        offsetX += dx;
        offsetY += dy;
        lastPanX = e.clientX;
        lastPanY = e.clientY;
        redraw();
      } else if (isDrawing) {
        draw(e);
      }
    });

    // Listen on document for mouseup so it works anywhere
    document.addEventListener('mouseup', (e) => {
      if (isPanning) {
        isPanning = false;
        canvas.style.cursor = 'crosshair';
      }
      if (isDrawing) {
        isDrawing = false;
        lastDrawX = null;
        lastDrawY = null;
        // Re-enable pointer events on content
        document.body.style.pointerEvents = '';
      }
    });

    // Zoom with mousewheel
    canvas.addEventListener('wheel', handleZoom, { passive: false });

    // Prevent context menu on right-click
    canvas.addEventListener('contextmenu', (e) => {
      e.preventDefault();
    });

    // Color palette handling
    const palette = document.getElementById('color-palette');
    const colorOptions = palette.querySelectorAll('.color-option:not(.picker-trigger)');
    
    colorOptions.forEach(option => {
      option.addEventListener('click', () => {
        currentColor = option.dataset.color;
        customColor = null;
        
        // Remove selected class from all
        colorOptions.forEach(opt => opt.classList.remove('selected'));
        option.classList.add('selected');
        
        // Reset picker trigger appearance
        const pickerTrigger = document.getElementById('color-picker-trigger');
        pickerTrigger.style.backgroundColor = '';
        pickerTrigger.classList.remove('has-custom-color');
      });
    });

    // Set initial color
    colorOptions[0].classList.add('selected');
    
    // Initialize color picker
    const hexPicker = initColorPicker();
    const hexInput = initHexInput();
    setupColorPickerUI(hexPicker, hexInput);
  },
  
  destroyed() {
    // Clean up interval when hook is destroyed
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
    }
    
    // Clean up resize listener
    if (this.resizeHandler) {
      window.removeEventListener('resize', this.resizeHandler);
    }
  }
};

export default DoodleCanvas;
