import { el } from '../utils/dom.js';

export class Toast {
  #root;

  constructor(root) {
    this.#root = root;
  }

  show(message, { duration = 2400, tone = 'info' } = {}) {
    const node = el('div', { class: `toast toast--${tone}` }, message);
    this.#root.append(node);
    requestAnimationFrame(() => node.classList.add('toast--in'));
    setTimeout(() => {
      node.classList.remove('toast--in');
      node.classList.add('toast--out');
      setTimeout(() => node.remove(), 300);
    }, duration);
  }
}
