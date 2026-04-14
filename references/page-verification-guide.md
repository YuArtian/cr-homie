# Page-Level Verification Guide

Requires Chrome DevTools MCP. This step runs after code review to verify the page at runtime.

## Prerequisites

- Chrome DevTools MCP server is connected
- Dev server is running and accessible at the provided `--url`

## Verification Procedure

### Step 1: Open Page

Navigate to the provided URL:

```
Tool: mcp__chrome-devtools__navigate_page
  url: <user-provided --url>
```

If the page fails to load, report as P0 finding and skip remaining checks.

### Step 2: Console Error Check ⚠️ REQUIRED

Capture console errors and warnings since page load:

```
Tool: mcp__chrome-devtools__list_console_messages
  types: ["error", "warn"]
```

Flag as findings:

| Console Type | Severity | Examples |
|-------------|----------|---------|
| Uncaught errors | P0 | `TypeError`, `ReferenceError`, unhandled promise rejection |
| React/Vue warnings | P1 | Missing key prop, invalid hook call, reactive mutation warning |
| Deprecation warnings | P2 | Deprecated API usage, legacy lifecycle methods |
| `console.log` in production | P3 | Debug logs left in code |

### Step 3: Fake Data Detection ⚠️ REQUIRED

#### 3a. Network Request Inspection

List all XHR/Fetch requests and check for fake data indicators:

```
Tool: mcp__chrome-devtools__list_network_requests
  resourceTypes: ["xhr", "fetch"]
```

Flag as **P0/P1**:
- Requests to `localhost`, `127.0.0.1`, or non-production hosts
- Requests returning hardcoded JSON from local files instead of API
- Failed requests (4xx/5xx) with no error handling in UI
- Requests with mock/stub response headers (e.g., `x-mock: true`)

#### 3b. Runtime Mock Detection

Evaluate script to detect common mock patterns:

```
Tool: mcp__chrome-devtools__evaluate_script
  function: |
    () => {
      const indicators = [];
      // Check for global mock flags
      if (window.__MOCK__ || window.__DEV_MOCK__ || window.useMock) {
        indicators.push('Global mock flag detected: ' + Object.keys(window).filter(k => /mock/i.test(k)).join(', '));
      }
      // Check for MSW (Mock Service Worker)
      if (navigator.serviceWorker) {
        navigator.serviceWorker.getRegistrations().then(regs => {
          const mswReg = regs.find(r => r.active && r.active.scriptURL.includes('mockServiceWorker'));
          if (mswReg) indicators.push('Mock Service Worker (MSW) is active');
        });
      }
      // Check for common placeholder text in body
      const bodyText = document.body.innerText;
      const placeholders = ['Lorem ipsum', 'placeholder', 'test@test.com', 'John Doe', 'Jane Doe', 'foo bar'];
      placeholders.forEach(p => {
        if (bodyText.toLowerCase().includes(p.toLowerCase())) {
          indicators.push('Placeholder text found: "' + p + '"');
        }
      });
      return indicators;
    }
```

Flag non-empty results as P1 (unless user confirmed it's intentional for demo/dev).

### Step 4: Lighthouse Audit

Run Lighthouse for accessibility and best practices:

```
Tool: mcp__chrome-devtools__lighthouse_audit
  device: "desktop"
  mode: "snapshot"
```

Interpret results:

| Category | Score < 50 | Score 50-89 | Score 90+ |
|----------|-----------|-------------|-----------|
| Accessibility | P1 | P2 | Pass |
| Best Practices | P2 | P3 | Pass |
| SEO | P3 | P3 | Pass |

Report specific failed audits, not just scores. Example: "Lighthouse a11y: 3 images missing alt text, 2 form inputs missing labels."

### Step 5: Accessibility Tree Snapshot

Capture the a11y tree to verify semantic structure:

```
Tool: mcp__chrome-devtools__take_snapshot
  verbose: true
```

Check for:
- Interactive elements without accessible names
- Missing landmark regions (`<nav>`, `<main>`, `<footer>`)
- Heading level skips (h1 → h3)
- Images without alt text
- Form inputs without labels

### Step 6: Visual & Responsive Check

#### 6a. Desktop Screenshot

```
Tool: mcp__chrome-devtools__take_screenshot
  fullPage: true
```

Inspect for:
- Layout overflow or broken alignment
- Missing content or blank sections (sign of failed data loading)
- Placeholder images or broken image icons
- Console error overlays

#### 6b. Mobile Viewport

```
Tool: mcp__chrome-devtools__emulate
  viewport: "375x812x3,mobile,touch"
```

```
Tool: mcp__chrome-devtools__take_screenshot
  fullPage: true
```

Check for:
- Horizontal scroll on mobile
- Touch targets too small (< 44x44px)
- Content overflowing viewport
- Missing mobile navigation

#### 6c. Dark Mode (if applicable)

```
Tool: mcp__chrome-devtools__emulate
  colorScheme: "dark"
```

```
Tool: mcp__chrome-devtools__take_screenshot
```

Check for:
- Text invisible on dark background
- Hardcoded colors not respecting theme
- Images/icons not adapted for dark mode

### Step 7: Performance Trace (optional)

Only run if `--verify` includes performance concern or page feels slow:

```
Tool: mcp__chrome-devtools__performance_start_trace
  reload: true
  autoStop: true
```

Key metrics to report:
- **LCP** (Largest Contentful Paint): > 2.5s is P1, > 4s is P0
- **INP** (Interaction to Next Paint): > 200ms is P1, > 500ms is P0
- **CLS** (Cumulative Layout Shift): > 0.1 is P2, > 0.25 is P1

## Output Format

Append page verification results to the main review output:

```markdown
## Page Verification Results

**URL**: [verified URL]
**Lighthouse**: a11y: XX, best-practices: XX, SEO: XX

### Runtime Findings

1. **[Console]** P0 — Uncaught TypeError: Cannot read property 'map' of undefined
   - **Source**: app.js:142
   - **Fix**: Add null check or loading state before rendering list

2. **[Network]** P1 — API request to localhost:8080/api/users
   - **Risk**: Production build pointing to local dev server
   - **Fix**: Use environment-based API URL configuration

3. **[Lighthouse a11y]** P1 — Score 62: 3 images missing alt, 2 inputs missing labels
   - **Fix**: Add descriptive alt text, associate labels with inputs

4. **[Visual]** P2 — Content overflows on mobile viewport (375px)
   - **Fix**: Add responsive breakpoint or overflow handling

### Verification Screenshots
(attached desktop + mobile screenshots)
```
