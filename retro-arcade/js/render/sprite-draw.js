export function drawSprite(ctx, sprite, x, y, scale, color) {
  ctx.fillStyle = color;
  for (let row = 0; row < sprite.length; row++) {
    for (let col = 0; col < sprite[row].length; col++) {
      if (sprite[row][col]) {
        ctx.fillRect(x + col * scale, y + row * scale, scale, scale);
      }
    }
  }
}
