import { validateGame } from './game-interface.js';

class GameManifest {
  constructor() {
    this._games = new Map();
  }

  register(game) {
    validateGame(game);
    if (this._games.has(game.id)) {
      throw new Error(`Game already registered: "${game.id}"`);
    }
    this._games.set(game.id, game);
    console.log(`[Manifest] Registered: ${game.id}`);
  }

  getGame(id) {
    return this._games.get(id) || null;
  }

  getAllGames() {
    return Array.from(this._games.values()).map(g => ({
      id: g.id,
      name: g.name,
      description: g.description,
    }));
  }

  getGameIds() {
    return Array.from(this._games.keys());
  }
}

export const gameManifest = new GameManifest();
