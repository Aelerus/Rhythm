// Web Audio wrapper. For the prototype we synthesize a kick on every beat
// plus a higher tick on every 4th beat. This keeps the project zero-asset.

export class AudioManager {
  constructor() {
    this.ctx = null;
    this.master = null;
  }

  async init() {
    const AC = window.AudioContext || window.webkitAudioContext;
    this.ctx = new AC();
    this.master = this.ctx.createGain();
    this.master.gain.value = 0.6;
    this.master.connect(this.ctx.destination);
  }

  async resume() {
    if (this.ctx && this.ctx.state === "suspended") {
      await this.ctx.resume();
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
