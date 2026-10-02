/// Kroppsvikt per dag och användarens inställningar.
library;

/// En vägning. En per kalenderdag; senaste skrivningen vinner (sync.dart).
class BodyweightEntry {
  const BodyweightEntry({required this.date, required this.kg});

  /// Kalenderdag `YYYY-MM-DD` (användarens lokala dag).
  final String date;
  final double kg;
}

enum WeightUnit { kg, lbs }

enum TempUnit { celsius, fahrenheit }

/// Synkade inställningar. Allt lagras metriskt — enheterna styr bara visning.
class UserSettings {
  const UserSettings({
    this.weightUnit = WeightUnit.kg,
    this.tempUnit = TempUnit.celsius,
    this.restTimerEnabled = false,
    this.restTimerSecs = 120,
    this.weightGoalKg,
    this.ambientEffects = true,
  });

  final WeightUnit weightUnit;
  final TempUnit tempUnit;
  final bool restTimerEnabled;
  final int restTimerSecs;

  /// Null = inget viktmål.
  final double? weightGoalKg;

  /// Rörliga bakgrunder (av för prestanda eller minskad rörelse).
  final bool ambientEffects;
}
