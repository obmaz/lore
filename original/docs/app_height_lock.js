// Keep browser chrome and keyboard height changes out of the game layout.
// Flutter observes this host element instead of the changing window viewport.
(() => {
  const mobile = window.matchMedia('(hover: none) and (pointer: coarse)').matches;
  if (!mobile) return;

  let width = window.innerWidth;
  let rotationTimer;
  const lockHeight = () => {
    if (window.innerHeight > 0) {
      document.documentElement.style.setProperty(
        '--app-height', `${window.innerHeight}px`,
      );
    }
  };
  const settleRotation = () => {
    window.clearTimeout(rotationTimer);
    rotationTimer = window.setTimeout(lockHeight, 250);
  };

  lockHeight();
  window.addEventListener('resize', () => {
    // A height-only resize is normally the address bar or onscreen keyboard.
    if (window.innerWidth === width) return;
    width = window.innerWidth;
    lockHeight();
    settleRotation();
  });
  window.addEventListener('orientationchange', settleRotation);
  const fullscreenChanged = () => {
    lockHeight();
    settleRotation();
  };
  document.addEventListener('fullscreenchange', fullscreenChanged);
  document.addEventListener('webkitfullscreenchange', fullscreenChanged);
})();
