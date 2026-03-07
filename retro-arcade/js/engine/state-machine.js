export class StateMachine {
  constructor(config) {
    this._initial = config.initial;
    this._current = config.initial;
    this._states = Object.freeze(
      Object.fromEntries(
        Object.entries(config.states).map(
          ([k, v]) => [k, Object.freeze({ transitions: Object.freeze([...v.transitions]) })]
        )
      )
    );
    this._onEnter = {};
    this._onExit = {};
    this._onChange = [];
  }

  getState() {
    return this._current;
  }

  is(state) {
    return this._current === state;
  }

  canTransition(toState) {
    const allowed = this._states[this._current]?.transitions;
    return allowed ? allowed.includes(toState) : false;
  }

  transition(toState) {
    if (!this.canTransition(toState)) {
      throw new Error(`Illegal state transition: ${this._current} → ${toState}`);
    }
    const from = this._current;
    if (this._onExit[from]) this._onExit[from](from);
    this._current = toState;
    if (this._onEnter[toState]) this._onEnter[toState](toState);
    for (const cb of this._onChange) cb(from, toState);
    return toState;
  }

  onEnter(state, callback) {
    this._onEnter[state] = callback;
  }

  onExit(state, callback) {
    this._onExit[state] = callback;
  }

  onChange(callback) {
    this._onChange.push(callback);
  }

  reset() {
    this._current = this._initial;
  }
}
