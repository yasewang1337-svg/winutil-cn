// Hextra 0.12.3 searches on keyup. Also refresh for paste, touch input and IME
// commits, without replacing its index, rendering or keyboard navigation.
document.addEventListener('DOMContentLoaded', () => {
  const indexReady = () => window.pageIndex && window.sectionIndex &&
    typeof window.pageIndex.contain === 'function' && window.pageIndex.contain(1);
  // The pinned theme adds documents synchronously after fetching its data,
  // starting at ID 1. An index object alone does not mean data has loaded.
  for (const input of document.querySelectorAll('.hextra-search-input')) {
    let composing = false;
    let timer;
    let deadline = 0;
    const status = input.closest('.hextra-search-wrapper').querySelector('.hextra-search-status');

    const refresh = () => {
      if (composing || document.activeElement !== input) return;
      if (!input.value || indexReady()) {
        input.dispatchEvent(new KeyboardEvent('keyup', {key: 'Unidentified', bubbles: true}));
        return;
      }
      if (Date.now() >= deadline) {
        if (status) status.textContent = '搜索索引未能加载，请刷新页面后再试。';
        return;
      }
      if (status) status.textContent = '正在准备搜索…';
      timer = setTimeout(refresh, 100);
    };
    const schedule = () => {
      clearTimeout(timer);
      deadline = Date.now() + 15000;
      timer = setTimeout(refresh, 100);
    };

    input.addEventListener('input', event => {
      if (!composing && !event.isComposing) schedule();
    });
    input.addEventListener('compositionstart', () => {
      composing = true;
      clearTimeout(timer);
    });
    input.addEventListener('compositionend', () => {
      composing = false;
      schedule();
    });
    input.addEventListener('keyup', event => {
      if (composing || event.isComposing) {
        event.stopImmediatePropagation();
      } else if (input.value && !indexReady()) {
        event.stopImmediatePropagation();
        schedule();
      }
    }, true);
    input.addEventListener('blur', () => clearTimeout(timer));
  }
});
