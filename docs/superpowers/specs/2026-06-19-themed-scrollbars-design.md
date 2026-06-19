# Themed Scrollbars — Design

## Goal

Make the main document scrollbar as visible and theme-consistent as the table-of-contents scrollbar.

## Design

Define one set of WebKit scrollbar rules in `Resources/template.html`. The rules apply to the root document scrollbar and nested scroll containers such as the table of contents and raw-source pane. The track uses `--bg`; the thumb is derived from `--text` and `--bg`, with a stronger hover color. Scrolling behavior, dimensions, and macOS scrollbar preferences remain unchanged.

When the source pane is visible, the rendered document and source are peer panes. `#content` owns rendered-document scrolling; `#raw-source` owns source scrolling; the page itself does not scroll. This places each scrollbar at its pane's right edge. A single `_contentScroller()` helper is the source of truth for rendered scrolling, including scroll preservation, source synchronization, TOC highlighting, heading navigation, find navigation, and Vim keys.

The TOC remains independently scrollable. When rendered scrolling changes the active heading, the active TOC link is scrolled with `block: 'nearest'`, moving only enough to keep that link visible rather than recentering the TOC on every update.

## Validation

An XCTest verifies that the bundled template contains shared track, thumb, hover, and corner rules using theme variables. It also verifies that `#content` owns vertical overflow and that rendered navigation no longer targets `window` scrolling. Build and unit tests guard template packaging and application behavior; a long document with its source pane open verifies scrollbar placement and synchronized scrolling visually.
