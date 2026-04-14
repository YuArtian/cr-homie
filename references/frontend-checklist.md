# Frontend Quality Checklist

## Frontend Code Principles

These principles guide every frontend finding. Apply them **before** the specific checklists below.

### 1. KISS — Concise & Efficient

Delete what can be deleted. Use the most direct implementation.

- Ternary or short-circuit where a full if/else block is overkill
- Early return instead of deeply nested conditionals
- Leverage built-in APIs (`Array.prototype` methods, CSS features) before reaching for libraries
- If a utility wrapper adds no value over the raw call, remove the wrapper
- **Ask**: "Can I achieve the same result with less code without sacrificing readability?"

### 2. Component SRP — High Cohesion, Low Coupling

One component = one reason to change. Componentize, but don't over-split.

- A component that mixes data fetching, business logic, and UI rendering → split into container + presentational, or use hooks/composables to extract logic
- A component that is only used once and has no independent meaning → don't extract it just for "reuse"
- Props > 7 is a smell: the component might be doing too much
- **Extract when**: the piece has an independent concept name, is reused, or simplifies testing
- **Don't extract when**: it only saves 10 lines and adds an indirection nobody benefits from
- **Ask**: "Does this component have a clear, single responsibility? Would extracting this help or just add indirection?"

### 3. Functional Programming — Separate Side Effects

Business logic stays pure. Side effects live at the edges.

- Data transformations (`filter`, `map`, `reduce`, `sort`) should be pure functions — no API calls, no DOM access, no state mutations inside
- Side effects (API calls, subscriptions, DOM manipulation, timers) belong in hooks (`useEffect`, `onMounted`), event handlers, or dedicated service layers — not mixed into rendering or data logic
- Prefer immutable updates: spread/`Object.assign` for objects, `map`/`filter` for arrays — never `push`/`splice` on state directly
- Extract reusable pure logic into utility functions that take input and return output with no hidden dependencies
- **Red flag**: A function that both computes a value AND triggers a side effect
- **Ask**: "Given the same input, does this function always return the same output? If not, can I split it?"

### 4. DRY — Don't Repeat, Don't Over-Abstract

Extract shared patterns. But three similar lines beat a premature abstraction.

- Same logic in 2+ places → extract to a shared hook, utility, or component
- Same API call pattern in 3+ places → extract to a service function
- Similar but not identical → parameterize only if the variations are clean; forced generalization is worse than duplication
- **Rule of three**: Don't abstract until the third occurrence. Two is coincidence, three is a pattern.
- **Ask**: "If I change this logic, how many places do I need to update?"

### 5. Clean Architecture — Naming as Documentation

Reading the code should reveal intent without comments.

- File/folder names describe the domain concept, not the technical role: `useCartItems.ts` > `customHook3.ts`
- Functions named by what they return or do: `formatPrice()`, `validateEmail()`, `fetchUserProfile()`
- Boolean variables/props prefixed with `is`/`has`/`should`/`can`: `isLoading`, `hasPermission`
- Components named by what they render: `<OrderSummary>` > `<DataDisplay>`
- Constants named by meaning: `MAX_RETRY_COUNT` > `NUM_3`
- **Red flag**: A name that requires a comment to explain, or generic names like `data`, `info`, `handle`, `process`, `temp`
- **Ask**: "Can a new team member understand this file's purpose from its name alone?"

### 6. YAGNI — No Over-Engineering

Build for today's requirements. Delete speculative code.

- No unused props, parameters, or function overloads "for future use"
- No wrapper components that just pass through props without adding behavior
- No configuration objects for things that have exactly one value
- No abstraction layers for a single implementation
- If you can solve it with a CSS property, don't write JavaScript
- **Ask**: "Is this solving a problem we actually have right now?"

### 7. Production Readiness — No Fake Data, No Fake Features ⚠️

**This is a P0/P1 check.** Fake data and stub features in production cause user trust issues and potential data integrity problems.

Flag immediately:
- **Hardcoded mock data**: Arrays/objects with fake user names, placeholder prices, dummy IDs in non-test files
- **Hardcoded API URLs**: `localhost:3000`, `127.0.0.1`, `staging.example.com` in production code paths
- **TODO/FIXME stubs**: Functions that return hardcoded values with `// TODO: implement`
- **Placeholder content**: `Lorem ipsum`, `test@test.com`, `placeholder.jpg`, `image.png` as default values
- **Feature stubs**: UI elements (buttons, menu items) that render but have no handler, or handlers that are empty / `console.log` only
- **Conditional mock overrides**: `if (isDev) return mockData` without proper environment gating
- **Fake loading states**: Hardcoded `setTimeout` simulating async behavior instead of real API calls

**Exception**: Only acceptable when user explicitly marks it as intentional (e.g., Storybook stories, demo pages, dev fixtures). Even then, it should be clearly isolated from production code paths.

**Ask**: "If a real user clicks this, does something real happen? If this data is displayed, is it from a real source?"

---

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
