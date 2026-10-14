/* EPUB-only adapter. Not included or executed in the web reader or studio. */
(() => {
  'use strict';
  window.novelEpubStorage = {
    get: key => localStorage.getItem(key),
    set: (key,value) => localStorage.setItem(key,value),
    remove: key => localStorage.removeItem(key)
  };
})();
