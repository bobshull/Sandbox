// Built-in preset patterns. Each preset only specifies tracks that have hits;
// missing tracks are filled with an empty row at load time.
// Steps are 16-element boolean arrays.

const row = (...positions) => {
  const r = Array(16).fill(false);
  for (const p of positions) r[p] = true;
  return r;
};

export const PRESETS = [
  {
    id: 'boom-bap',
    name: 'Boom Bap',
    tempo: 88,
    swing: 0.22,
    pattern: {
      kick:  row(0, 6, 10),
      snare: row(4, 12),
      hat:   row(0, 2, 4, 6, 8, 10, 12, 14),
      bass:  row(0, 10),
      perc:  row(7, 15),
    },
  },
  {
    id: 'lofi-shuffle',
    name: 'Lo-Fi Shuffle',
    tempo: 76,
    swing: 0.32,
    pattern: {
      kick:  row(0, 8),
      snare: row(4, 12),
      hat:   row(2, 6, 10, 14),
      clap:  row(12),
      pluck: row(0, 6, 10),
      pad:   row(0),
    },
  },
  {
    id: 'house-pulse',
    name: 'House Pulse',
    tempo: 122,
    swing: 0.05,
    pattern: {
      kick:  row(0, 4, 8, 12),
      clap:  row(4, 12),
      hat:   row(2, 6, 10, 14),
      bass:  row(0, 3, 8, 11),
      perc:  row(7, 15),
    },
  },
  {
    id: 'breakbeat',
    name: 'Breakbeat',
    tempo: 138,
    swing: 0.1,
    pattern: {
      kick:  row(0, 6, 10),
      snare: row(4, 12, 14),
      hat:   row(0, 2, 3, 5, 7, 8, 10, 11, 13, 15),
      bass:  row(0, 8),
    },
  },
  {
    id: 'half-time',
    name: 'Half Time',
    tempo: 70,
    swing: 0.15,
    pattern: {
      kick:  row(0, 7),
      snare: row(8),
      hat:   row(0, 4, 8, 12),
      clap:  row(8),
      pad:   row(0),
      pluck: row(2, 9, 13),
    },
  },
  {
    id: 'empty',
    name: 'Empty',
    tempo: 96,
    swing: 0.18,
    pattern: {},
  },
];
