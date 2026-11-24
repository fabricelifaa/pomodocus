// Generates Pomodocus' own Lottie animations and end-of-session chime.
// Usage: node tool/generate_assets.js
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const hex = (h) => {
  const n = parseInt(h.slice(1), 16);
  return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255, 1];
};
const CORAL = hex('#F2553D');
const TEAL = hex('#23A58C');
const AMBER = hex('#F5B83D');
const WHITE = [1, 1, 1, 1];

const st = (k) => ({ a: 0, k });
const EASE_OUT = { o: { x: [0.2], y: [0] }, i: { x: [0.2], y: [1] } };
const EASE_IO = { o: { x: [0.45], y: [0] }, i: { x: [0.55], y: [1] } };
// keyframes: [[t, value], ...]
const anim = (frames, ease = EASE_OUT) => ({
  a: 1,
  k: frames.map(([t, s], idx) =>
    idx < frames.length - 1
      ? { t, s: Array.isArray(s) ? s : [s], ...ease }
      : { t, s: Array.isArray(s) ? s : [s] },
  ),
});

const tr = (o = {}) => ({
  ty: 'tr',
  p: o.p || st([0, 0]),
  a: o.a || st([0, 0]),
  s: o.s || st([100, 100]),
  r: o.r || st(0),
  o: o.o || st(100),
  sk: st(0),
  sa: st(0),
});
const fill = (c) => ({ ty: 'fl', c: st(c), o: st(100), r: 1 });
const stroke = (c, w) => ({ ty: 'st', c: st(c), o: st(100), w: st(w), lc: 2, lj: 2 });
const ellipse = (w, h = w, p = [0, 0]) => ({ ty: 'el', d: 1, p: st(p), s: st([w, h]) });
const rect = (w, h, r, p = [0, 0]) => ({ ty: 'rc', d: 1, p: st(p), s: st([w, h]), r: st(r) });
const group = (items, t = {}) => ({ ty: 'gr', it: [...items, tr(t)] });

// Path from absolute points with optional quadratic control points.
// segs: [{to:[x,y], q:[x,y]?}], start [x,y]
function quadPath(start, segs) {
  const v = [start];
  const i = [[0, 0]];
  const o = [];
  let prev = start;
  for (const s of segs) {
    if (s.q) {
      const c1 = [prev[0] + (2 / 3) * (s.q[0] - prev[0]), prev[1] + (2 / 3) * (s.q[1] - prev[1])];
      const c2 = [s.to[0] + (2 / 3) * (s.q[0] - s.to[0]), s.to[1] + (2 / 3) * (s.q[1] - s.to[1])];
      o.push([c1[0] - prev[0], c1[1] - prev[1]]);
      v.push(s.to);
      i.push([c2[0] - s.to[0], c2[1] - s.to[1]]);
    } else {
      o.push([0, 0]);
      v.push(s.to);
      i.push([0, 0]);
    }
    prev = s.to;
  }
  // Closed: last vertex equals the first → merge.
  const last = v.pop();
  const lastIn = i.pop();
  i[0] = lastIn;
  void last;
  return { ty: 'sh', d: 1, ks: st({ i, o, v, c: true }) };
}

const layer = (ind, nm, shapes, ks, ip, op) => ({
  ddd: 0,
  ind,
  ty: 4,
  nm,
  sr: 1,
  ks: {
    o: ks.o || st(100),
    r: ks.r || st(0),
    p: ks.p || st([0, 0, 0]),
    a: ks.a || st([0, 0, 0]),
    s: ks.s || st([100, 100, 100]),
  },
  ao: 0,
  shapes,
  ip,
  op,
  st: 0,
  bm: 0,
});

const comp = (nm, w, h, op, layers) => ({
  v: '5.7.4',
  fr: 60,
  ip: 0,
  op,
  w,
  h,
  nm,
  ddd: 0,
  assets: [],
  layers,
});

// ---- Tomato drawn in logo coordinates (centre of fruit = origin) --------
const ox = 128, oy = 146;
const L = (x, y) => [x - ox, y - oy];
const leafShape = quadPath(L(134, 54), [
  { to: L(200, 28), q: L(148, 16) },
  { to: L(134, 54), q: L(184, 68) },
]);
const tomatoShapes = (handColor) => [
  group([leafShape, fill(TEAL)]),
  group([rect(20, 46, 10, L(128, 45)), fill(TEAL)]),
  group([rect(22, 76, 11, L(128, 121)), fill(handColor)]),
  group([ellipse(180), fill(CORAL)]),
];

