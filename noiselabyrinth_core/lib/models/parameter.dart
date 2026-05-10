class Parameter {
  Parameter(this.baseValue) : finalValue = baseValue;
  double baseValue;
  double modulationValue = 0;
  double finalValue;

  void update() {
    finalValue = baseValue + modulationValue;
    modulationValue = 0.0; // reset per block
  }
}
