# Themed Scrollbars Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the main document, TOC, and raw-source pane matching, visible theme-aware scrollbars.

**Architecture:** Add shared scrollbar CSS to the bundled HTML template. Verify the contract by reading the real bundled template in an XCTest.

**Tech Stack:** Swift/XCTest, HTML/CSS, WebKit

---

### Task 1: Shared themed scrollbar styling

**Files:**
- Modify: `markdownViewr/Resources/template.html`
- Test: `markdownViewrTests/TemplateScrollbarTests.swift`

- [ ] **Step 1: Write the failing test**

Add an XCTest that loads `template.html` and asserts shared `::-webkit-scrollbar-track`, `::-webkit-scrollbar-thumb`, and hover selectors use `--bg` and `--text`.

- [ ] **Step 2: Run the test to verify it fails**

Run `xcodebuild test -scheme markdownViewr -destination 'platform=macOS' -only-testing:markdownViewrTests/TemplateScrollbarTests` and expect missing-selector assertion failures.

- [ ] **Step 3: Write minimal implementation**

Add shared WebKit scrollbar track and thumb rules near the base CSS in `template.html`, deriving colors from the existing theme variables.

- [ ] **Step 4: Verify**

Run the focused test, the complete test suite, and visually inspect Nord with a long document.

### Task 2: Give the rendered pane its own scroll container

**Files:**
- Modify: `markdownViewr/Resources/template.html:18-47,220-225,420-426,876-1112`
- Test: `markdownViewrTests/TemplateScrollbarTests.swift`

- [ ] **Step 1: Write the failing test**

Extend `TemplateScrollbarTests` to require `body { height: 100vh; overflow: hidden; }`, `#content { overflow-y: auto; }`, a `_contentScroller()` helper, and content-owned scroll listeners and navigation.

- [ ] **Step 2: Run test to verify it fails**

Run `xcodebuild test -scheme markdownViewr -destination 'platform=macOS' -only-testing:markdownViewrTests/TemplateScrollbarTests` and expect failures for the missing content-scroller contract.

- [ ] **Step 3: Implement the pane scroll owner**

Bound the body and all three panes to the viewport. Make `#content` flexible and vertically scrollable. Add `_contentScroller()` and replace root-document reads, `window.scrollTo`/`scrollBy`, and `window` scroll listeners with equivalent operations on that element.

- [ ] **Step 4: Verify behavior**

Run the focused test and full `xcodebuild test -scheme markdownViewr -destination 'platform=macOS'`. Open a long document with TOC and source visible; verify each pane has a scrollbar at its own edge, scroll sync works in both directions, TOC highlighting follows the rendered pane, and Vim/find navigation still scrolls the rendered pane.

### Task 3: Keep the active TOC heading visible

**Files:**
- Modify: `markdownViewr/Resources/template.html:1000-1025`
- Test: `markdownViewrTests/TemplateScrollbarTests.swift`

- [ ] **Step 1: Write the failing test**

Add `testActiveTOCLinkIsKeptVisible`, requiring the active link to call `scrollIntoView` with `block: 'nearest'`.

- [ ] **Step 2: Run test to verify it fails**

Run `xcodebuild test -scheme markdownViewr -destination 'platform=macOS' -only-testing:markdownViewrTests/TemplateScrollbarTests/testActiveTOCLinkIsKeptVisible` and expect the missing nearest-scroll assertion to fail.

- [ ] **Step 3: Implement nearest TOC scrolling**

After assigning the active class in `highlightActiveTOC`, call `activeLink.scrollIntoView({ block: 'nearest' })` so the TOC moves only when needed.

- [ ] **Step 4: Verify behavior**

Run the focused and full suites, then scroll a long rendered document far enough that the active TOC entry would otherwise leave the TOC viewport and confirm it remains visible.
