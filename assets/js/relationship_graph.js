// Seeded RNG (Mulberry32) — deterministic layout per seed
function createSeededRandom(seed) {
  let state = seed >>> 0;
  return function() {
    state = (state + 0x6D2B79F5) >>> 0;
    let t = Math.imul(state ^ (state >>> 15), state | 1);
    t = (t + Math.imul(t ^ (t >>> 7), t | 61)) >>> 0;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const FORCE_PARAMS = {
  repulsionStrength: 15000,
  attractionStrength: 0.08,
  idealEdgeLength: 180,
  centerGravity: 0.01,
  damping: 0.85,
  maxIterations: 300,
  seed: 42
};

// Responsive parameters based on viewport
function getResponsiveParams() {
  const canvasWidth = document.documentElement.clientWidth;
  const isMobile = canvasWidth < 768;
  const isSmallMobile = canvasWidth < 480;

  return {
    nodeRadius: isSmallMobile ? 28 : isMobile ? 32 : 40,
    initialSpread: isSmallMobile ? 0.8 : isMobile ? 0.6 : 0.3, // fraction of min dimension
    repulsionMultiplier: isSmallMobile ? 2.0 : isMobile ? 1.5 : 1.0,
    centerGravityMultiplier: isSmallMobile ? 0.3 : isMobile ? 0.5 : 1.0,
    idealEdgeLength: isSmallMobile ? 140 : isMobile ? 160 : 180,
  };
}

const RelationshipGraph = {

  mounted() {
    this.canvas = this.el;
    this.ctx = this.canvas.getContext('2d');
    this.nodes = [];
    this.edges = [];
    this.selectedNode = null;
    this.hoveredNode = null;
    this.hoveredEdge = null;

    // Pan/zoom state
    this.scale = 1;
    this.offsetX = 0;
    this.offsetY = 0;
    this.isPanning = false;
    this.lastPanX = 0;
    this.lastPanY = 0;

    // Drag state
    this.draggedNode = null;
    this.hasMoved = false;

    // Touch state for pinch zoom
    this.touchState = {
      initialDistance: 0,
      initialScale: 1,
      initialCenterX: 0,
      initialCenterY: 0,
      initialOffsetX: 0,
      initialOffsetY: 0,
      isPinching: false,
      isPanning: false,
      lastTouchX: 0,
      lastTouchY: 0,
      // Tap detection
      touchStartTime: 0,
      touchStartX: 0,
      touchStartY: 0,
      potentialTapNode: null
    };

    // Seeded random for deterministic layout
    this.random = createSeededRandom(FORCE_PARAMS.seed);

    // Canvas size
    this.resizeCanvas();
    window.addEventListener('resize', () => this.resizeCanvas());

    // Mouse events
    this.canvas.addEventListener('wheel', (e) => this.handleWheel(e), { passive: false });
    this.canvas.addEventListener('mousedown', (e) => this.handleMouseDown(e));
    this.canvas.addEventListener('mousemove', (e) => this.handleMouseMove(e));
    this.canvas.addEventListener('mouseup', (e) => this.handleMouseUp(e));
    this.canvas.addEventListener('click', (e) => this.handleClick(e));
    this.canvas.addEventListener('contextmenu', (e) => e.preventDefault());

    // Touch events for mobile pinch zoom and pan
    // iOS: use passive: true for touchstart, call preventDefault() only when needed in touchmove
    this.canvas.addEventListener('touchstart', (e) => this.handleTouchStart(e), { passive: true });
    this.canvas.addEventListener('touchmove', (e) => this.handleTouchMove(e), { passive: false });
    this.canvas.addEventListener('touchend', (e) => this.handleTouchEnd(e), { passive: true });
    this.canvas.addEventListener('touchcancel', (e) => this.handleTouchEnd(e), { passive: true });

    // Listen for graph data from LiveView
    this.handleEvent("load_graph", ({ nodes, edges }) => {
      this.nodes = (nodes || []).map(n => ({ ...n, vx: 0, vy: 0 }));
      this.edges = edges || [];
      this.initForceLayout();    // compute positions
      this.fitToView();          // center/scale to viewport
      this.render();
    });

    // Initial render
    this.render();
  },

  updated() {
    // Re-render when data changes (though we use phx-update="ignore" and pushEvent)
  },

  destroyed() {
    window.removeEventListener('resize', () => this.resizeCanvas());
  },

  resizeCanvas() {
    const rect = this.canvas.parentElement.getBoundingClientRect();
    this.canvas.width = rect.width * window.devicePixelRatio;
    this.canvas.height = rect.height * window.devicePixelRatio;
    this.canvas.style.width = rect.width + 'px';
    this.canvas.style.height = rect.height + 'px';
    this.ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
    this.render();
  },

  fitToView() {
    if (this.nodes.length === 0) return;

    let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
    this.nodes.forEach(node => {
      minX = Math.min(minX, node.x);
      maxX = Math.max(maxX, node.x);
      minY = Math.min(minY, node.y);
      maxY = Math.max(maxY, node.y);
    });

    const padding = 100;
    const graphWidth = maxX - minX + padding * 2;
    const graphHeight = maxY - minY + padding * 2;

    const canvasWidth = this.canvas.width / window.devicePixelRatio;
    const canvasHeight = this.canvas.height / window.devicePixelRatio;

    this.scale = Math.min(canvasWidth / graphWidth, canvasHeight / graphHeight, 2);
    this.offsetX = canvasWidth / 2 - (minX + maxX) / 2 * this.scale;
    this.offsetY = canvasHeight / 2 - (minY + maxY) / 2 * this.scale;
  },

  initForceLayout() {
    const { nodes, edges } = this;
    const params = FORCE_PARAMS;
    const rand = this.random;
    const responsive = getResponsiveParams();

    // Initialize positions randomly within canvas bounds
    const canvasWidth = this.canvas.width / window.devicePixelRatio;
    const canvasHeight = this.canvas.height / window.devicePixelRatio;
    const centerX = canvasWidth / 2;
    const centerY = canvasHeight / 2;
    const spread = Math.min(canvasWidth, canvasHeight) * responsive.initialSpread;

    nodes.forEach(node => {
      // Random initial position around center
      node.x = centerX + (rand() - 0.5) * spread;
      node.y = centerY + (rand() - 0.5) * spread;
      node.vx = 0;
      node.vy = 0;
    });

    // Build nodeMap once for O(1) edge lookups
    const nodeMap = new Map(nodes.map(n => [n.id, n]));

    // Responsive force parameters
    const repulsionStrength = params.repulsionStrength * responsive.repulsionMultiplier;
    const centerGravity = params.centerGravity * responsive.centerGravityMultiplier;
    const idealEdgeLength = responsive.idealEdgeLength;

    // Force-directed iterations
    for (let iter = 0; iter < params.maxIterations; iter++) {
      // Repulsion: all nodes repel each other
      for (let i = 0; i < nodes.length; i++) {
        const n1 = nodes[i];
        for (let j = i + 1; j < nodes.length; j++) {
          const n2 = nodes[j];
          const dx = n2.x - n1.x;
          const dy = n2.y - n1.y;
          const distSq = dx * dx + dy * dy;
          const dist = Math.max(1, Math.sqrt(distSq));
          const force = repulsionStrength / (dist * dist);
          const fx = (force * dx) / dist;
          const fy = (force * dy) / dist;
          n1.vx -= fx;
          n1.vy -= fy;
          n2.vx += fx;
          n2.vy += fy;
        }
      }

      // Attraction: connected nodes attract (Hooke's law: F = k * displacement)
      edges.forEach(edge => {
        const source = nodeMap.get(edge.source);
        const target = nodeMap.get(edge.target);
        if (!source || !target) return;
        const dx = target.x - source.x;
        const dy = target.y - source.y;
        const dist = Math.sqrt(dx * dx + dy * dy) || 1;
        const force = (dist - idealEdgeLength) * params.attractionStrength;
        const fx = (force * dx) / dist;
        const fy = (force * dy) / dist;
        source.vx += fx;
        source.vy += fy;
        target.vx -= fx;
        target.vy -= fy;
      });

      // Center gravity
      nodes.forEach(node => {
        const dx = centerX - node.x;
        const dy = centerY - node.y;
        node.vx += dx * centerGravity;
        node.vy += dy * centerGravity;
      });

      // Apply velocity with damping
      nodes.forEach(node => {
        node.vx *= params.damping;
        node.vy *= params.damping;
        node.x += node.vx;
        node.y += node.vy;
      });
    }

    // Clean up velocity properties
    nodes.forEach(node => {
      delete node.vx;
      delete node.vy;
    });

    // Post-layout: reduce edge crossings
    this.reduceCrossings(nodes, edges);
  },

  // Post-layout edge crossing reduction
  reduceCrossings(nodes, edges) {
    const MAX_PASSES = 5;
    const responsive = getResponsiveParams();
    const NEIGHBOR_RADIUS = responsive.nodeRadius * 6; // ~6x node radius

    const countCrossings = () => {
      let crossings = 0;
      for (let i = 0; i < edges.length; i++) {
        for (let j = i + 1; j < edges.length; j++) {
          if (this.edgesCross(edges[i], edges[j], nodes)) crossings++;
        }
      }
      return crossings;
    };

    let bestCrossings = countCrossings();

    for (let pass = 0; pass < MAX_PASSES; pass++) {
      let improved = false;

      for (let i = 0; i < nodes.length; i++) {
        const n1 = nodes[i];
        const screenPos1 = this.graphToScreen(n1.x, n1.y);

        // Find nearby nodes
        for (let j = i + 1; j < nodes.length; j++) {
          const n2 = nodes[j];
          const screenPos2 = this.graphToScreen(n2.x, n2.y);

          const dx = screenPos2.x - screenPos1.x;
          const dy = screenPos2.y - screenPos1.y;
          const dist = Math.sqrt(dx * dx + dy * dy);

          if (dist > NEIGHBOR_RADIUS) continue;

          // Try swapping positions
          const tempX = n1.x;
          const tempY = n1.y;
          n1.x = n2.x;
          n1.y = n2.y;
          n2.x = tempX;
          n2.y = tempY;

          const newCrossings = countCrossings();
          if (newCrossings < bestCrossings) {
            bestCrossings = newCrossings;
            improved = true;
          } else {
            // Swap back
            n2.x = n1.x;
            n2.y = n1.y;
            n1.x = tempX;
            n1.y = tempY;
          }
        }
      }

      if (!improved) break;
    }
  },

  // Check if two edges cross (line segment intersection)
  edgesCross(e1, e2, nodes) {
    const a = nodes.find(n => n.id === e1.source);
    const b = nodes.find(n => n.id === e1.target);
    const c = nodes.find(n => n.id === e2.source);
    const d = nodes.find(n => n.id === e2.target);
    if (!a || !b || !c || !d) return false;

    // Skip if edges share a node
    if (e1.source === e2.source || e1.source === e2.target ||
        e1.target === e2.source || e1.target === e2.target) return false;

    return this.segmentsIntersect(a, b, c, d);
  },

  // Line segment intersection test (graph coordinates)
  segmentsIntersect(a, b, c, d) {
    const x1 = a.x, y1 = a.y;
    const x2 = b.x, y2 = b.y;
    const x3 = c.x, y3 = c.y;
    const x4 = d.x, y4 = d.y;

    const denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
    if (Math.abs(denom) < 1e-10) return false; // Parallel or collinear

    const t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom;
    const u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom;

    return t > 0 && t < 1 && u > 0 && u < 1;
  },

  // Coordinate transforms
  screenToGraph(x, y) {
    return {
      x: (x - this.offsetX) / this.scale,
      y: (y - this.offsetY) / this.scale
    };
  },

  graphToScreen(x, y) {
    return {
      x: x * this.scale + this.offsetX,
      y: y * this.scale + this.offsetY
    };
  },

  handleWheel(e) {
    e.preventDefault();
    const rect = this.canvas.getBoundingClientRect();
    const mouseX = e.clientX - rect.left;
    const mouseY = e.clientY - rect.top;

    const zoomFactor = e.deltaY > 0 ? 0.97 : 1.03;
    const newScale = Math.max(0.1, Math.min(5, this.scale * zoomFactor));

    // Zoom towards mouse
    this.offsetX = mouseX - (mouseX - this.offsetX) * (newScale / this.scale);
    this.offsetY = mouseY - (mouseY - this.offsetY) * (newScale / this.scale);
    this.scale = newScale;

    this.render();
  },

  // Touch event handlers for mobile pinch zoom and pan
  handleTouchStart(e) {
    // iOS: don't call preventDefault() here - only in touchmove when needed
    const rect = this.canvas.getBoundingClientRect();
    const touches = e.touches;

    if (touches.length === 1) {
      // Single touch - could be pan, node drag, or tap
      const touch = touches[0];
      const mouseX = touch.clientX - rect.left;
      const mouseY = touch.clientY - rect.top;
      const graphPos = this.screenToGraph(mouseX, mouseY);

      // Check if touching a node
      const node = this.getNodeAt(graphPos.x, graphPos.y);

      // Record for tap/drag detection - don't start drag yet!
      this.touchState.touchStartTime = Date.now();
      this.touchState.touchStartX = mouseX;
      this.touchState.touchStartY = mouseY;
      this.touchState.potentialTapNode = node;
      this.touchState.potentialDragNode = node; // Track for possible drag
      this.touchState.hasMovedEnoughForDrag = false;

      if (node) {
        // Don't start dragging yet - wait for movement in handleTouchMove
        this.touchState.isPinching = false;
        this.touchState.isPanning = false;
        this.draggedNode = null;
      } else {
        // Start panning immediately (no tap on empty space)
        this.touchState.isPanning = true;
        this.touchState.lastTouchX = mouseX;
        this.touchState.lastTouchY = mouseY;
        this.touchState.isPinching = false;
        this.touchState.potentialTapNode = null;
        this.touchState.potentialDragNode = null;
      }
    } else if (touches.length === 2) {
      // Two touches - pinch zoom
      const touch1 = touches[0];
      const touch2 = touches[1];

      const x1 = touch1.clientX - rect.left;
      const y1 = touch1.clientY - rect.top;
      const x2 = touch2.clientX - rect.left;
      const y2 = touch2.clientY - rect.top;

      const dx = x2 - x1;
      const dy = y2 - y1;
      const distance = Math.sqrt(dx * dx + dy * dy);

      this.touchState.initialDistance = distance;
      this.touchState.initialScale = this.scale;
      this.touchState.initialCenterX = (x1 + x2) / 2;
      this.touchState.initialCenterY = (y1 + y2) / 2;
      this.touchState.initialOffsetX = this.offsetX;
      this.touchState.initialOffsetY = this.offsetY;
      this.touchState.isPinching = true;
      this.touchState.isPanning = false;
      this.draggedNode = null;
      this.touchState.potentialTapNode = null;
      this.touchState.potentialDragNode = null;
    }
  },

  handleTouchMove(e) {
    // Only preventDefault when actually handling a gesture (pan/drag/pinch)
    // This allows native scrolling on elements that need it, and avoids iOS cancelling touches
    const shouldPreventDefault = this.touchState.isPinching || 
                                 this.touchState.isPanning || 
                                 this.draggedNode || 
                                 this.touchState.potentialDragNode;
    if (shouldPreventDefault) {
      e.preventDefault();
    }
    const rect = this.canvas.getBoundingClientRect();
    const touches = e.touches;

    if (this.touchState.isPinching && touches.length === 2) {
      // Pinch zoom
      const touch1 = touches[0];
      const touch2 = touches[1];

      const x1 = touch1.clientX - rect.left;
      const y1 = touch1.clientY - rect.top;
      const x2 = touch2.clientX - rect.left;
      const y2 = touch2.clientY - rect.top;

      const dx = x2 - x1;
      const dy = y2 - y1;
      const distance = Math.sqrt(dx * dx + dy * dy);

      if (this.touchState.initialDistance > 0) {
        const scaleFactor = distance / this.touchState.initialDistance;
        const newScale = Math.max(0.1, Math.min(5, this.touchState.initialScale * scaleFactor));

        // Zoom towards pinch center
        this.offsetX = this.touchState.initialCenterX - (this.touchState.initialCenterX - this.touchState.initialOffsetX) * (newScale / this.touchState.initialScale);
        this.offsetY = this.touchState.initialCenterY - (this.touchState.initialCenterY - this.touchState.initialOffsetY) * (newScale / this.touchState.initialScale);
        this.scale = newScale;

        this.render();
      }
    // Handle active node dragging (check this FIRST, before potential drag)
    if (this.draggedNode && touches.length === 1) {
      const touch = touches[0];
      const mouseX = touch.clientX - rect.left;
      const mouseY = touch.clientY - rect.top;

      const graphPos = this.screenToGraph(mouseX, mouseY);
      this.draggedNode.x = graphPos.x;
      this.draggedNode.y = graphPos.y;
      this.render();
    } else if (this.touchState.potentialDragNode && touches.length === 1) {
      // Potential node drag - check if moved enough to become a real drag
      const touch = touches[0];
      const mouseX = touch.clientX - rect.left;
      const mouseY = touch.clientY - rect.top;

      // Track position for distance calculation
      this.touchState.lastTouchX = mouseX;
      this.touchState.lastTouchY = mouseY;

      const dx = mouseX - this.touchState.touchStartX;
      const dy = mouseY - this.touchState.touchStartY;
      const distanceMoved = Math.sqrt(dx * dx + dy * dy);

      if (distanceMoved > 5 && !this.touchState.hasMovedEnoughForDrag) {
        // Movement exceeded threshold - start dragging
        this.touchState.hasMovedEnoughForDrag = true;
        this.hasMoved = true;
        this.touchState.potentialTapNode = null; // Not a tap anymore
        this.draggedNode = this.touchState.potentialDragNode;
        this.touchState.potentialDragNode = null;
      }
      // Don't move yet - wait for next touchmove after drag starts
      }
    } else if (this.touchState.isPanning && touches.length === 1) {
      // Pan
      const touch = touches[0];
      const mouseX = touch.clientX - rect.left;
      const mouseY = touch.clientY - rect.top;

      const dx = mouseX - this.touchState.lastTouchX;
      const dy = mouseY - this.touchState.lastTouchY;

      if (Math.abs(dx) > 5 || Math.abs(dy) > 5) {
        this.hasMoved = true;
      }

      this.offsetX += dx;
      this.offsetY += dy;
      this.touchState.lastTouchX = mouseX;
      this.touchState.lastTouchY = mouseY;
      this.render();
    }
  },

  handleTouchEnd(e) {
    // Check for tap on node (quick touch without significant movement)
    const tapTimeout = 300; // ms
    const tapThreshold = 10; // pixels
    const now = Date.now();
    const timeElapsed = now - this.touchState.touchStartTime;
    const dx = this.touchState.touchStartX - (this.touchState.lastTouchX || this.touchState.touchStartX);
    const dy = this.touchState.touchStartY - (this.touchState.lastTouchY || this.touchState.touchStartY);
    const distanceMoved = Math.sqrt(dx * dx + dy * dy);

    // If it was a potential tap on a node, and quick enough, and didn't move much
    if (this.touchState.potentialTapNode && 
        timeElapsed < tapTimeout && 
        distanceMoved < tapThreshold &&
        !this.hasMoved) {
      // Fire select_character event like a click
      const node = this.touchState.potentialTapNode;
      const rect = this.canvas.getBoundingClientRect();
      // Use the touch start position for the popup
      const mouseX = this.touchState.touchStartX;
      const mouseY = this.touchState.touchStartY;
      const isMobile = window.innerWidth < 768;
      this.pushEvent("select_character", { id: node.id, x: mouseX, y: mouseY, is_mobile: isMobile });
    }

    // End drag
    if (this.draggedNode) {
      this.draggedNode = null;
    }

    // End pinch
    if (this.touchState.isPinching) {
      this.touchState.isPinching = false;
    }

    // End pan
    if (this.touchState.isPanning) {
      this.touchState.isPanning = false;
    }

    // Reset all touch state
    this.touchState.potentialTapNode = null;
    this.touchState.potentialDragNode = null;
    this.touchState.hasMovedEnoughForDrag = false;
    this.hasMoved = false;
  },

  handleMouseDown(e) {
    const rect = this.canvas.getBoundingClientRect();
    const mouseX = e.clientX - rect.left;
    const mouseY = e.clientY - rect.top;
    const graphPos = this.screenToGraph(mouseX, mouseY);

    // Check if clicking on a node
    const node = this.getNodeAt(graphPos.x, graphPos.y);

    if (node && e.button === 0) {
      // Start dragging this node
      e.preventDefault();
      this.draggedNode = node;
      this.hasMoved = true;  // Prevent click from firing after drag
      this.canvas.style.cursor = 'grabbing';
      return;
    }

    // Left click on empty space — start panning
    if (e.button === 0) {
      e.preventDefault();
      this.isPanning = true;
      this.hasMoved = false;
      this.lastPanX = mouseX;
      this.lastPanY = mouseY;
      this.canvas.style.cursor = 'grabbing';
    }
  },

  handleMouseMove(e) {
    const rect = this.canvas.getBoundingClientRect();
    const mouseX = e.clientX - rect.left;
    const mouseY = e.clientY - rect.top;

    if (this.draggedNode) {
      const graphPos = this.screenToGraph(mouseX, mouseY);
      this.draggedNode.x = graphPos.x;
      this.draggedNode.y = graphPos.y;
      this.render();
      return;
    }

    if (this.isPanning) {
      const dx = mouseX - this.lastPanX;
      const dy = mouseY - this.lastPanY;
      if (Math.abs(dx) > 20 || Math.abs(dy) > 20) {
        this.hasMoved = true;
      }
      this.offsetX += dx;
      this.offsetY += dy;
      this.lastPanX = mouseX;
      this.lastPanY = mouseY;
      this.render();
      return;
    }

    // Check hover
    const graphPos = this.screenToGraph(mouseX, mouseY);
    this.hoveredNode = this.getNodeAt(graphPos.x, graphPos.y);
    this.hoveredEdge = !this.hoveredNode ? this.getEdgeAt(graphPos.x, graphPos.y) : null;

    this.canvas.style.cursor = this.hoveredNode || this.hoveredEdge ? 'pointer' : 'default';

    if (this.hoveredNode || this.hoveredEdge) {
      this.render();
    }
  },

  handleMouseUp(e) {
    if (this.draggedNode) {
      this.draggedNode = null;
      this.canvas.style.cursor = 'default';
      return;
    }

    if (this.isPanning) {
      this.isPanning = false;
      this.canvas.style.cursor = 'default';
    }
  },

  handleClick(e) {
    // Only treat as click if mouse didn't move (not a drag)
    if (this.hasMoved || this.draggedNode) {
      this.hasMoved = false;
      return;
    }

    const rect = this.canvas.getBoundingClientRect();
    const mouseX = e.clientX - rect.left;
    const mouseY = e.clientY - rect.top;
    const graphPos = this.screenToGraph(mouseX, mouseY);

    const node = this.getNodeAt(graphPos.x, graphPos.y);
    if (node) {
      const isMobile = window.innerWidth < 768;
      this.pushEvent("select_character", { id: node.id, x: mouseX, y: mouseY, is_mobile: isMobile });
    } else {
      // Click on empty space - close detail panel
      this.pushEvent("close_detail", {});
    }
  },

  getNodeAt(x, y) {
    const radius = getResponsiveParams().nodeRadius; // Node radius in graph coordinates
    for (const node of this.nodes) {
      const dx = node.x - x;
      const dy = node.y - y;
      if (dx * dx + dy * dy <= radius * radius) {
        return node;
      }
    }
    return null;
  },

  getEdgeAt(x, y) {
    const threshold = 8 / this.scale; // Hit threshold in graph coordinates
    for (const edge of this.edges) {
      const source = this.nodes.find(n => n.id === edge.source);
      const target = this.nodes.find(n => n.id === edge.target);
      if (!source || !target) continue;

      // Distance from point to line segment
      const dist = this.pointToLineDistance(x, y, source.x, source.y, target.x, target.y);
      if (dist < threshold) {
        return edge;
      }
    }
    return null;
  },

  pointToLineDistance(px, py, x1, y1, x2, y2) {
    const dx = x2 - x1;
    const dy = y2 - y1;
    const lenSq = dx * dx + dy * dy;
    if (lenSq === 0) return Math.hypot(px - x1, py - y1);

    let t = ((px - x1) * dx + (py - y1) * dy) / lenSq;
    t = Math.max(0, Math.min(1, t));
    const closestX = x1 + t * dx;
    const closestY = y1 + t * dy;
    return Math.hypot(px - closestX, py - closestY);
  },

  render() {
    const ctx = this.ctx;
    const width = this.canvas.width / window.devicePixelRatio;
    const height = this.canvas.height / window.devicePixelRatio;

    // Clear
    ctx.clearRect(0, 0, width, height);

    // Draw background grid
    this.drawGrid(ctx, width, height);

    // Draw edges
    this.edges.forEach(edge => this.drawEdge(ctx, edge));

    // Draw nodes
    this.nodes.forEach(node => this.drawNode(ctx, node));

    // Draw hover tooltip
    if (this.hoveredEdge) {
      this.drawEdgeTooltip(ctx, this.hoveredEdge);
    }
  },

  drawGrid(ctx, width, height) {
    const gridSize = 50 * this.scale;
    if (gridSize < 20) return; // Don't draw if too small

    ctx.strokeStyle = 'rgba(139,115,85,0.08)';
    ctx.lineWidth = 1;

    // Vertical lines
    const startX = -this.offsetX % gridSize;
    for (let x = startX; x < width; x += gridSize) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, height);
      ctx.stroke();
    }

    // Horizontal lines
    const startY = -this.offsetY % gridSize;
    for (let y = startY; y < height; y += gridSize) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();
    }
  },

  drawNode(ctx, node) {
    const pos = this.graphToScreen(node.x, node.y);
    const radius = getResponsiveParams().nodeRadius;
    const isHovered = this.hoveredNode === node;

    // Node background circle
    ctx.beginPath();
    ctx.arc(pos.x, pos.y, radius, 0, Math.PI * 2);

    // Determine color based on tags — sepia/grayscale palette
    const isPC = node.tags?.includes('pc') || node.tags?.includes('player');
    const fillColor = isPC ? '#8b7355' : '#555'; // sepia for PC, gray for NPC
    const borderColor = isHovered ? '#c4a882' : '#0d0d0d';

    ctx.fillStyle = fillColor;
    ctx.fill();
    ctx.strokeStyle = borderColor;
    ctx.lineWidth = isHovered ? 4 : 2;
    ctx.stroke();

    // Draw image if available
    if (node.image_url) {
      // We'd need to preload images - for now draw initials
      this.drawInitials(ctx, node.name, pos.x, pos.y, radius);
    } else {
      this.drawInitials(ctx, node.name, pos.x, pos.y, radius);
    }

    // Draw name label
    this.drawNodeLabel(ctx, node, pos.x, pos.y, radius);
  },

  drawInitials(ctx, name, x, y, radius) {
    const initials = name
      .split(' ')
      .map(w => w[0])
      .join('')
      .toUpperCase()
      .slice(0, 2);

    const responsive = getResponsiveParams();
    const fontSize = Math.max(14, Math.floor(responsive.nodeRadius * 0.6));

    ctx.fillStyle = '#d4c9b8';
    ctx.font = `bold ${fontSize}px monospace`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(initials, x, y);
  },

  drawNodeLabel(ctx, node, x, y, radius) {
    const responsive = getResponsiveParams();
    const fontSize = Math.max(10, Math.floor(responsive.nodeRadius * 0.35));

    ctx.fillStyle = '#999';
    ctx.font = `${fontSize}px monospace`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    ctx.fillText(node.name, x, y + radius + 6);
  },

  drawEdge(ctx, edge) {
    const source = this.nodes.find(n => n.id === edge.source);
    const target = this.nodes.find(n => n.id === edge.target);
    if (!source || !target) return;

    const start = this.graphToScreen(source.x, source.y);
    const end = this.graphToScreen(target.x, target.y);

    // Curved line - quadratic bezier
    const midX = (start.x + end.x) / 2;
    const midY = (start.y + end.y) / 2;

    // Perpendicular offset for curve
    const dx = end.x - start.x;
    const dy = end.y - start.y;
    const dist = Math.hypot(dx, dy);
    const curveAmount = Math.min(dist * 0.15, 50);
    const perpX = -dy / dist * curveAmount;
    const perpY = dx / dist * curveAmount;

    const isHovered = this.hoveredEdge === edge;

    ctx.beginPath();
    ctx.moveTo(start.x, start.y);
    ctx.quadraticCurveTo(midX + perpX, midY + perpY, end.x, end.y);

    ctx.strokeStyle = isHovered ? '#c4a882' : 'rgba(139,115,85,0.6)'; // sepia on hover, muted sepia normal
    ctx.lineWidth = isHovered ? 3 : 2;
    ctx.stroke();

    // Draw arrowhead
    this.drawArrowhead(ctx, start.x, start.y, midX + perpX, midY + perpY, edge);
  },

  drawArrowhead(ctx, fromX, fromY, toX, toY, edge) {
    // Actually draw arrow at 60% along the curve
    const t = 0.6;
    const source = this.nodes.find(n => n.id === edge.source);
    const target = this.nodes.find(n => n.id === edge.target);
    if (!source || !target) return;

    const start = this.graphToScreen(source.x, source.y);
    const end = this.graphToScreen(target.x, target.y);
    const midX = (start.x + end.x) / 2;
    const midY = (start.y + end.y) / 2;
    const dx = end.x - start.x;
    const dy = end.y - start.y;
    const dist = Math.hypot(dx, dy);
    const curveAmount = Math.min(dist * 0.15, 50);
    const perpX = -dy / dist * curveAmount;
    const perpY = dx / dist * curveAmount;

    // Point at t along curve
    const x1 = start.x;
    const y1 = start.y;
    const xc = midX + perpX;
    const yc = midY + perpY;
    const x2 = end.x;
    const y2 = end.y;

    // Quadratic bezier point at t
    const mt = 1 - t;
    const px = mt * mt * x1 + 2 * mt * t * xc + t * t * x2;
    const py = mt * mt * y1 + 2 * mt * t * yc + t * t * y2;

    // Derivative for angle
    const dx_dt = 2 * mt * (xc - x1) + 2 * t * (x2 - xc);
    const dy_dt = 2 * mt * (yc - y1) + 2 * t * (y2 - yc);
    const angle = Math.atan2(dy_dt, dx_dt);

    const arrowSize = 8;
    ctx.beginPath();
    ctx.moveTo(px, py);
    ctx.lineTo(px - arrowSize * Math.cos(angle - Math.PI / 6), py - arrowSize * Math.sin(angle - Math.PI / 6));
    ctx.lineTo(px - arrowSize * Math.cos(angle + Math.PI / 6), py - arrowSize * Math.sin(angle + Math.PI / 6));
    ctx.closePath();
    ctx.fillStyle = 'rgba(139,115,85,0.6)';
    ctx.fill();
  },

  drawEdgeTooltip(ctx, edge) {
    const source = this.nodes.find(n => n.id === edge.source);
    const target = this.nodes.find(n => n.id === edge.target);
    if (!source || !target) return;

    const start = this.graphToScreen(source.x, source.y);
    const end = this.graphToScreen(target.x, target.y);
    const midX = (start.x + end.x) / 2;
    const midY = (start.y + end.y) / 2;

    const text = edge.description || 'Relationship';
    const tags = edge.tags?.join(', ') || '';

    ctx.font = '11px monospace';
    const padding = 8;
    const textWidth = Math.max(ctx.measureText(text).width, ctx.measureText(tags).width);
    const boxWidth = textWidth + padding * 2;
    const boxHeight = 44;

    // Background
    ctx.fillStyle = 'rgba(45,37,32,0.95)'; // dark sepia
    ctx.fillRect(midX - boxWidth / 2, midY - boxHeight - 10, boxWidth, boxHeight);

    // Border
    ctx.strokeStyle = '#8b7355';
    ctx.lineWidth = 1;
    ctx.strokeRect(midX - boxWidth / 2, midY - boxHeight - 10, boxWidth, boxHeight);

    // Text
    ctx.fillStyle = '#d4c9b8';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    ctx.fillText(text, midX, midY - boxHeight - 10 + padding);
    if (tags) {
      ctx.font = '10px monospace';
      ctx.fillStyle = '#999';
      ctx.fillText(tags, midX, midY - boxHeight - 10 + padding + 18);
    }
  }
};

export default RelationshipGraph;
