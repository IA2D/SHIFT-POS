class PosSettings {
  const PosSettings({
    required this.restaurantNameAr,
    required this.currencySymbol,
    required this.taxRate,
    required this.serviceRate,
    required this.deliveryFee,
  });

  final String restaurantNameAr;
  final String currencySymbol;
  final double taxRate;
  final double serviceRate;
  final double deliveryFee;
}
