# Post Header Pixel Strip Design

**Date:** 2026-03-22  
**Status:** Approved

## Overview

Add a fun pixelated color strip at the bottom of each post header, inspired by the rootring widget's pixel grid. Each post gets a unique but deterministic color pattern based on its ID.

## Visual Design

### Placement
- **Location:** Bottom of `.post-header` element (inside the header, at the very bottom)
- **Layout:** Horizontal strip spanning the full width of the header
- **Integration:** Sits between the post title/link and the post content area

### Appearance
- **Pixel Count:** 18 colored squares per header (fixed count for consistent grid layout)
- **Pixel Size:** 4px height, width determined by CSS grid (`1fr` columns)
- **Grid Structure:** 
  - Display: CSS Grid with `repeat(N, 1fr)` columns
  - Gap: 1px between pixels
  - Background: Black (#000) to create visible separation
  - Padding: 3px around the entire grid
- **Border Integration:** The pixel strip sits within the existing header border (not a separate element outside)

### Color Palette

Vibrant, indie web aesthetic colors matching the rootring widget style:

```elixir
[
  "#FF00FF",  # Magenta
  "#00FFFF",  # Cyan
  "#FFFF00",  # Yellow
  "#FF6B6B",  # Coral red
  "#4ECDC4",  # Teal
  "#95E1D3",  # Mint
  "#F38181",  # Salmon
  "#AA96DA",  # Lavender
  "#FCBAD3",  # Pink
  "#FFFFD2",  # Cream
  "#A8E6CF",  # Seafoam
  "#FFD3B6",  # Peach
  "#FFAAA5",  # Light coral
  "#FF8B94",  # Rose
  "#6C5CE7",  # Purple
  "#FD79A8",  # Hot pink
  "#FDCB6E",  # Gold
  "#00B894",  # Emerald
]
```

### Pattern Generation

**Deterministic Randomization:**
- Each post gets a unique color pattern based on its post ID
- Pattern is consistent across page reloads (same post = same pattern)
- Uses seeded random number generator (`:rand.seed/1` with post ID hash)
- Randomly selects colors from the palette for each pixel position

## Technical Implementation

### Architecture

**Server-Side Logic (LiveView):**
- Add helper function to generate pixel patterns
- Assign pixel colors alongside post data in mount/handle_event
- Function is pure/deterministic (no side effects)

**Template Rendering (HEEx):**
- Render pixel strip inside `.post-header` element
- Use `:for` comprehension to loop over pixel colors
- Apply inline `background` style per pixel

**Styling (CSS):**
- Add `.post-header-pixels` class for container
- Use CSS Grid matching rootring widget structure
- Ensure pixels render crisply (no anti-aliasing)

### Component Structure

```
.post-header (existing)
  ├── .post-title + .expand-collapse-btn (existing)
  ├── .post-header-link (existing)
  └── .post-header-pixels (NEW)
      └── span.pixel × N (generated from @pixel_colors)
```

### Helper Function Design

```elixir
defp generate_pixel_colors(post_id, count \\ 18) do
  # Hash the post ID to create a seed
  seed = :erlang.phash2(post_id)
  
  # Use seed_s for isolated random state (doesn't affect global :rand state)
  rand_state = :rand.seed_s(:exsss, {seed, seed, seed})
  
  # Color palette
  colors = [
    "#FF00FF", "#00FFFF", "#FFFF00", "#FF6B6B",
    "#4ECDC4", "#95E1D3", "#F38181", "#AA96DA",
    "#FCBAD3", "#FFFFD2", "#A8E6CF", "#FFD3B6",
    "#FFAAA5", "#FF8B94", "#6C5CE7", "#FD79A8",
    "#FDCB6E", "#00B894"
  ]
  
  # Generate pixel colors using isolated state
  {pixel_colors, _final_state} = 
    Enum.map_reduce(1..count, rand_state, fn _, state ->
      {random_color, new_state} = :rand.uniform_s(length(colors), state)
      {Enum.at(colors, random_color - 1), new_state}
    end)
  
  pixel_colors
end
```

### Template Structure

**home_live.html.heex** (multiple posts, loop context):
```heex
<div class="post-header" id={post.id} style={"width: #{post.width};"}>
  <h2>
    <button id={"expand-btn-#{index}"} class="expand-collapse-btn" ...>
      [+]
    </button>
    {post.title}
  </h2>
  <.link navigate={"/p/#{post.id}"} class="post-header-link">[link]</.link>
  
  <!-- NEW: Pixel strip (note: post.pixel_colors in loop context) -->
  <div class="post-header-pixels">
    <span :for={color <- post.pixel_colors} class="pixel" style={"background: #{color};"}></span>
  </div>
</div>
```

**post_live.html.heex** (single post, assign context):
```heex
<div class="post-header" id={@post.id} style={"width: #{@post.width};"}>
  <h2>{@post.title}</h2>
  <.link navigate={"/p/#{@post.id}"} class="post-header-link">[link]</.link>
  
  <!-- NEW: Pixel strip (note: @post.pixel_colors in assign context) -->
  <div class="post-header-pixels">
    <span :for={color <- @post.pixel_colors} class="pixel" style={"background: #{color};"}></span>
  </div>
</div>
```

### CSS Implementation

```css
.post-header-pixels {
  display: grid;
  grid-template-columns: repeat(18, 1fr); /* Fixed to match pixel count */
  gap: 1px;
  padding: 3px;
  background: #000;
  margin-top: 0.5rem; /* Space from title */
}

.post-header-pixels .pixel {
  display: block;
  height: 4px;
  image-rendering: pixelated; /* Crisp rendering (supported in modern browsers) */
}
```

## Files to Modify

1. **lib/indie_web/live/home_live.ex**
   - Add `generate_pixel_colors/2` helper function
   - Update `mount/3` to assign pixel colors for each post
   - Map over posts and add `:pixel_colors` to each post map

2. **lib/indie_web/live/post_live.ex**
   - Add `generate_pixel_colors/2` helper function (same as above)
   - Update `mount/3` to assign pixel colors for the single post
   - Add `:pixel_colors` to the post assign

3. **lib/indie_web/live/home_live.html.heex**
   - Add pixel strip div inside `.post-header` (after title/link, before closing)
   - Render pixels using `:for={color <- post.pixel_colors}`

4. **lib/indie_web/live/post_live.html.heex**
   - Add pixel strip div inside `.post-header` (same structure as home)
   - Render pixels using `:for={color <- @post.pixel_colors}` (note the @ for assign context)

5. **assets/css/app.css**
   - Add `.post-header-pixels` styles
   - Add `.pixel` styles

## Implementation Notes

### Data Flow

1. Post struct is loaded from database
2. In LiveView mount, `generate_pixel_colors(post.id)` is called
3. Pixel color list is added to post map: `Map.put(post, :pixel_colors, colors)`
4. Template renders pixels with inline background styles
5. CSS Grid handles layout and spacing

### Edge Cases

- **Missing post ID:** Fallback to empty list or default pattern
- **Multiple posts on page:** Each gets own pattern (home page)
- **Single post page:** Single pattern generated (post page)
- **Page reload:** Same pattern appears (deterministic seeding)

### Performance

- Minimal overhead: 15-20 random selections per post
- Pattern generation happens once per mount
- No database queries needed
- CSS Grid is efficient for small counts

### Testing Considerations

- Verify deterministic behavior: same post ID = same pattern
- Check pattern uniqueness: different posts = different patterns
- Ensure colors render correctly across browsers
- Validate responsive behavior (grid scales with header width)

## Future Enhancements (Out of Scope)

- Allow customizing pixel count per post
- Add animation effects (subtle shimmer, hover effects)
- Provide color palette themes
- Store pattern in database for true permanence
- Add pixel strip to other elements (content footer, etc.)

## Success Criteria

- [x] Pixel strip appears at bottom of all post headers
- [x] Each post has unique color pattern
- [x] Pattern is consistent across page reloads
- [x] Styling matches rootring widget aesthetic
- [x] No performance degradation
- [x] Works on both home page (multiple posts) and post page (single post)
