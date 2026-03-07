const STORAGE_KEY = 'retro-arcade-v1';
const CURRENT_VERSION = 1;
const MAX_SCORES_PER_GAME = 10;
const SAVE_DEBOUNCE_MS = 300;

const DEFAULT_DATA = Object.freeze({
  version: CURRENT_VERSION,
  highScores: Object.freeze({
    snake: Object.freeze([]),
    breakout: Object.freeze([]),
    invaders: Object.freeze([]),
  }),
  settings: Object.freeze({
    masterVolume: 0.7,
    sfxVolume: 1.0,
    musicVolume: 0.5,
    crtEffect: true,
    scanlines: true,
    screenShake: true,
    touchLayout: 'swipe',
  }),
});

function deepClone(obj) {
  return JSON.parse(JSON.stringify(obj));
}

class StorageManager {
  constructor() {
    this._data = null;
    this._saveTimer = null;
  }

  init() {
    this._data = this._load();
  }

  getHighScores(gameId) {
    this._ensureLoaded();
    const scores = this._data.highScores[gameId];
    return scores ? scores.slice() : [];
  }

  addHighScore(gameId, name, score) {
    this._ensureLoaded();
    if (!this._data.highScores[gameId]) {
      this._data.highScores[gameId] = [];
    }
    const list = this._data.highScores[gameId];
    const entry = { name, score, date: new Date().toISOString().slice(0, 10) };

    let rank = list.findIndex(e => score > e.score);
    if (rank === -1) rank = list.length;
    if (rank >= MAX_SCORES_PER_GAME) return null;

    list.splice(rank, 0, entry);
    if (list.length > MAX_SCORES_PER_GAME) list.length = MAX_SCORES_PER_GAME;

    this._scheduleSave();
    return rank + 1;
  }

  isHighScore(gameId, score) {
    this._ensureLoaded();
    const list = this._data.highScores[gameId];
    if (!list || list.length < MAX_SCORES_PER_GAME) return true;
    return score > list[list.length - 1].score;
  }

  getSettings() {
    this._ensureLoaded();
    return Object.assign({}, this._data.settings);
  }

  getSetting(key) {
    this._ensureLoaded();
    return this._data.settings[key];
  }

  setSetting(key, value) {
    this._ensureLoaded();
    this._data.settings[key] = value;
    this._scheduleSave();
  }

  updateSettings(partial) {
    this._ensureLoaded();
    Object.assign(this._data.settings, partial);
    this._scheduleSave();
  }

  resetAll() {
    this._data = deepClone(DEFAULT_DATA);
    this._saveNow();
  }

  _ensureLoaded() {
    if (!this._data) this._data = this._load();
  }

  _load() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return deepClone(DEFAULT_DATA);

      const parsed = JSON.parse(raw);
      if (!parsed || parsed.version !== CURRENT_VERSION) {
        console.warn('[Storage] Version mismatch or invalid data, resetting to defaults');
        return deepClone(DEFAULT_DATA);
      }

      return {
        version: CURRENT_VERSION,
        highScores: parsed.highScores || deepClone(DEFAULT_DATA.highScores),
        settings: Object.assign(deepClone(DEFAULT_DATA.settings), parsed.settings),
      };
    } catch (e) {
      console.warn('[Storage] Failed to load, resetting to defaults:', e.message);
      return deepClone(DEFAULT_DATA);
    }
  }

  _scheduleSave() {
    clearTimeout(this._saveTimer);
    this._saveTimer = setTimeout(() => this._saveNow(), SAVE_DEBOUNCE_MS);
  }

  _saveNow() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(this._data));
    } catch (e) {
      console.warn('[Storage] Failed to save:', e.message);
    }
  }
}

export const storage = new StorageManager();
