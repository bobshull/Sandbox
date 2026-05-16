import { el, mount } from '../utils/dom.js';
import {
  getPresets,
  getUserPatterns,
  saveUserPattern,
  deleteUserPattern,
  makeId,
} from '../state/patterns.js';

export class PatternLibrary {
  #host;
  #store;
  #toast;
  #onLoad;

  constructor({ host, store, toast, onLoad }) {
    this.#host = host;
    this.#store = store;
    this.#toast = toast;
    this.#onLoad = onLoad;
    this.render();
    this.#store.on('change', ({ section }) => {
      if (section === 'name' || section === 'load') this.render();
    });
  }

  #loadPattern(p) {
    this.#store.loadPattern(p);
    this.#onLoad?.(p);
    this.#toast.show(`Loaded "${p.name}"`);
  }

  #saveCurrent() {
    const current = this.#store.exportPattern();
    const name = (prompt('Name this pattern', current.name === 'Untitled' ? '' : current.name) || '').trim();
    if (!name) return;
    const saved = { id: makeId(), name, tempo: current.tempo, swing: current.swing, pattern: current.pattern };
    if (saveUserPattern(saved)) {
      this.#store.setPatternName(name);
      this.#toast.show(`Saved "${name}"`, { tone: 'ok' });
      this.render();
    } else {
      this.#toast.show('Could not save (storage unavailable)', { tone: 'warn' });
    }
  }

  #exportJSON() {
    const data = this.#store.exportPattern();
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${(data.name || 'pattern').replace(/[^a-z0-9-_]+/gi, '_')}.json`;
    document.body.append(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    this.#toast.show('Exported pattern JSON');
  }

  #deleteUser(p) {
    if (!confirm(`Delete pattern "${p.name}"?`)) return;
    deleteUserPattern(p.id);
    this.#toast.show(`Deleted "${p.name}"`, { tone: 'warn' });
    this.render();
  }

  #renderList(title, list, { canDelete = false } = {}) {
    if (list.length === 0) {
      return el('div', { class: 'library__section' }, [
        el('h3', { class: 'library__heading' }, title),
        el('p', { class: 'library__empty' }, canDelete
          ? 'No saved patterns yet. Make a beat and hit Save.'
          : 'No patterns to show.'),
      ]);
    }
    return el('div', { class: 'library__section' }, [
      el('h3', { class: 'library__heading' }, title),
      el('ul', { class: 'library__list' }, list.map(p => el('li', { class: 'library__item' }, [
        el('button', {
          type: 'button',
          class: 'library__load',
          onClick: () => this.#loadPattern(p),
        }, [
          el('span', { class: 'library__name' }, p.name),
          el('span', { class: 'library__meta' }, `${p.tempo} BPM`),
        ]),
        canDelete && el('button', {
          type: 'button',
          class: 'library__delete',
          aria: { label: `Delete ${p.name}` },
          onClick: () => this.#deleteUser(p),
        }, '×'),
      ]))),
    ]);
  }

  render() {
    const header = el('header', { class: 'library__header' }, [
      el('h2', { class: 'library__title' }, 'Patterns'),
      el('p', { class: 'library__current' }, `Now: ${this.#store.state.patternName}`),
      el('div', { class: 'library__actions' }, [
        el('button', { type: 'button', class: 'btn btn--primary', onClick: () => this.#saveCurrent() }, 'Save'),
        el('button', { type: 'button', class: 'btn', onClick: () => this.#exportJSON() }, 'Export JSON'),
      ]),
    ]);

    const presets = getPresets();
    const userPatterns = getUserPatterns();

    const layout = el('div', { class: 'library' }, [
      header,
      this.#renderList('Built-in', presets),
      this.#renderList('Saved', userPatterns, { canDelete: true }),
    ]);

    mount(this.#host, layout);
  }
}