// ---- 1. Celebration: rings + particles burst (end of a pomodoro) --------
function celebrate() {
  const W = 400, C = 200, OP = 90;
  const layers = [];
  let ind = 1;
  const colors = [CORAL, TEAL, AMBER];
  const N = 14;
  for (let k = 0; k < N; k++) {
    const a = (k / N) * Math.PI * 2 - Math.PI / 2;
    const dist = k % 2 ? 150 : 120;
    const delay = (k % 3) * 2;
    const size = k % 2 ? 12 : 16;
    layers.push(
      layer(
        ind++,
        `p${k}`,
        [group([ellipse(size), fill(colors[k % 3])])],
        {
          p: anim([
            [delay, [C + Math.cos(a) * 40, C + Math.sin(a) * 40, 0]],
            [delay + 46, [C + Math.cos(a) * dist, C + Math.sin(a) * dist, 0]],
          ]),
          s: anim([
            [delay, [40, 40, 100]],
            [delay + 10, [110, 110, 100]],
            [delay + 56, [20, 20, 100]],
          ]),
          o: anim([
            [delay, 0],
            [delay + 6, 100],
            [delay + 40, 100],
            [delay + 60, 0],
          ]),
        },
        0,
        OP,
      ),
    );
  }
  for (const [color, delay, w] of [
    [CORAL, 0, 10],
    [TEAL, 8, 6],
  ]) {
    layers.push(
      layer(
        ind++,
        'ring',
        [group([ellipse(200), stroke(color, w)])],
        {
          p: st([C, C, 0]),
          s: anim([
            [delay, [40, 40, 100]],
            [delay + 50, [165, 165, 100]],
          ]),
          o: anim([
            [delay, 90],
            [delay + 50, 0],
          ]),
        },
        0,
        OP,
      ),
    );
  }
  return comp('celebrate', W, W, OP, layers);
}

// ---- 2. Empty state: tomato gently floating, leaf swaying -----------------
function emptyTomato() {
  const W = 220, OP = 180;
  const shadow = layer(
    2,
    'shadow',
    [group([ellipse(110, 16), fill([0, 0, 0, 1])])],
    {
      p: st([110, 196, 0]),
      o: st(10),
      s: anim(
        [
          [0, [100, 100, 100]],
          [90, [78, 78, 100]],
          [180, [100, 100, 100]],
        ],
        EASE_IO,
      ),
    },
    0,
    OP,
  );
  const tomato = layer(
    1,
    'tomato',
    tomatoShapes(WHITE),
    {
      p: anim(
        [
          [0, [110, 118, 0]],
          [90, [110, 104, 0]],
          [180, [110, 118, 0]],
        ],
        EASE_IO,
      ),
      r: anim(
        [
          [0, -3],
          [90, 3],
          [180, -3],
        ],
        EASE_IO,
      ),
      s: st([62, 62, 100]),
    },
    0,
    OP,
  );
  return comp('empty_tomato', W, W, OP, [tomato, shadow]);
}

// ---- 3. Splash: logo reveal (fruit pops, hand spins to 12, stem + leaf grow)
// Ease-out-back, i.e. CSS cubic-bezier(0.34, 1.56, 0.64, 1).
const EASE_BACK = { o: { x: [0.34], y: [1.56] }, i: { x: [0.64], y: [1] } };
function logoReveal() {
  const W = 400, OP = 120;
  const C = [200, 214, 0];
  const PAPER = hex('#FBF7F3');
  const body = layer(
    5,
    'body',
    [group([ellipse(180), fill(CORAL)])],
    {
      p: st(C),
      s: anim([
        [0, [0, 0, 100]],
        [16, [112, 112, 100]],
        [24, [96, 96, 100]],
        [30, [100, 100, 100]],
      ]),
    },
    0,
    OP,
  );
  const child = (ind, nm, shapes, ks) => ({ ...layer(ind, nm, shapes, ks, 0, OP), parent: 5 });
  const hand = child(1, 'hand', [group([rect(22, 76, 11, L(128, 121)), fill(PAPER)])], {
    r: anim([
      [16, -300],
      [58, 0],
    ]),
    o: anim([
      [14, 0],
      [18, 100],
    ]),
  });
  const stemBase = L(128, 66);
  const stem = child(3, 'stem', [group([rect(20, 46, 10, L(128, 45)), fill(TEAL)])], {
    a: st([...stemBase, 0]),
    p: st([...stemBase, 0]),
    s: anim(
      [
        [26, [100, 0, 100]],
        [42, [100, 100, 100]],
      ],
      EASE_BACK,
    ),
  });
  const leafBase = L(136, 54);
  const leaf = child(2, 'leaf', [group([leafShape, fill(TEAL)])], {
    a: st([...leafBase, 0]),
    p: st([...leafBase, 0]),
    s: anim(
      [
        [34, [0, 0, 100]],
        [56, [100, 100, 100]],
      ],
      EASE_BACK,
    ),
    r: anim([
      [34, -40],
      [60, 0],
    ]),
  });
  const ring = (ind, color, delay, w) =>
    layer(
      ind,
      'ring',
      [group([ellipse(200), stroke(color, w)])],
      {
        p: st(C),
        s: anim([
          [delay, [70, 70, 100]],
          [delay + 44, [185, 185, 100]],
        ]),
        o: anim([
          [delay, 0],
          [delay + 4, 55],
          [delay + 44, 0],
        ]),
      },
      0,
      OP,
    );
  return comp('logo_reveal', W, W, OP, [hand, leaf, stem, body, ring(6, CORAL, 10, 6), ring(7, TEAL, 20, 4)]);
}

