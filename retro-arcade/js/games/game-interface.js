export function createGameContext(managers) {
  return Object.freeze({
    canvas: Object.freeze({
      width: managers.viewport.getLogicalSize().width,
      height: managers.viewport.getLogicalSize().height,
    }),
    audio: managers.audio,
    particles: managers.particles,
    storage: managers.storage,
    effects: managers.effects,
    renderer: managers.renderer,
    input: managers.input,
  });
}

const REQUIRED_PROPS = ['id', 'name', 'description'];
const REQUIRED_METHODS = ['init', 'update', 'render', 'destroy', 'setState', 'getScore', 'getState'];

export function validateGame(game) {
  for (const prop of REQUIRED_PROPS) {
    if (typeof game[prop] !== 'string' || game[prop].length === 0) {
      throw new Error(`Game missing required string property: "${prop}"`);
    }
  }
  for (const method of REQUIRED_METHODS) {
    if (typeof game[method] !== 'function') {
      throw new Error(`Game "${game.id || '?'}" missing required method: "${method}"`);
    }
  }
}
