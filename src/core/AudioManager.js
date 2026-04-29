// Web Audio wrapper. For the prototype we synthesize a kick on every beat
// plus a higher tick on every 4th beat. This keeps the project zero-asset.

export class AudioManager {
  constructor() {
    this.ctx = null;
    this.master = null;
    this.musicGain = null;
    this.currentMusic = null;
    this._bufferCache = new Map();
  }

  async init() {
    const AC = window.AudioContext || window.webkitAudioContext;
    this.ctx = new AC();
    this.master = this.ctx.createGain();
    this.master.gain.value = 0.6;
    this.master.connect(this.ctx.destination);
    this.musicGain = this.ctx.createGain();
    this.musicGain.gain.value = 0.85;
    this.musicGain.connect(this.master);
  }

  async resume() {
    if (this.ctx && this.ctx.state === "suspended") {
      await this.ctx.resume();
    }
  }

  // Load and decode an audio file. Cached by URL.
  async loadBuffer(url) {
    if (this._bufferCache.has(url)) return this._bufferCache.get(url);
    const res = await fetch(url);
    if (!res.ok) throw new Error(`Failed to load audio: ${url} (${res.status})`);
    const arr = await res.arrayBuffer();
    const buf = await this.ctx.decodeAudioData(arr);
    this._bufferCache.set(url, buf);
    return buf;
  }

  // Play a decoded buffer at AudioContext time `when`. Returns the source node.
  playBuffer(buffer, when, { offset = 0, volume = 0.85, loop = false } = {}) {
    this.stopMusic();
    const src = this.ctx.createBufferSource();
    src.buffer = buffer;
    src.loop = loop;
    this.musicGain.gain.cancelScheduledValues(this.ctx.currentTime);
    this.musicGain.gain.setValueAtTime(volume, this.ctx.currentTime);
    src.connect(this.musicGain);
    src.start(Math.max(this.ctx.currentTime, when), offset);
    this.currentMusic = src;
    return src;
  }

  fadeOutMusic(duration = 0.6) {
    if (!this.currentMusic) return;
    const now = this.ctx.currentTime;
    this.musicGain.gain.cancelScheduledValues(now);
    this.musicGain.gain.setValueAtTime(this.musicGain.gain.value, now);
    this.musicGain.gain.linearRampToValueAtTime(0.0001, now + duration);
    const src = this.currentMusic;
    setTimeout(() => { try { src.stop(); } catch {} }, duration * 1000 + 80);
    this.currentMusic = null;
  }

  stopMusic() {
    if (this.currentMusic) {
      try { this.currentMusic.stop(); } catch {}
      this.currentMusic = null;
    }
  }

  // Schedule a kick drum at a specific AudioContext time.
  scheduleKick(time, accent = false) {
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = "sine";
    const startFreq = accent ? 180 : 130;
    const endFreq = accent ? 60 : 45;
    osc.frequency.setValueAtTime(startFreq, time);
    osc.frequency.exponentialRampToValueAtTime(endFreq, time + 0.12);
    gain.gain.setValueAtTime(0.0001, time);
    gain.gain.exponentialRampToValueAtTime(accent ? 0.9 : 0.6, time + 0.005);
    gain.gain.exponentialRampToValueAtTime(0.0001, time + 0.18);
    osc.connect(gain).connect(this.master);
    osc.start(time);
    osc.stop(time + 0.22);
  }

  // Schedule a hi-hat-style noise blip.
  scheduleHat(time) {
    const buf = this.ctx.createBuffer(1, 0.05 * this.ctx.sampleRate, this.ctx.sampleRate);
    const data = buf.getChannelData(0);
    for (let i = 0; i < data.length; i++) data[i] = (Math.random() * 2 - 1) * (1 - i / data.length);
    const src = this.ctx.createBufferSource();
    src.buffer = buf;
    const hp = this.ctx.createBiquadFilter();
    hp.type = "highpass";
    hp.frequency.value = 6000;
    const gain = this.ctx.createGain();
    gain.gain.setValueAtTime(0.25, time);
    gain.gain.exponentialRampToValueAtTime(0.0001, time + 0.05);
    src.connect(hp).connect(gain).connect(this.master);
    src.start(time);
  }

  // Quick UI sound effect played immediately.
  blip(freq = 800, duration = 0.08, type = "square", vol = 0.3) {
    const t = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = type;
    osc.frequency.value = freq;
    gain.gain.setValueAtTime(vol, t);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + duration);
    osc.connect(gain).connect(this.master);
    osc.start(t);
    osc.stop(t + duration + 0.02);
  }
}
