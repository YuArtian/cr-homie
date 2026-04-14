# Frontend Quality Checklist

## Accessibility (a11y)

### Critical (P0/P1)
- **Missing alt text**: `<img>` without `alt`, decorative images should use `alt=""`
- **No keyboard navigation**: Interactive elements not reachable via Tab, custom widgets missing `onKeyDown`
- **Missing ARIA on custom widgets**: Custom dropdowns, modals, tabs without `role`, `aria-expanded`, `aria-selected`
- **Focus trap missing in modals**: Tab key escapes modal/dialog overlay
- **Color as only indicator**: Error/success states distinguished only by color, not icon/text

### Important (P2)
- **Missing form labels**: `<input>` without associated `<label>` or `aria-label`
- **Heading hierarchy broken**: Skipping levels (h1 → h3), multiple h1 on page
- **Low color contrast**: Text-to-background ratio below WCAG AA (4.5:1 normal, 3:1 large text)
- **Auto-playing media**: Video/audio without user-initiated play
- **Missing skip navigation**: Long page without skip-to-content link

### Questions to Ask
- "Can a screen reader user complete this flow?"
- "Can a keyboard-only user interact with this component?"
- "Is there a non-color indicator for every state change?"

---

## Rendering Performance

### React
- **Missing memo**: Component re-renders on every parent render despite same props
- **Inline objects/arrays in JSX**: `style={{...}}` or `options={[...]}` recreated every render
- **useEffect missing deps / wrong deps**: Stale closures or infinite re-render loops
- **Heavy computation in render**: Filtering/sorting large arrays without `useMemo`
- **Context overuse**: Single large context causing unrelated components to re-render

### Vue
- **Reactive pitfall**: Assigning non-reactive objects into reactive state
- **v-for without key**: Or using array index as key on dynamic lists
- **Computed vs watch misuse**: Using `watch` for derived state that should be `computed`
- **Unnecessary deep watch**: `watch(obj, fn, { deep: true })` on large objects

### General
- **Large lists without virtualization**: Rendering 1000+ DOM nodes (use virtual scroll)
- **Layout thrashing**: Reading layout properties (offsetHeight) then writing styles in a loop
- **Unoptimized images**: Large images without lazy loading, missing width/height (CLS)
- **Expensive operations in scroll/resize handlers**: Without `requestAnimationFrame` or throttle
- **Memory leaks**: Event listeners, timers, subscriptions not cleaned up on unmount

### Questions to Ask
- "Will this component re-render when it shouldn't?"
- "What happens with 1000 items in this list?"
- "Are expensive computations memoized?"

---

## Bundle Size

### Anti-patterns
- **Full library import**: `import _ from 'lodash'` instead of `import debounce from 'lodash/debounce'`
- **Missing code splitting**: Large route-level components not using dynamic `import()` / `React.lazy`
- **Uncompressed assets**: SVGs not optimized, images not in modern formats (WebP/AVIF)
- **Duplicate dependencies**: Same library in different versions bundled together
- **Dev-only code in production**: Debug logs, mock data, test utilities not tree-shaken

### Questions to Ask
- "Does this import pull in more than needed?"
- "Should this route/component be lazy loaded?"
- "Is this dependency justified for what it provides?"

---

## CSS & Styling

### Anti-patterns
- **z-index arms race**: Arbitrary large values (z-index: 9999) without a scale system
- **Hardcoded pixels**: Fixed px values that should use rem/em or design tokens
- **Missing responsive handling**: Components that break on mobile widths
- **Style conflicts**: Global CSS leaking into components, specificity wars
- **Unused CSS**: Large stylesheets with rules that no longer match any element

### Layout Issues
- **Missing overflow handling**: Long text/content breaking layout (use `overflow`, `text-overflow`)
- **No max-width constraints**: Content stretching to full viewport on ultra-wide screens
- **Fixed dimensions on flexible content**: Hardcoded height/width on user-generated content

---

## State Management

### Anti-patterns
- **Prop drilling > 3 levels**: Data passed through intermediate components that don't use it
- **Derived state stored separately**: State that can be computed from other state but is manually synced
- **Global state for local concerns**: Using Redux/Zustand/Pinia for state that belongs to a single component
- **Missing loading/error states**: Async data without loading indicator or error handling in UI
- **Stale state after navigation**: Data from previous route still visible during transition

### Questions to Ask
- "Does this state belong at this level, or should it be lifted/lowered?"
- "Can this be derived from existing state instead of stored separately?"
- "What does the user see while this data is loading?"

---

## i18n & Content

- **Hardcoded user-facing strings**: Text literals in JSX/template instead of i18n keys
- **String concatenation for sentences**: `"Hello " + name + "!"` breaks in languages with different word order
- **Date/number formatting**: Using `.toLocaleDateString()` without explicit locale, or hardcoded formats
- **Text overflow**: UI breaks with longer translations (German/Finnish ~30% longer than English)
- **Missing RTL support**: Layout assumptions that break in right-to-left languages (Arabic, Hebrew)

---

## Browser Compatibility

- **Modern API without polyfill**: `structuredClone`, `Array.at()`, `AbortSignal.timeout()` — check target browser support
- **CSS features without fallback**: `container queries`, `has()`, `subgrid` — depends on browser matrix
- **Safari-specific issues**: `position: sticky` in overflow containers, `100vh` on mobile Safari, date input quirks
- **Missing `type="button"`**: Buttons inside forms default to `type="submit"`, causing accidental submissions
