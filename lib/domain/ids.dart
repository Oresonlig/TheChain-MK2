/// Typade id:n. Extension types kostar inget i körtid men gör det omöjligt att
/// skicka ett pass-id där ett övnings-id väntas — MK1 hade fyra sorters
/// övnings-id plus namn som referens i samma strängrymd (Gör om #2).
library;

/// Stabilt id för en övning i katalogen (bibliotek eller egen). Ändras aldrig,
/// även om övningen byter namn. Historik, PR och anteckningar refererar detta.
extension type const ExerciseId(String value) implements Object {}

/// Ett pass i programmet (A, B, … eller vilodag).
extension type const SessionId(String value) implements Object {}

/// En plats i ett pass. Pekar på en övning; överlever byte av övning.
extension type const SlotId(String value) implements Object {}

/// Ett set. Stabilt under hela passet — aldrig en position (MK1 3.39.0).
extension type const SetId(String value) implements Object {}

/// Ett pass som pågår eller är avslutat.
extension type const WorkoutId(String value) implements Object {}
