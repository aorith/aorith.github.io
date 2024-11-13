// Code block triple-click select all for <pre><code>Code</code></pre>
let clickCount = 0;
let clickTimer = null;

document.addEventListener("click", function (event) {
  clickCount++;

  // Reset click count after a delay
  if (clickTimer) clearTimeout(clickTimer);
  clickTimer = setTimeout(() => {
    clickCount = 0;
  }, 400);

  if (clickCount === 3) {
    clickCount = 0;

    let elem = event.target.closest("pre");
    if (elem) {
      let range = document.createRange();
      range.selectNodeContents(elem);
      let selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
    }
  }
});
