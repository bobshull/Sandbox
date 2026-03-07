const FONT_PRESETS = Object.freeze({
  title: { family: '"Press Start 2P", monospace', size: 16 },
  body: { family: '"VT323", monospace', size: 24 },
  ui: { family: '"Pixelify Sans", monospace', size: 20 },
  score: { family: '"Press Start 2P", monospace', size: 12 },
});

export function drawText(ctx, text, x, y, options = {}) {
  const preset = FONT_PRESETS[options.font] || FONT_PRESETS.body;
  const scale = options.scale || 1;
  const size = Math.round(preset.size * scale);
  const color = options.color || '#f1f2f6';
  const align = options.align || 'left';
  const baseline = options.baseline || 'top';

  ctx.font = `${size}px ${preset.family}`;
  ctx.fillStyle = color;
  ctx.textAlign = align;
  ctx.textBaseline = baseline;

  if (options.alpha !== undefined) {
    const saved = ctx.globalAlpha;
    ctx.globalAlpha = options.alpha;
    ctx.fillText(text, x, y);
    ctx.globalAlpha = saved;
  } else {
    ctx.fillText(text, x, y);
  }
}

export function drawGlowText(ctx, text, x, y, options = {}) {
  const preset = FONT_PRESETS[options.font] || FONT_PRESETS.body;
  const scale = options.scale || 1;
  const size = Math.round(preset.size * scale);
  const color = options.color || '#f1f2f6';
  const glowColor = options.glowColor || color;
  const align = options.align || 'left';
  const baseline = options.baseline || 'top';

  ctx.font = `${size}px ${preset.family}`;
  ctx.textAlign = align;
  ctx.textBaseline = baseline;

  const saved = ctx.globalAlpha;

  ctx.globalAlpha = 0.3;
  ctx.shadowColor = glowColor;
  ctx.shadowBlur = 20;
  ctx.fillStyle = glowColor;
  ctx.fillText(text, x, y);

  ctx.globalAlpha = 0.6;
  ctx.shadowBlur = 10;
  ctx.fillText(text, x, y);

  ctx.globalAlpha = saved;
  ctx.shadowBlur = 0;
  ctx.shadowColor = 'transparent';
  ctx.fillStyle = color;
  ctx.fillText(text, x, y);
}

export function measureText(ctx, text, font) {
  const preset = FONT_PRESETS[font] || FONT_PRESETS.body;
  ctx.font = `${preset.size}px ${preset.family}`;
  const metrics = ctx.measureText(text);
  return {
    width: metrics.width,
    height: preset.size,
  };
}

export function drawWrappedText(ctx, text, x, y, maxWidth, lineHeight, options = {}) {
  const preset = FONT_PRESETS[options.font] || FONT_PRESETS.body;
  const scale = options.scale || 1;
  const size = Math.round(preset.size * scale);
  const color = options.color || '#f1f2f6';
  const align = options.align || 'left';

  ctx.font = `${size}px ${preset.family}`;
  ctx.fillStyle = color;
  ctx.textAlign = align;
  ctx.textBaseline = 'top';

  const words = text.split(' ');
  let line = '';
  let cy = y;

  for (const word of words) {
    const test = line ? line + ' ' + word : word;
    if (ctx.measureText(test).width > maxWidth && line) {
      ctx.fillText(line, x, cy);
      line = word;
      cy += lineHeight;
    } else {
      line = test;
    }
  }
  if (line) ctx.fillText(line, x, cy);
}
