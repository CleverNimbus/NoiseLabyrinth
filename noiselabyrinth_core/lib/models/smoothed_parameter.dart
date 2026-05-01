class SmoothedParameter {
  double current;
  double target;
  double smoothing;

  SmoothedParameter(this.current, this.smoothing) : target = current {
    smoothing = smoothing.clamp(0.0, 1.0);
  }

  void update() {
    current += (target - current) * smoothing;
  }
}
