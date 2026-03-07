const _circleRectResult = { hit: false, side: null };
const _gridCell = { col: 0, row: 0 };
const _gridCells = [];

export function rectIntersects(a, b) {
  return a.x < b.x + b.w &&
    a.x + a.w > b.x &&
    a.y < b.y + b.h &&
    a.y + a.h > b.y;
}

export function circleIntersects(a, b) {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  const radii = a.r + b.r;
  return dx * dx + dy * dy <= radii * radii;
}

export function circleRectIntersects(circle, rect) {
  const closestX = Math.max(rect.x, Math.min(circle.x, rect.x + rect.w));
  const closestY = Math.max(rect.y, Math.min(circle.y, rect.y + rect.h));
  const dx = circle.x - closestX;
  const dy = circle.y - closestY;
  const hit = dx * dx + dy * dy <= circle.r * circle.r;

  _circleRectResult.hit = hit;
  _circleRectResult.side = null;

  if (hit) {
    const overlapLeft = (circle.x + circle.r) - rect.x;
    const overlapRight = (rect.x + rect.w) - (circle.x - circle.r);
    const overlapTop = (circle.y + circle.r) - rect.y;
    const overlapBottom = (rect.y + rect.h) - (circle.y - circle.r);
    const minOverlap = Math.min(overlapLeft, overlapRight, overlapTop, overlapBottom);

    if (minOverlap === overlapLeft) _circleRectResult.side = 'left';
    else if (minOverlap === overlapRight) _circleRectResult.side = 'right';
    else if (minOverlap === overlapTop) _circleRectResult.side = 'top';
    else _circleRectResult.side = 'bottom';
  }

  return _circleRectResult;
}

export function pointInRect(px, py, rect) {
  return px >= rect.x && px <= rect.x + rect.w &&
    py >= rect.y && py <= rect.y + rect.h;
}

export function gridCellAt(x, y, cellSize) {
  _gridCell.col = Math.floor(x / cellSize);
  _gridCell.row = Math.floor(y / cellSize);
  return _gridCell;
}

export function gridCellsInRect(rect, cellSize) {
  const startCol = Math.floor(rect.x / cellSize);
  const endCol = Math.floor((rect.x + rect.w - 1) / cellSize);
  const startRow = Math.floor(rect.y / cellSize);
  const endRow = Math.floor((rect.y + rect.h - 1) / cellSize);

  _gridCells.length = 0;
  for (let row = startRow; row <= endRow; row++) {
    for (let col = startCol; col <= endCol; col++) {
      _gridCells.push({ col, row });
    }
  }
  return _gridCells;
}
