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
    this.finishNote = true,
    this.restWakeScreen = true,
    this.workoutTourSeen = false,
    this.appBuild,
  });

  final WeightUnit weightUnit;
  final TempUnit tempUnit;
  final bool restTimerEnabled;
  final int restTimerSecs;

  /// Null = inget viktmål.
  final double? weightGoalKg;

  /// Rörliga bakgrunder (av för prestanda eller minskad rörelse).
  final bool ambientEffects;

  /// "How did it feel?" vid FINISH SESSION (Settings → Training).
  final bool finishNote;

  /// Vilotimerns signal tänder skärmen (helskärmsnotis).
  final bool restWakeScreen;

  /// Rundturen i passvyn (LOG / DONE / ⋮) är visad — en gång, på alla enheter.
  final bool workoutTourSeen;

  /// Senaste bygget som körts ("DEV · build 68") — adminsidan visar det.
  final String? appBuild;

  /// [clearGoal] = ta bort viktmålet (null betyder annars "oförändrat").
  UserSettings copyWith({
    WeightUnit? weightUnit,
    TempUnit? tempUnit,
    bool? restTimerEnabled,
    int? restTimerSecs,
    double? weightGoalKg,
    bool clearGoal = false,
    bool? ambientEffects,
    bool? finishNote,
    bool? restWakeScreen,
    bool? workoutTourSeen,
    String? appBuild,
  }) =>
      UserSettings(
        weightUnit: weightUnit ?? this.weightUnit,
        tempUnit: tempUnit ?? this.tempUnit,
        restTimerEnabled: restTimerEnabled ?? this.restTimerEnabled,
        restTimerSecs: restTimerSecs ?? this.restTimerSecs,
        weightGoalKg: clearGoal ? null : (weightGoalKg ?? this.weightGoalKg),
        ambientEffects: ambientEffects ?? this.ambientEffects,
        finishNote: finishNote ?? this.finishNote,
        restWakeScreen: restWakeScreen ?? this.restWakeScreen,
        workoutTourSeen: workoutTourSeen ?? this.workoutTourSeen,
        appBuild: appBuild ?? this.appBuild,
      );
}
