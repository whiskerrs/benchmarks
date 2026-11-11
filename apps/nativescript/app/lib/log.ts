let homeReadyLogged = false;

/** Writes `SHOPBENCH home_ready` to the iOS unified log, once per process. */
export function logHomeReady() {
  if (homeReadyLogged) return;
  homeReadyLogged = true;
  if (__APPLE__) {
    SBNative.logHomeReady();
  }
}
