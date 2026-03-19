# Rootring Webring Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fixed bottom-left collapsible rootring webring widget to every page of the blog, open by default each new session but remembering the collapsed state within a session via `sessionStorage`.

**Architecture:** A native `<details>`/`<summary>` HTML element in `root.html.heex` provides the expand/collapse affordance. A small inline `<script>` (safe here since this is a static layout, not a LiveView template) reads/writes `sessionStorage` to track collapsed state within the browser session. CSS in `app.css` positions and styles the widget to match the blog's existing palette.

**Tech Stack:** Phoenix HEEx layout template, vanilla JS (`sessionStorage`), custom CSS (matching existing `--slate-blue`, `--mauve`, `--blue-gray` palette variables).

---

### Task 1: Add CSS for the rootring widget

**Files:**
- Modify: `assets/css/app.css` (append at end of file)

- [ ] **Step 1: Append rootring widget styles to `app.css`**

Add at the very end of `assets/css/app.css`:

```css
/* Rootring webring widget */
.rootring-widget {
  position: fixed;
  bottom: 1rem;
  left: 1rem;
  z-index: 100;
  font-family: inherit;
  font-size: 0.84rem;
}

.rootring-widget summary {
  display: inline-flex;
  align-items: center;
  gap: 0.6rem;
  cursor: pointer;
  list-style: none;
  padding: 0.35rem 0.7rem;
  border: 1px solid var(--blue-gray);
  border-radius: 999px;
  background: var(--slate-blue);
  color: var(--mauve);
  user-select: none;
}

.rootring-widget summary::-webkit-details-marker {
  display: none;
}

.rootring-widget .summary-title {
  letter-spacing: 0.05em;
  text-transform: lowercase;
}

.rootring-widget .summary-hint {
  opacity: 0.6;
  font-size: 0.78rem;
}

.rootring-widget summary::after {
  content: "▾";
  opacity: 0.7;
}

.rootring-widget[open] summary::after {
  content: "▴";
}

.rootring-widget nav {
  display: inline-flex;
  flex-direction: column;
  gap: 0.3rem;
  margin-top: 0.4rem;
  padding: 0.55rem 0.7rem;
  border: 1px solid var(--blue-gray);
  border-radius: 0.6rem;
  background: var(--slate-blue);
  color: var(--mauve);
  min-width: 9rem;
}

.rootring-widget nav a {
  color: var(--mauve);
  text-decoration: none;
  padding: 0.1rem 0;
}

.rootring-widget nav a:hover {
  text-decoration: underline;
  opacity: 0.85;
}
```

- [ ] **Step 2: Visually verify in browser**

The styles won't show anything yet (no HTML), but you can confirm no CSS parse errors by checking the browser dev tools network/console after the next step.

---

### Task 2: Add widget HTML and sessionStorage script to root layout

**Files:**
- Modify: `lib/indie_web/components/layouts/root.html.heex`

- [ ] **Step 1: Add the widget before `</body>`**

Replace the closing `</body>` tag with:

```html
    <details id="rootring-widget" class="rootring-widget">
      <summary>
        <span class="summary-title"><a href="https://rootr.ing/" style="color: inherit; text-decoration: none;">rootring</a></span>
        <span class="summary-hint">webring</span>
      </summary>
      <nav aria-label="Webring">
        <a href="https://rootr.ing/prev?site=https://YOUR-SITE">← Prev</a>
        <a href="https://rootr.ing/random">Random</a>
        <a href="https://rootr.ing/directory">Directory</a>
        <a href="https://rootr.ing/next?site=https://YOUR-SITE">Next →</a>
      </nav>
    </details>
    <script>
      (function() {
        var w = document.getElementById('rootring-widget');
        if (!sessionStorage.getItem('rootring-closed')) {
          w.setAttribute('open', '');
        }
        w.addEventListener('toggle', function() {
          if (w.open) {
            sessionStorage.removeItem('rootring-closed');
          } else {
            sessionStorage.setItem('rootring-closed', '1');
          }
        });
      })();
    </script>
  </body>
```

**Important:** Replace `YOUR-SITE` in both `prev` and `next` hrefs with the blog's actual public URL.

- [ ] **Step 2: Replace YOUR-SITE placeholder with the actual blog URL**

Find out the blog's public homepage URL and substitute it into both links:
- `https://rootr.ing/prev?site=https://YOUR-SITE`
- `https://rootr.ing/next?site=https://YOUR-SITE`

- [ ] **Step 3: Verify behavior in browser**

1. Load any page — widget should appear open in bottom-left
2. Click the summary to collapse it — it should close
3. Navigate to another page — it should remain closed
4. Close the tab and reopen — it should be open again

- [ ] **Step 4: Commit**

```bash
git add lib/indie_web/components/layouts/root.html.heex assets/css/app.css
git commit -m "feat: add rootring webring widget to bottom-left corner"
```
