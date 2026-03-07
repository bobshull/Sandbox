import { ObjectPool } from './pool.js';

const POOL_SIZE = 200;
const TWO_PI = Math.PI * 2;

const DEFAULTS = { x: 0, y: 0, vx: 0, vy: 0, ax: 0, ay: 0, alpha: 1, decay: 0, radius: 2, color: '#ffffff', life: 0, maxLife: 0 };

class Particle {
  constructor() { Object.assign(this, DEFAULTS); }
  reset() { Object.assign(this, DEFAULTS); }
}

export class ParticleSystem {
  constructor() {
    this._pool = new ObjectPool(() => new Particle(), POOL_SIZE);
  }

  emit(x, y, count, options) {
    const speed = options.speed || 50;
    const spread = options.spread || speed;
    const gravity = options.gravity || 0;
    const decay = options.decay || 1;
    const minR = options.minRadius || 1;
    const maxR = options.maxRadius || 3;
    const minLife = options.minLife || 0.3;
    const maxLife = options.maxLife || 1.0;
    const color = options.color || '#ffffff';

    for (let i = 0; i < count; i++) {
      const p = this._pool.acquire();
      const angle = Math.random() * TWO_PI;
      const v = speed + (Math.random() - 0.5) * spread;
      p.x = x;
      p.y = y;
      p.vx = Math.cos(angle) * v;
      p.vy = Math.sin(angle) * v;
      p.ax = 0;
      p.ay = gravity;
      p.radius = minR + Math.random() * (maxR - minR);
      p.life = minLife + Math.random() * (maxLife - minLife);
      p.maxLife = p.life;
      p.alpha = 1;
      p.decay = decay;
      p.color = color;
    }
  }

  emitBurst(x, y, count, options) {
    const speed = options.speed || 80;
    const spread = options.spread || 20;
    const gravity = options.gravity || 0;
    const decay = options.decay || 1;
    const minR = options.minRadius || 1;
    const maxR = options.maxRadius || 3;
    const minLife = options.minLife || 0.3;
    const maxLife = options.maxLife || 1.0;
    const color = options.color || '#ffffff';
    const step = TWO_PI / count;

    for (let i = 0; i < count; i++) {
      const p = this._pool.acquire();
      const angle = step * i;
      const v = speed + (Math.random() - 0.5) * spread;
      p.x = x;
      p.y = y;
      p.vx = Math.cos(angle) * v;
      p.vy = Math.sin(angle) * v;
      p.ax = 0;
      p.ay = gravity;
      p.radius = minR + Math.random() * (maxR - minR);
      p.life = minLife + Math.random() * (maxLife - minLife);
      p.maxLife = p.life;
      p.alpha = 1;
      p.decay = decay;
      p.color = color;
    }
  }

  emitDirectional(x, y, count, angle, spread, options) {
    const speed = options.speed || 60;
    const speedVar = options.speedVariance || 20;
    const gravity = options.gravity || 0;
    const decay = options.decay || 1;
    const minR = options.minRadius || 1;
    const maxR = options.maxRadius || 3;
    const minLife = options.minLife || 0.3;
    const maxLife = options.maxLife || 1.0;
    const color = options.color || '#ffffff';

    for (let i = 0; i < count; i++) {
      const p = this._pool.acquire();
      const a = angle + (Math.random() - 0.5) * spread;
      const v = speed + (Math.random() - 0.5) * speedVar;
      p.x = x;
      p.y = y;
      p.vx = Math.cos(a) * v;
      p.vy = Math.sin(a) * v;
      p.ax = 0;
      p.ay = gravity;
      p.radius = minR + Math.random() * (maxR - minR);
      p.life = minLife + Math.random() * (maxLife - minLife);
      p.maxLife = p.life;
      p.alpha = 1;
      p.decay = decay;
      p.color = color;
    }
  }

  explode(x, y, color) {
    this.emitBurst(x, y, 15, {
      color,
      speed: 120,
      spread: 40,
      decay: 2,
      minRadius: 1,
      maxRadius: 4,
      minLife: 0.2,
      maxLife: 0.5,
      gravity: 50,
    });
  }

  sparkle(x, y, color) {
    this.emit(x, y, 5, {
      color: color || '#ffd455',
      speed: 20,
      spread: 15,
      decay: 1.5,
      minRadius: 1,
      maxRadius: 2,
      minLife: 0.4,
      maxLife: 0.8,
    });
  }

  trail(x, y, color) {
    this.emit(x, y, 1 + Math.round(Math.random()), {
      color,
      speed: 10,
      spread: 10,
      gravity: 30,
      decay: 2,
      minRadius: 1,
      maxRadius: 2,
      minLife: 0.15,
      maxLife: 0.3,
    });
  }

  update(dt) {
    for (const p of this._pool.getActive()) {
      p.vx += p.ax * dt;
      p.vy += p.ay * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      p.alpha = Math.max(0, (p.life / p.maxLife) * (1 / p.decay));
      if (p.life <= 0 || p.alpha <= 0) {
        this._pool.release(p);
      }
    }
  }

  draw(ctx) {
    const saved = ctx.globalAlpha;
    for (const p of this._pool.getActive()) {
      ctx.globalAlpha = p.alpha;
      ctx.fillStyle = p.color;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.radius, 0, TWO_PI);
      ctx.fill();
    }
    ctx.globalAlpha = saved;
  }

  clear() { this._pool.releaseAll(); }
  getActiveCount() { return this._pool.getActiveCount(); }
}
