// Called directly from a menu button so the browser's user gesture is retained.
window.loreToggleFullscreen = async () => {
  try {
    if (document.fullscreenElement || document.webkitFullscreenElement) {
      const exit = document.exitFullscreen || document.webkitExitFullscreen;
      if (!exit) return 'unsupported';
      await exit.call(document);
    } else {
      const root = document.documentElement;
      const request = root.requestFullscreen || root.webkitRequestFullscreen;
      if (!request || document.fullscreenEnabled === false) return 'unsupported';
      await request.call(root);
    }
    return 'ok';
  } catch (_) {
    return 'denied';
  }
};
