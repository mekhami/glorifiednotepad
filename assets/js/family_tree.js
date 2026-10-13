// Parchment family tree renderer.
// Expects `family_tree:render` events with {focus_id, nodes, parent_links, partnerships}.
const SVG_NS = "http://www.w3.org/2000/svg";

const INK = "#3a2a1a";
const FOCUS_INK = "#7a2a12";
const NODE_W = 150;
const HIDDEN_W = 50; // unknown (placeholder) parents take a narrow, empty slot
const UNIT_GAP = 40;
const ROW_H = 150;
const MARGIN = 80;

const STATUS_LABEL = {
  married: "= wed =",
  partnered: "~ bound ~",
  divorced: "≠ parted ≠",
  widowed: "= wed, till death ="
};

const KIND_NOTE = { adopted: "(taken in)", step: "(step)" };

function el(name, attrs = {}, parent = null) {
  const node = document.createElementNS(SVG_NS, name);
  for (const [k, v] of Object.entries(attrs)) node.setAttribute(k, v);
  if (parent) parent.appendChild(node);
  return node;
}

// Deterministic per-line wobble so the ink looks hand-drawn but doesn't jitter between renders.
function hash(str) {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) h = Math.imul(h ^ str.charCodeAt(i), 16777619);
  return h >>> 0;
}

function wobblyLine(x1, y1, x2, y2) {
  const seed = hash(`${Math.round(x1)},${Math.round(y1)},${Math.round(x2)},${Math.round(y2)}`);
  const len = Math.hypot(x2 - x1, y2 - y1);
  const amp = Math.min(3, len * 0.03);
  const offset = ((seed % 1000) / 1000 - 0.5) * 2 * amp;
  const mx = (x1 + x2) / 2;
  const my = (y1 + y2) / 2;
  // Perpendicular offset for the control point
  const nx = len ? -(y2 - y1) / len : 0;
  const ny = len ? (x2 - x1) / len : 0;
  return `M${x1} ${y1} Q${mx + nx * offset} ${my + ny * offset} ${x2} ${y2}`;
}

// --- Layout ---------------------------------------------------------------

