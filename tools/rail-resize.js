/* tools/rail-resize.js -- make the TOC rail of book.html resizable.
 *
 * Delivered by build-book-html.sh, which wraps this file in a <script> element
 * and inlines it via pandoc's --include-after-body, so the published book.html
 * stays self-contained (no external request, works offline).
 *
 * Each chapter is a grid (tools/style.css .chapter): rail | gutter | text.
 * At load this script drops a <div class="rail-handle"> into every chapter's
 * gutter column.  Dragging any handle rewrites the --rail custom property on
 * <html>, so every chapter's rail resizes together and the text reflows live;
 * the width is saved to localStorage and restored on the next visit.
 * Double-clicking a handle resets to the stylesheet default.  Without JS the
 * handle never appears and the fixed-width layout is unchanged.
 */
(function () {
  var root = document.documentElement;
  var KEY = 'book-rail-width';
  var MIN = 160; /* px: still fits "Contents" and short entries */
  function maxWidth() { return Math.max(MIN, window.innerWidth * 0.6); }
  function apply(px) { root.style.setProperty('--rail', px + 'px'); }

  try {
    var saved = parseFloat(localStorage.getItem(KEY));
    if (saved > 0) apply(Math.min(maxWidth(), Math.max(MIN, saved)));
  } catch (e) { /* storage blocked: the default width is fine */ }

  Array.prototype.forEach.call(document.querySelectorAll('.chapter'), function (ch) {
    var body = ch.querySelector(':scope > .chapter-body');
    if (!body) return;
    var handle = document.createElement('div');
    handle.className = 'rail-handle';
    handle.title = 'Drag to resize the Contents rail; double-click to reset';
    ch.insertBefore(handle, body);

    handle.addEventListener('pointerdown', function (e) {
      if (e.button !== 0) return;
      e.preventDefault();
      handle.setPointerCapture(e.pointerId);
      /* The rail's current width in px is the grid's first column. */
      var startW = parseFloat(getComputedStyle(ch).gridTemplateColumns);
      var startX = e.clientX;
      var width = startW;
      root.classList.add('rail-dragging');
      function move(ev) {
        width = Math.min(maxWidth(), Math.max(MIN, startW + ev.clientX - startX));
        apply(width);
      }
      function up() {
        handle.removeEventListener('pointermove', move);
        handle.removeEventListener('pointerup', up);
        handle.removeEventListener('pointercancel', up);
        root.classList.remove('rail-dragging');
        try { localStorage.setItem(KEY, String(Math.round(width))); } catch (err) { /* ignore */ }
      }
      handle.addEventListener('pointermove', move);
      handle.addEventListener('pointerup', up);
      handle.addEventListener('pointercancel', up);
    });

    handle.addEventListener('dblclick', function () {
      root.style.removeProperty('--rail');
      try { localStorage.removeItem(KEY); } catch (err) { /* ignore */ }
    });
  });
})();
