class Money {
  const Money._();

  static double round(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}
