/// Weight/height unit conversion for the EdgeFuel domain. The calculator
/// always works in kilograms/centimeters internally (master prompt §7.1,
/// "units are converted before entering the engine") — these helpers are the
/// conversion boundary for callers working in imperial units.
library;

const double _kgPerLb = 0.45359237;
const double _cmPerIn = 2.54;

double lbToKg(double pounds) => pounds * _kgPerLb;

double kgToLb(double kg) => kg / _kgPerLb;

double inToCm(double inches) => inches * _cmPerIn;

double cmToIn(double cm) => cm / _cmPerIn;
