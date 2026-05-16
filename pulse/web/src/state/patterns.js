import { readJSON, writeJSON, removeKey } from '../utils/storage.js';
import { PRESETS } from '../data/presets.js';

const USER_KEY = 'user-patterns';

export function getPresets() {
  return PRESETS.map(p => ({ ...p, source: 'preset' }));
}

export function getUserPatterns() {
  const list = readJSON(USER_KEY, []);
  if (!Array.isArray(list)) return [];
  return list.map(p => ({ ...p, source: 'user' }));
}

export function saveUserPattern(pattern) {
  const list = getUserPatterns().map(({ source, ...rest }) => rest);
  const idx = list.findIndex(p => p.id === pattern.id);
  if (idx >= 0) list[idx] = pattern;
  else list.unshift(pattern);
  return writeJSON(USER_KEY, list.slice(0, 50));
}

export function deleteUserPattern(id) {
  const list = getUserPatterns().filter(p => p.id !== id).map(({ source, ...rest }) => rest);
  return writeJSON(USER_KEY, list);
}

export function clearUserPatterns() {
  return removeKey(USER_KEY);
}

export function makeId() {
  return 'p_' + Math.random().toString(36).slice(2, 9) + Date.now().toString(36).slice(-4);
}