function layout(tree) {
  const byId = new Map(tree.nodes.map(n => [n.id, n]));
  const widthOf = id => (byId.get(id).hidden ? HIDDEN_W : NODE_W);
  const parentsOf = new Map();
  const childrenOf = new Map();
  for (const l of tree.parent_links) {
    if (!byId.has(l.parent_id) || !byId.has(l.child_id)) continue;
    if (!parentsOf.has(l.child_id)) parentsOf.set(l.child_id, []);
    parentsOf.get(l.child_id).push(l.parent_id);
    if (!childrenOf.has(l.parent_id)) childrenOf.set(l.parent_id, []);
    childrenOf.get(l.parent_id).push(l.child_id);
  }

  const partnersOf = new Map();
  for (const p of tree.partnerships) {
    if (!byId.has(p.a_id) || !byId.has(p.b_id)) continue;
    if (byId.get(p.a_id).generation !== byId.get(p.b_id).generation) continue;
    for (const [x, y] of [[p.a_id, p.b_id], [p.b_id, p.a_id]]) {
      if (!partnersOf.has(x)) partnersOf.set(x, []);
      partnersOf.get(x).push(y);
    }
  }

  // Rows of units; a unit is a chain of partners drawn side by side.
  const maxGen = Math.max(...tree.nodes.map(n => n.generation));
  const rows = [];
  const unitOf = new Map();
  for (let g = 0; g <= maxGen; g++) {
    const members = tree.nodes.filter(n => n.generation === g).map(n => n.id);
    const seen = new Set();
    const units = [];
    for (const id of members) {
      if (seen.has(id)) continue;
      // Collect the partner component, then walk it as a chain from an end.
      const comp = [];
      const stack = [id];
      while (stack.length) {
        const cur = stack.pop();
        if (seen.has(cur)) continue;
        seen.add(cur);
        comp.push(cur);
        for (const p of partnersOf.get(cur) || []) stack.push(p);
      }
      const start = comp.find(c => (partnersOf.get(c) || []).length <= 1) || comp[0];
      const chain = [];
      const visited = new Set();
      let cur = start;
      while (cur && !visited.has(cur)) {
        chain.push(cur);
        visited.add(cur);
        cur = (partnersOf.get(cur) || []).find(p => !visited.has(p));
      }
      for (const c of comp) if (!visited.has(c)) chain.push(c);
      const unit = { members: chain, x: 0, width: chain.reduce((w, m) => w + widthOf(m), 0) };
      chain.forEach(m => unitOf.set(m, unit));
      units.push(unit);
    }
    rows.push(units);
  }

  const xOf = id => {
    const u = unitOf.get(id);
    const i = u.members.indexOf(id);
    const before = u.members.slice(0, i).reduce((w, m) => w + widthOf(m), 0);
    return u.x + before + widthOf(id) / 2;
  };
  const mean = xs => xs.reduce((a, b) => a + b, 0) / xs.length;

  const placeRow = (units, desiredCentre) => {
    const withDesired = units.map((u, i) => ({ u, i, d: desiredCentre(u) }));
    withDesired.sort((a, b) => {
      if (a.d == null && b.d == null) return a.i - b.i;
      if (a.d == null) return 1;
      if (b.d == null) return -1;
      return a.d - b.d;
    });
    let right = -Infinity;
    let fallback = 0;
    const ordered = [];
    for (const { u, d } of withDesired) {
      const want = d == null ? Math.max(fallback, right + UNIT_GAP) : d - u.width / 2;
      u.x = right === -Infinity ? want : Math.max(want, right + UNIT_GAP);
      right = u.x + u.width;
      fallback = right + UNIT_GAP;
      ordered.push(u);
    }
    return ordered;
  };

  const parentCentre = u => {
    const xs = u.members.flatMap(m => (parentsOf.get(m) || []).map(xOf));
    return xs.length ? mean(xs) : null;
  };
  const childCentre = u => {
    const xs = u.members.flatMap(m => (childrenOf.get(m) || []).map(xOf));
    return xs.length ? mean(xs) : null;
  };

  // Top-down: children under parents. Bottom-up: parents over children. Then top-down again.
  rows[0] = placeRow(rows[0], () => null);
  for (let g = 1; g < rows.length; g++) rows[g] = placeRow(rows[g], parentCentre);
  for (let g = rows.length - 2; g >= 0; g--) {
    const current = new Map(rows[g].map(u => [u, u.x + u.width / 2]));
    rows[g] = placeRow(rows[g], u => childCentre(u) ?? current.get(u));
  }
  for (let g = 1; g < rows.length; g++) {
    const current = new Map(rows[g].map(u => [u, u.x + u.width / 2]));
    rows[g] = placeRow(rows[g], u => parentCentre(u) ?? current.get(u));
  }

  const positions = new Map();
  for (const n of tree.nodes) positions.set(n.id, { x: xOf(n.id), y: n.generation * ROW_H });
  return { positions, parentsOf };
}

// --- Drawing --------------------------------------------------------------

