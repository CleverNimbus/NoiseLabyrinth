class Parameter {
  double baseValue;
  double modulationValue = 0.0;
  double finalValue;

  Parameter(this.baseValue) : finalValue = baseValue;

  void update() {
    finalValue = baseValue + modulationValue;
    modulationValue = 0.0; // reset per block
  }
}
