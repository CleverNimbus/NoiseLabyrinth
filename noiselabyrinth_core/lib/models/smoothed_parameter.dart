class SmoothedParameter {
  SmoothedParameter(this.current, this.smoothing) : target = current {
    smoothing = smoothing.clamp(0.0, 1.0);
  }
  double current;
  double target;
  double smoothing;

  void update() {
    current += (target - current) * smoothing;
  }
}