function draw(svg, tree) {
  const { positions, parentsOf } = layout(tree);
  const byId = new Map(tree.nodes.map(n => [n.id, n]));
  const kindOf = new Map(tree.parent_links.map(l => [`${l.parent_id}>${l.child_id}`, l.kind]));
  const partnered = new Map(tree.partnerships.map(p => [[p.a_id, p.b_id].sort().join("|"), p]));

  svg.replaceChildren();
  const world = el("g", { class: "ft-world" }, svg);
  const lines = el("g", { class: "ft-lines", fill: "none", stroke: INK, "stroke-width": 1.6, "stroke-linecap": "round" }, world);
  const labels = el("g", { class: "ft-labels" }, world);

  // Names first so we can measure them for connector endpoints.
  const boxes = new Map();
  for (const n of tree.nodes) {
    const { x, y } = positions.get(n.id);
    if (n.hidden) {
      boxes.set(n.id, { left: x, right: x, top: y, bottom: y, hidden: true });
      continue;
    }
    const isFocus = n.id === tree.focus_id;
    const g = el("g", { class: "ft-person", "data-id": n.id, tabindex: "0", role: "link" }, labels);
    const text = el("text", {
      x, y,
      "text-anchor": "middle",
      "dominant-baseline": "middle",
      class: isFocus ? "ft-name ft-focus" : "ft-name",
      fill: isFocus ? FOCUS_INK : INK
    }, g);
    text.textContent = n.deceased ? `${n.name} ✝` : n.name;
    if (n.has_more) {
      const more = el("tspan", { class: "ft-more", dx: "4" }, text);
      more.textContent = "☞";
      el("title", {}, g).textContent = `${n.name}: more kin beyond this page`;
    }
    if (n.pc) {
      const mark = el("text", { x, y: y + 17, "text-anchor": "middle", class: "ft-note", fill: INK }, g);
      mark.textContent = "❦";
    }
    const b = text.getBBox();
    boxes.set(n.id, { left: b.x, right: b.x + b.width, top: b.y, bottom: b.y + b.height });
  }

  // Partnerships between adjacent names in the same row.
  for (const p of tree.partnerships) {
    const a = positions.get(p.a_id);
    const b = positions.get(p.b_id);
    if (!a || !b || a.y !== b.y) continue;
    const [l, r] = a.x < b.x ? [p.a_id, p.b_id] : [p.b_id, p.a_id];
    const x1 = boxes.get(l).right + 6;
    const x2 = boxes.get(r).left - 6;
    const path = el("path", { d: wobblyLine(x1, a.y, x2, a.y) }, lines);
    if (p.status === "divorced" || p.status === "widowed") path.setAttribute("stroke-dasharray", "4 5");
    const label = el("text", { x: (x1 + x2) / 2, y: a.y + 16, "text-anchor": "middle", class: "ft-note", fill: INK }, labels);
    label.textContent = STATUS_LABEL[p.status] || "";
  }

  // Group children by their set of parents, then draw a bracket per group.
  const groups = new Map();
  for (const [childId, parents] of parentsOf) {
    const key = [...parents].sort().join("|");
    if (!groups.has(key)) groups.set(key, { parents: [...parents].sort(), children: [] });
    groups.get(key).children.push(childId);
  }

  for (const { parents: allParents, children } of groups.values()) {
    // Unknown (placeholder) parents aren't drawn; children hang from the known ones.
    const parents = allParents.filter(id => !byId.get(id).hidden);
    const pPos = parents.map(id => positions.get(id));
    const cPos = children.map(id => positions.get(id));
    const parentY = Math.max(...pPos.map(p => p.y));
    const childY = Math.min(...cPos.map(c => c.y));
    const barY = childY - ROW_H / 2 + 8;

    let ax, ay;
    if (parents.length === 0) {
      // Siblings with no known parents: a short stub fading up into nothing.
      ax = cPos.reduce((s, c) => s + c.x, 0) / cPos.length;
      ay = barY - 30;
      el("path", { d: wobblyLine(ax, ay, ax, barY - 12), "stroke-dasharray": "2 4", opacity: "0.45" }, lines);
      ay = barY - 12;
    } else if (parents.length === 2 && partnered.has(parents.join("|")) && pPos[0].y === pPos[1].y) {
      ax = (pPos[0].x + pPos[1].x) / 2;
      ay = pPos[0].y + 24; // just below the "= wed =" label
    } else if (parents.length === 1) {
      ax = pPos[0].x;
      ay = boxes.get(parents[0]).bottom + (byId.get(parents[0]).pc ? 20 : 6);
    } else {
      ax = pPos.reduce((s, p) => s + p.x, 0) / pPos.length;
      ay = parentY + 14;
      for (const id of parents) {
        const p = positions.get(id);
        el("path", { d: wobblyLine(p.x, boxes.get(id).bottom + 4, ax, ay) }, lines);
      }
    }

    el("path", { d: wobblyLine(ax, ay, ax, barY) }, lines);
    const xs = cPos.map(c => c.x).concat(ax);
    const minX = Math.min(...xs);
    const maxX = Math.max(...xs);
    if (maxX - minX > 1) el("path", { d: wobblyLine(minX, barY, maxX, barY) }, lines);

    for (const childId of children) {
      const c = positions.get(childId);
      const kinds = allParents.map(p => kindOf.get(`${p}>${childId}`));
      const kind = kinds.find(k => k && k !== "biological");
      const path = el("path", { d: wobblyLine(c.x, barY, c.x, boxes.get(childId).top - 4) }, lines);
      if (kind) {
        path.setAttribute("stroke-dasharray", "3 4");
        const note = el("text", {
          x: c.x,
          y: boxes.get(childId).bottom + (byId.get(childId).pc ? 28 : 13),
          "text-anchor": "middle",
          class: "ft-note",
          fill: INK
        }, labels);
        note.textContent = KIND_NOTE[kind];
      }
    }
  }

  // Bounds for fitting / centring
  const all = [...boxes.values()].filter(b => !b.hidden);
  const bounds = {
    minX: Math.min(...all.map(b => b.left)) - MARGIN,
    maxX: Math.max(...all.map(b => b.right)) + MARGIN,
    minY: Math.min(...all.map(b => b.top)) - MARGIN,
    maxY: Math.max(...all.map(b => b.bottom)) + MARGIN
  };
  return { world, bounds, focus: positions.get(tree.focus_id) };
}

