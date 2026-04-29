// Central beat tracker. Single source of truth for timing.
// Uses AudioContext.currentTime for sample-accurate scheduling.

export class BeatClock {
  constructor(audioCtx) {
    this.ctx = audioCtx;
    this.bpm = 120;
    this.beatInterval = 60 / this.bpm; // seconds
    this.startTime = 0;
    this.running = false;
    this.lastBeatIndex = -1;
    this.listeners = new Set();
  }

  setBPM(bpm) {
    this.bpm = bpm;
    this.beatInterval = 60 / bpm;
  }

  start(startTime = null) {
    this.startTime = startTime != null ? startTime : this.ctx.currentTime;
    this.lastBeatIndex = -1;
    this.running = true;
  }

  stop() {
    this.running = false;
  }

  // Continuous beat position (e.g. 5.42 = 42% past beat 5)
  get beatPosition() {
    if (!this.running) return 0;
    return (this.ctx.currentTime - this.startTime) / this.beatInterval;
  }

  // Seconds since song start
  get songTime() {
    if (!this.running) return 0;
    return this.ctx.currentTime - this.startTime;
  }

  // Time of beat N (in AudioContext seconds)
  beatTime(beatIndex) {
    return this.startTime + beatIndex * this.beatInterval;
  }

  on(fn) { this.listeners.add(fn); return () => this.listeners.delete(fn); }

  // Called every frame. Fires beat events for any beats that just passed.
  tick() {
    if (!this.running) return;
    const pos = this.beatPosition;
    const currentBeat = Math.floor(pos);
    while (this.lastBeatIndex < currentBeat) {
      this.lastBeatIndex++;
      const beatIdx = this.lastBeatIndex;
      for (const fn of this.listeners) fn(beatIdx);
    }
  }
}
