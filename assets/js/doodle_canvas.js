import 'vanilla-colorful/hex-color-picker.js';
import 'vanilla-colorful/hex-input.js';

const DoodleCanvas = {
  mounted() {
    const hookThis = this;
    console.log('DoodleCanvas hook mounted');
    const canvas = this.el;
    const ctx = canvas.getContext('2d');
    
    // Canvas configuration
    const PIXEL_SIZE = 2;
    const CANVAS_WIDTH = 1920;
    const CANVAS_HEIGHT = 1080;
    const BACKGROUND_COLOR = '#df9390';
    
    // Canvas visibility state
    const CANVAS_VISIBLE_KEY = 'canvas_visible';
    let isCanvasVisible = localStorage.getItem(CANVAS_VISIBLE_KEY) !== 'false'; // default to true
    
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
    
    // Animation state
    let animationRegions = []; // [{id, x1, y1, x2, y2, frame_count}]
    let activeEditor = null;   // null | {animation_id, x1, y1, x2, y2, current_frame, total_frames, frameBuffers, el}
    let isDragMode = false;
    let dragStart = null;      // {gridX, gridY}
    
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
      // Redraw the canvas
      redraw();
    };

    // Delete pixels received from other users (eraser sync)
    const deletePixelsFromServer = (coords) => {
      console.log('Received deleted pixels from other users:', coords.length);
      coords.forEach(coord => {
        // Remove from cache
        const key = `${coord.x},${coord.y}`;
        allPixels.delete(key);
      });
      // Redraw the canvas
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

    // Add pixel to pending batch (skips pixels inside active animation editor)
    const batchPixel = (x, y, color) => {
      if (activeEditor) {
        const minX = Math.min(activeEditor.x1, activeEditor.x2);
        const maxX = Math.max(activeEditor.x1, activeEditor.x2);
        const minY = Math.min(activeEditor.y1, activeEditor.y2);
        const maxY = Math.max(activeEditor.y1, activeEditor.y2);
        if (x >= minX && x <= maxX && y >= minY && y <= maxY) return;
      }
      pendingPixels.push({ x, y, color });
    };

    // Returns the animation region containing (gridX, gridY), or null
    const findAnimationRegion = (gridX, gridY) => {
      return animationRegions.find(a => {
        const minX = Math.min(a.x1, a.x2);
        const maxX = Math.max(a.x1, a.x2);
        const minY = Math.min(a.y1, a.y2);
        const maxY = Math.max(a.y1, a.y2);
        return gridX >= minX && gridX <= maxX && gridY >= minY && gridY <= maxY;
      }) || null;
    };

    // Draw a pixel into the current animation frame buffer (editor mode)
    const drawEditorFramePixel = (x, y, color) => {
      if (!activeEditor) return;
      const buf = activeEditor.frameBuffers.get(activeEditor.current_frame) || new Map();
      buf.set(`${x},${y}`, color);
      activeEditor.frameBuffers.set(activeEditor.current_frame, buf);
      drawPixel(x, y, color);
    };

    // Redraw canvas showing the current editor frame's pixels
    const redrawWithEditorFrame = () => {
      redraw();
      if (!activeEditor) return;
      ctx.save();
      ctx.translate(offsetX, offsetY);
      ctx.scale(scale, scale);
      const buf = activeEditor.frameBuffers.get(activeEditor.current_frame) || new Map();
      buf.forEach((color, key) => {
        const [x, y] = key.split(',').map(Number);
        ctx.fillStyle = color;
        ctx.fillRect(x * PIXEL_SIZE, y * PIXEL_SIZE, PIXEL_SIZE, PIXEL_SIZE);
      });
      ctx.restore();
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
        if (x < 0 || x >= CANVAS_WIDTH || y < 0 || y >= CANVAS_HEIGHT) return;
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
      // Check if mouse is over a canvas margin zone (left or right)
      const leftZone = document.getElementById('canvas-zone-left');
      const rightZone = document.getElementById('canvas-zone-right');
      
      let isOverCanvasZone = false;
      if (leftZone || rightZone) {
        const leftRect = leftZone?.getBoundingClientRect();
        const rightRect = rightZone?.getBoundingClientRect();
        
        if (leftRect && e.clientX >= leftRect.left && e.clientX <= leftRect.right &&
            e.clientY >= leftRect.top && e.clientY <= leftRect.bottom) {
          isOverCanvasZone = true;
        } else if (rightRect && e.clientX >= rightRect.left && e.clientX <= rightRect.right &&
                   e.clientY >= rightRect.top && e.clientY <= rightRect.bottom) {
          isOverCanvasZone = true;
        }
      }
      
      // Only handle canvas pan/zoom if mouse is over canvas zones
      // Otherwise, allow default page scrolling
      if (!isOverCanvasZone) {
        return; // Let the page scroll naturally
      }
      
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
          if (x >= 0 && x < CANVAS_WIDTH && y >= 0 && y < CANVAS_HEIGHT) {
            if (activeEditor) {
              drawEditorFramePixel(x, y, currentColor);
            } else {
              batchPixel(x, y, currentColor);
            }
          }
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
        if (activeEditor) {
          drawEditorFramePixel(gridX, gridY, currentColor);
        } else {
          drawPixel(gridX, gridY, currentColor);
          batchPixel(gridX, gridY, currentColor);
        }
      }
      
      ctx.restore();
      
      // Store current position for next draw
      lastDrawX = gridX;
      lastDrawY = gridY;
    };

    // ===== Color Picker Functions =====
    
    // ===== Canvas Visibility Toggle =====
    
    // Toggle canvas visibility
    const toggleCanvasVisibility = () => {
      isCanvasVisible = !isCanvasVisible;
      localStorage.setItem(CANVAS_VISIBLE_KEY, isCanvasVisible.toString());
      updateCanvasVisibility();
    };
    
    // Update canvas visibility based on state
    const updateCanvasVisibility = () => {
      const toggleBtn = document.getElementById('canvas-toggle-btn');
      const eyeOpen = toggleBtn?.querySelector('.eye-open');
      const eyeClosed = toggleBtn?.querySelector('.eye-closed');
      
      if (isCanvasVisible) {
        canvas.style.display = '';
        eyeOpen?.classList.remove('hidden');
        eyeClosed?.classList.add('hidden');
      } else {
        canvas.style.display = 'none';
        eyeOpen?.classList.add('hidden');
        eyeClosed?.classList.remove('hidden');
      }
    };
    
    // Setup canvas toggle button
    const setupCanvasToggle = () => {
      const toggleBtn = document.getElementById('canvas-toggle-btn');
      if (toggleBtn) {
        toggleBtn.addEventListener('click', toggleCanvasVisibility);
        // Set initial state
        updateCanvasVisibility();
      }
    };
    
    // Create the animation editor DOM overlay
    const createEditorBox = (animation_id, x1, y1, x2, y2) => {
      const minX = Math.min(x1, x2);
      const minY = Math.min(y1, y2);
      const maxX = Math.max(x1, x2);
      const maxY = Math.max(y1, y2);
      const totalFrames = 1;

      const frameBuffers = new Map();
      frameBuffers.set(0, new Map());

      const editorState = {
        animation_id,
        x1: minX, y1: minY, x2: maxX, y2: maxY,
        current_frame: 0,
        total_frames: totalFrames,
        frameBuffers,
        el: null
      };

      // Position editor box in screen coordinates
      const rect = canvas.getBoundingClientRect();
      const screenX1 = minX * PIXEL_SIZE * scale + offsetX + rect.left;
      const screenY1 = minY * PIXEL_SIZE * scale + offsetY + rect.top;
      const screenX2 = (maxX + 1) * PIXEL_SIZE * scale + offsetX + rect.left;
      const screenY2 = (maxY + 1) * PIXEL_SIZE * scale + offsetY + rect.top;
      const screenW = screenX2 - screenX1;
      const screenH = screenY2 - screenY1;

      const box = document.createElement('div');
      box.id = `animation-editor-${animation_id}`;
      box.style.cssText = `
        position: fixed;
        left: ${screenX1}px;
        top: ${screenY1}px;
        width: ${screenW}px;
        z-index: 100;
        font-family: monospace;
        pointer-events: none;
        overflow: visible;
      `;

      const titlebar = document.createElement('div');
      titlebar.style.cssText = `
        display: flex;
        align-items: center;
        gap: 4px;
        width: max-content;
        min-width: 100%;
        box-sizing: border-box;
        background: rgba(255,255,255,0.9);
        border: 1px solid #555;
        border-top: none;
        padding: 3px 6px;
        font-size: 11px;
        color: #222;
        user-select: none;
        pointer-events: auto;
      `;

      const btnClose = document.createElement('button');
      btnClose.textContent = '\u2715';
      btnClose.title = 'Discard';
      btnClose.style.cssText = 'background:none;border:none;cursor:pointer;font-family:monospace;font-size:11px;color:#333;padding:0 3px;';

      const btnPrev = document.createElement('button');
      btnPrev.textContent = '\u2190';
      btnPrev.style.cssText = btnClose.style.cssText;

      const frameLabel = document.createElement('span');
      frameLabel.textContent = `frame 1/${totalFrames}`;

      const btnNext = document.createElement('button');
      btnNext.textContent = '\u2192';
      btnNext.style.cssText = btnClose.style.cssText;

      const spacer = document.createElement('span');
      spacer.style.flex = '1';

      const btnSave = document.createElement('button');
      btnSave.textContent = 'save';
      btnSave.style.cssText = `
        background: #222;
        color: #fff;
        border: none;
        border-radius: 2px;
        padding: 1px 7px;
        cursor: pointer;
        font-family: monospace;
        font-size: 11px;
      `;

      titlebar.append(btnClose, btnPrev, frameLabel, btnNext, spacer, btnSave);

      const drawArea = document.createElement('div');
      drawArea.style.cssText = `
        width: 100%;
        height: ${screenH}px;
        border: 1px dashed #555;
        box-sizing: border-box;
        pointer-events: none;
      `;

      box.append(drawArea, titlebar);
      document.body.appendChild(box);
      editorState.el = box;

      // Button handlers
      btnClose.addEventListener('click', () => {
        box.remove();
        activeEditor = null;
      });

      btnPrev.addEventListener('click', () => {
        if (editorState.current_frame > 0) {
          editorState.current_frame -= 1;
          if (!editorState.frameBuffers.has(editorState.current_frame)) {
            editorState.frameBuffers.set(editorState.current_frame, new Map());
          }
          frameLabel.textContent = `frame ${editorState.current_frame + 1}/${editorState.total_frames}`;
          redrawWithEditorFrame();
        }
      });

      btnNext.addEventListener('click', () => {
        const maxFrame = 7; // 0-indexed, max 8 frames
        if (editorState.current_frame < maxFrame) {
          editorState.current_frame += 1;
          editorState.total_frames = Math.max(editorState.total_frames, editorState.current_frame + 1);
          if (!editorState.frameBuffers.has(editorState.current_frame)) {
            editorState.frameBuffers.set(editorState.current_frame, new Map());
          }
          frameLabel.textContent = `frame ${editorState.current_frame + 1}/${editorState.total_frames}`;
          redrawWithEditorFrame();
        }
      });

      btnSave.addEventListener('click', () => {
        const frames = [];
        editorState.frameBuffers.forEach((pixelMap, frameIndex) => {
          const pixels = [];
          pixelMap.forEach((color, key) => {
            const [x, y] = key.split(',').map(Number);
            pixels.push({ x, y, color });
          });
          frames.push({ frame: frameIndex, pixels });
        });

        hookThis.pushEventTo(canvas, "save_animation", {
          animation_id: editorState.animation_id,
          frames
        });

        box.remove();
        activeEditor = null;
      });

      activeEditor = editorState;
      return editorState;
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
      
      // Automatically enable pipette mode when opening color picker
      if (!isPipetteMode) {
        togglePipetteMode();
      }
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
      
      // Update the color indicator
      const colorIndicator = document.getElementById('current-color-indicator');
      if (colorIndicator) {
        colorIndicator.style.backgroundColor = hexColor;
      }
      
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

    this.handleEvent("delete-pixels", ({ coords }) => {
      deletePixelsFromServer(coords);
    });
    
    hookThis.handleEvent("load-animations", ({ animations }) => {
      animationRegions = animations.map(a => ({
        id: a.id, x1: a.x1, y1: a.y1, x2: a.x2, y2: a.y2, frame_count: a.frame_count
      }));

      // Render frame 0 pixels for each animation
      animations.forEach(a => {
        (a.frame0_pixels || []).forEach(p => {
          allPixels.set(`${p.x},${p.y}`, p.color);
        });
      });
      redraw();
    });

    hookThis.handleEvent("animation-frame", ({ animation_id, pixels }) => {
      const region = animationRegions.find(a => a.id === animation_id);
      if (!region) return;

      // Clear old animation pixels in this region
      const minX = Math.min(region.x1, region.x2);
      const maxX = Math.max(region.x1, region.x2);
      const minY = Math.min(region.y1, region.y2);
      const maxY = Math.max(region.y1, region.y2);

      for (let x = minX; x <= maxX; x++) {
        for (let y = minY; y <= maxY; y++) {
          allPixels.delete(`${x},${y}`);
        }
      }

      // Paint new frame pixels
      pixels.forEach(p => {
        allPixels.set(`${p.x},${p.y}`, p.color);
      });

      redraw();
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
        if (isDragMode) {
          e.preventDefault();
          const { gridX, gridY } = getGridCoords(e.clientX, e.clientY);
          dragStart = { gridX, gridY };
          return;
        }
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
      } else if (isDragMode && dragStart) {
        const { gridX, gridY } = getGridCoords(e.clientX, e.clientY);
        redraw();
        // Draw drag preview rectangle
        ctx.save();
        ctx.translate(offsetX, offsetY);
        ctx.scale(scale, scale);
        ctx.strokeStyle = '#333';
        ctx.lineWidth = 1 / scale;
        ctx.setLineDash([4 / scale, 4 / scale]);
        const rx = Math.min(dragStart.gridX, gridX) * PIXEL_SIZE;
        const ry = Math.min(dragStart.gridY, gridY) * PIXEL_SIZE;
        const rw = (Math.abs(gridX - dragStart.gridX) + 1) * PIXEL_SIZE;
        const rh = (Math.abs(gridY - dragStart.gridY) + 1) * PIXEL_SIZE;
        ctx.strokeRect(rx, ry, rw, rh);
        ctx.setLineDash([]);
        ctx.restore();
        return;
      } else if (isDrawing) {
        draw(e);
      }
    });

    // Listen on document for mouseup so it works anywhere
    document.addEventListener('mouseup', (e) => {
      if (isDragMode && dragStart) {
        const { gridX, gridY } = getGridCoords(e.clientX, e.clientY);
        isDragMode = false;
        const animBtn = document.getElementById('animation-add-btn');
        if (animBtn) animBtn.style.outline = '';
        canvas.style.cursor = '';

        const payload = {
          x1: Math.min(dragStart.gridX, gridX),
          y1: Math.min(dragStart.gridY, gridY),
          x2: Math.max(dragStart.gridX, gridX),
          y2: Math.max(dragStart.gridY, gridY)
        };
        dragStart = null;

        hookThis.pushEventTo(
          canvas,
          "create_animation",
          payload,
          (reply) => {
            if (reply && reply.animation_id) {
              animationRegions.push({
                id: reply.animation_id,
                x1: payload.x1, y1: payload.y1,
                x2: payload.x2, y2: payload.y2,
                frame_count: 1
              });
              createEditorBox(reply.animation_id, payload.x1, payload.y1, payload.x2, payload.y2);
            } else {
              console.warn('Could not create animation region:', reply && reply.error);
            }
          }
        );
        return;
      }
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
        
        // Update the color indicator
        const colorIndicator = document.getElementById('current-color-indicator');
        if (colorIndicator) {
          colorIndicator.style.backgroundColor = currentColor;
        }
        
        // Reset picker trigger appearance
        const pickerTrigger = document.getElementById('color-picker-trigger');
        pickerTrigger.style.backgroundColor = '';
        pickerTrigger.classList.remove('has-custom-color');
      });
    });

    // Set initial color
    colorOptions[0].classList.add('selected');
    
    // Setup canvas visibility toggle
    setupCanvasToggle();
    
    // Setup animation add button (drag mode)
    const animAddBtn = document.getElementById('animation-add-btn');
    if (animAddBtn) {
      animAddBtn.addEventListener('click', () => {
        isDragMode = !isDragMode;
        animAddBtn.style.outline = isDragMode ? '2px solid #333' : '';
        canvas.style.cursor = isDragMode ? 'crosshair' : '';
      });
    }
    
    // Initialize color picker with retry logic for production timing issues
    let retryCount = 0;
    const maxRetries = 10; // Max 10 retries (~150ms total with RAF timing)
    
    const initializeColorPicker = () => {
      console.log('[ColorPicker] Attempting initialization, retry:', retryCount);
      
      // Query all required DOM elements
      const pickerTrigger = document.getElementById('color-picker-trigger');
      const pickerPopup = document.getElementById('color-picker-popup');
      const pickerContainer = document.getElementById('color-picker-container');
      const hexInputContainer = document.getElementById('hex-input-container');
      const closePicker = document.querySelector('.close-picker');
      const pipetteToggle = document.getElementById('pipette-mode-toggle');
      
      // Log what we found
      console.log('[ColorPicker] DOM elements status:', {
        pickerTrigger: !!pickerTrigger,
        pickerPopup: !!pickerPopup,
        pickerContainer: !!pickerContainer,
        hexInputContainer: !!hexInputContainer,
        closePicker: !!closePicker,
        pipetteToggle: !!pipetteToggle
      });
      
      // Check if all required elements exist
      if (!pickerTrigger || !pickerPopup || !pickerContainer || 
          !hexInputContainer || !closePicker || !pipetteToggle) {
        
        if (retryCount < maxRetries) {
          retryCount++;
          console.warn('[ColorPicker] Some elements not ready, retrying on next frame...');
          requestAnimationFrame(initializeColorPicker);
        } else {
          console.error('[ColorPicker] Failed to initialize after', maxRetries, 'retries. Elements still missing.');
        }
        return;
      }
      
      // All elements ready, proceed with initialization
      console.log('[ColorPicker] All elements ready, initializing...');
      const hexPicker = initColorPicker();
      const hexInput = initHexInput();
      setupColorPickerUI(hexPicker, hexInput);
      console.log('[ColorPicker] Initialization complete!');
    };

    // Start initialization on next animation frame
    requestAnimationFrame(initializeColorPicker);
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