// --- Hook -----------------------------------------------------------------

const FamilyTree = {
  mounted() {
    this.interactive = this.el.dataset.interactive !== "false";
    this.svg = el("svg", { class: "ft-svg", role: "img", "aria-label": "Family tree" }, this.el);
    this.view = { x: 0, y: 0, scale: 1 };

    this.handleEvent("family_tree:render", tree => this.render(tree));
    this.svg.addEventListener("click", e => this.onClick(e));
    this.svg.addEventListener("keydown", e => {
      if (e.key === "Enter") this.onClick(e);
    });

    if (this.interactive) this.enablePanZoom();
    this.onResize = () => this.current && this.render(this.current);
    window.addEventListener("resize", this.onResize);
  },

  destroyed() {
    window.removeEventListener("resize", this.onResize);
  },

  render(tree) {
    this.current = tree;
    const { world, bounds, focus } = draw(this.svg, tree);
    this.world = world;
    const w = this.el.clientWidth;
    const h = this.el.clientHeight;

    if (this.interactive) {
      // Fit if it fits, otherwise keep scale at 1 and centre on the focus person.
      const fit = Math.min(w / (bounds.maxX - bounds.minX), h / (bounds.maxY - bounds.minY));
      const scale = Math.min(1, Math.max(0.5, fit));
      const cx = fit >= 0.5 ? (bounds.minX + bounds.maxX) / 2 : focus.x;
      const cy = fit >= 0.5 ? (bounds.minY + bounds.maxY) / 2 : focus.y;
      this.view = { scale, x: w / 2 - cx * scale, y: h / 2 - cy * scale };
      this.applyView();
    } else {
      this.svg.setAttribute(
        "viewBox",
        `${bounds.minX} ${bounds.minY} ${bounds.maxX - bounds.minX} ${bounds.maxY - bounds.minY}`
      );
    }
  },

  applyView() {
    const { x, y, scale } = this.view;
    this.world?.setAttribute("transform", `translate(${x} ${y}) scale(${scale})`);
  },

  onClick(e) {
    if (this.dragged) return;
    const person = e.target.closest(".ft-person");
    if (person && person.dataset.id !== this.current?.focus_id) {
      this.pushEvent("select_person", { id: person.dataset.id });
    }
  },

  enablePanZoom() {
    const pointers = new Map();
    let last = null;
    let pinchDist = null;

    this.svg.addEventListener("pointerdown", e => {
      pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
      last = { x: e.clientX, y: e.clientY };
      this.dragged = false;
    });

    this.svg.addEventListener("pointermove", e => {
      if (!pointers.has(e.pointerId)) return;
      pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });

      if (pointers.size === 2) {
        const [a, b] = [...pointers.values()];
        const dist = Math.hypot(a.x - b.x, a.y - b.y);
        if (pinchDist) {
          const rect = this.svg.getBoundingClientRect();
          this.zoomAt((a.x + b.x) / 2 - rect.left, (a.y + b.y) / 2 - rect.top, dist / pinchDist);
        }
        pinchDist = dist;
        this.dragged = true;
        return;
      }

      const dx = e.clientX - last.x;
      const dy = e.clientY - last.y;
      if (Math.abs(dx) + Math.abs(dy) > 3) this.dragged = true;
      if (this.dragged) {
        if (!this.svg.hasPointerCapture(e.pointerId)) this.svg.setPointerCapture(e.pointerId);
        this.view.x += dx;
        this.view.y += dy;
        last = { x: e.clientX, y: e.clientY };
        this.applyView();
      }
    });

    const end = e => {
      pointers.delete(e.pointerId);
      if (pointers.size < 2) pinchDist = null;
      // Let the click handler see `dragged` before resetting it.
      setTimeout(() => (this.dragged = false), 0);
    };
    this.svg.addEventListener("pointerup", end);
    this.svg.addEventListener("pointercancel", end);

    this.svg.addEventListener("wheel", e => {
      e.preventDefault();
      const rect = this.svg.getBoundingClientRect();
      this.zoomAt(e.clientX - rect.left, e.clientY - rect.top, Math.exp(-e.deltaY * 0.0015));
    }, { passive: false });
  },

  zoomAt(px, py, factor) {
    const scale = Math.min(2.5, Math.max(0.3, this.view.scale * factor));
    const k = scale / this.view.scale;
    this.view = { scale, x: px - (px - this.view.x) * k, y: py - (py - this.view.y) * k };
    this.applyView();
  }
};

export default FamilyTree;