// ---- Ticks for the full-screen clock (one per second) ----------------------
function wav(data, rate, gain) {
  const n = data.length;
  const buf = Buffer.alloc(44 + n * 2);
  buf.write('RIFF', 0);
  buf.writeUInt32LE(36 + n * 2, 4);
  buf.write('WAVEfmt ', 8);
  buf.writeUInt32LE(16, 16);
  buf.writeUInt16LE(1, 20);
  buf.writeUInt16LE(1, 22);
  buf.writeUInt32LE(rate, 24);
  buf.writeUInt32LE(rate * 2, 28);
  buf.writeUInt16LE(2, 32);
  buf.writeUInt16LE(16, 34);
  buf.write('data', 36);
  buf.writeUInt32LE(n * 2, 40);
  for (let i = 0; i < n; i++) {
    const v = Math.max(-1, Math.min(1, data[i] * gain));
    buf.writeInt16LE(Math.round(v * 32767), 44 + i * 2);
  }
  return buf;
}

// Digital clock: a short, soft electronic blip.
function tickDigital() {
  const rate = 44100, n = Math.floor(rate * 0.07);
  const d = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const t = i / rate;
    const env = Math.min(1, t / 0.0015) * Math.exp(-t * 85);
    d[i] = env * (Math.sin(2 * Math.PI * 1950 * t) + 0.25 * Math.sin(2 * Math.PI * 3900 * t) * Math.exp(-t * 120));
  }
  return wav(d, rate, 0.32);
}

// Flip clock: a "flap" — the card swishes through the air, then slaps down
// on the one below (papery, muted; no sharp click). Variants:
//   1 card       : short swish + flat slap + tiny bounce (default)
//   2 muted      : lower, softer, like a heavy card
//   3 rattle     : 3 quick flaps, like a station departure board
const FLAP_VARIANTS = {
  1: { swish: [0.028, 2300, 0.7, 0.35], slaps: [[0.026, 1, 1300]], body: 240, bounce: 0.28 },
  2: { swish: [0.022, 1500, 0.8, 0.25], slaps: [[0.02, 1, 750]], body: 170, bounce: 0 },
  3: {
    swish: [0.018, 2600, 0.7, 0.2],
    slaps: [
      [0.012, 0.75, 1700],
      [0.04, 0.85, 1500],
      [0.068, 1, 1300],
    ],
    body: 230,
    bounce: 0.18,
  },
};

