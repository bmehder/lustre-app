export function randomUUID() {
  try {
    return globalThis.crypto.randomUUID();
  } catch {
    return null;
  }
}