function tickFlip(variant = 1) {
  const v = FLAP_VARIANTS[variant];
  const rate = 44100, n = Math.floor(rate * 0.16);
  const d = new Float32Array(n);
  let seed = 11;
  const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647) * 2 - 1;
  // RBJ band-pass (0 dB peak), one instance per call.
  const bandpass = (f, q) => {
    const w = (2 * Math.PI * f) / rate, alpha = Math.sin(w) / (2 * q), a0 = 1 + alpha;
    const b0 = alpha / a0, b2 = -alpha / a0, a1 = (-2 * Math.cos(w)) / a0, a2 = (1 - alpha) / a0;
    let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
    return (x) => {
      const y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2;
      x2 = x1; x1 = x; y2 = y1; y1 = y;
      return y;
    };
  };
  // "fl": airy swish, swelling then cut by the slap.
  const [sd, sf, sq, sa] = v.swish;
  const bp = bandpass(sf, sq);
  for (let i = 0; i < Math.floor(sd * rate); i++) {
    const p = i / (sd * rate);
    d[i] += bp(rnd()) * sa * Math.sin(Math.PI * Math.pow(p, 0.7)) * 3;
  }
  // "ap": card hitting card — filtered noise burst + a short, low body.
  const slap = (t0, amp, f) => {
    const s0 = Math.floor(t0 * rate), f1 = bandpass(f, 1.1), f2 = bandpass(f * 2.3, 1.6);
    for (let i = s0; i < n; i++) {
      const t = (i - s0) / rate;
      const env = Math.min(1, t / 0.0012) * Math.exp(-t * 95);
      const x = rnd();
      d[i] +=
        amp *
        (env * (f1(x) * 3.2 + f2(x) * 1.4) +
          0.45 * Math.sin(2 * Math.PI * v.body * t) * Math.exp(-t * 70) * Math.min(1, t / 0.002));
    }
  };
  for (const [t0, a, f] of v.slaps) slap(t0, a, f);
  if (v.bounce) slap(v.slaps[v.slaps.length - 1][0] + 0.034, v.bounce, v.slaps[0][2] * 1.2);
  // Normalise to a comfortable peak.
  let pk = 0;
  for (const x of d) pk = Math.max(pk, Math.abs(x));
  return wav(d, rate, 0.62 / pk);
}

// ---- Chime: two soft bell notes, generated as 16-bit PCM WAV ---------------
function chime() {
  const rate = 44100, dur = 1.6;
  const n = Math.floor(rate * dur);
  const data = new Float32Array(n);
  const notes = [
    [659.25, 0.0],
    [987.77, 0.18],
  ];
  for (const [f, t0] of notes) {
    const s0 = Math.floor(t0 * rate);
    for (let i = s0; i < n; i++) {
      const t = (i - s0) / rate;
      const env = Math.min(1, t / 0.008) * Math.exp(-t * 3.2);
      data[i] +=
        env *
        (0.6 * Math.sin(2 * Math.PI * f * t) +
          0.22 * Math.sin(2 * Math.PI * f * 2 * t) * Math.exp(-t * 4) +
          0.08 * Math.sin(2 * Math.PI * f * 3.01 * t) * Math.exp(-t * 6));
    }
  }
  const buf = Buffer.alloc(44 + n * 2);
  buf.write('RIFF', 0);
  buf.writeUInt32LE(36 + n * 2, 4);
  buf.write('WAVEfmt ', 8);
  buf.writeUInt32LE(16, 16);
  buf.writeUInt16LE(1, 20);
  buf.writeUInt16LE(1, 22);
  buf.writeUInt32LE(rate, 24);
  buf.writeUInt32LE(rate * 2, 28);
  buf.writeUInt16LE(2, 32);
  buf.writeUInt16LE(16, 34);
  buf.write('data', 36);
  buf.writeUInt32LE(n * 2, 40);
  for (let i = 0; i < n; i++) {
    const v = Math.max(-1, Math.min(1, data[i] * 0.55));
    buf.writeInt16LE(Math.round(v * 32767), 44 + i * 2);
  }
  return buf;
}

fs.mkdirSync(path.join(root, 'assets/lottie'), { recursive: true });
fs.mkdirSync(path.join(root, 'assets/sounds'), { recursive: true });
fs.writeFileSync(path.join(root, 'assets/lottie/celebrate.json'), JSON.stringify(celebrate()));
fs.writeFileSync(path.join(root, 'assets/lottie/empty_tomato.json'), JSON.stringify(emptyTomato()));
fs.writeFileSync(path.join(root, 'assets/lottie/logo_reveal.json'), JSON.stringify(logoReveal()));
fs.writeFileSync(path.join(root, 'assets/sounds/chime.wav'), chime());
fs.writeFileSync(path.join(root, 'assets/sounds/tick_digital.wav'), tickDigital());
// FLAP_VARIANT=2 node tool/generate_assets.js  → use another flip sound.
fs.writeFileSync(
  path.join(root, 'assets/sounds/tick_flip.wav'),
  tickFlip(Number(process.env.FLAP_VARIANT) || 1),
);
// Previews of every variant, to compare by ear (not bundled in the app).
if (process.env.FLAP_PREVIEW) {
  fs.mkdirSync(process.env.FLAP_PREVIEW, { recursive: true });
  for (const k of Object.keys(FLAP_VARIANTS)) {
    fs.writeFileSync(path.join(process.env.FLAP_PREVIEW, `flap-${k}.wav`), tickFlip(Number(k)));
  }
}
console.log('assets generated');
