/// Lettura tollerante dei campi JSON: ogni campo ha un predefinito, come `s.get(..., default)` del desktop.
library;

Map<String, Object?> asMap(Object? v) => v is Map
    ? <String, Object?>{for (final e in v.entries) e.key.toString(): e.value}
    : <String, Object?>{};

List<Object?> asList(Object? v) =>
    v is List ? List<Object?>.of(v) : <Object?>[];

double readDouble(Map<String, Object?> m, String k, double predefinito) {
  final v = m[k];
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? predefinito;
  return predefinito;
}

int readInt(Map<String, Object?> m, String k, int predefinito) {
  final v = m[k];
  if (v is int) return v;
  if (v is num) return v.toInt(); // `int(x)` di Python tronca verso lo zero
  if (v is String) return int.tryParse(v) ?? predefinito;
  return predefinito;
}

/// Verità alla Python: `bool(x)`.
bool truthy(Object? v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.isNotEmpty;
  if (v is List) return v.isNotEmpty;
  if (v is Map) return v.isNotEmpty;
  return true;
}

bool readBool(Map<String, Object?> m, String k, bool predefinito) =>
    m.containsKey(k) && m[k] != null ? truthy(m[k]) : predefinito;

String readString(Map<String, Object?> m, String k, String predefinito) {
  final v = m[k];
  return v is String ? v : predefinito;
}

String? readStringOrNull(Map<String, Object?> m, String k) {
  final v = m[k];
  return v is String ? v : null;
}

/// Campi non conosciuti da questa versione: si conservano e si riscrivono tali e quali.
Map<String, Object?> unknownFields(Map<String, Object?> m, Set<String> noti) =>
    <String, Object?>{
      for (final e in m.entries)
        if (!noti.contains(e.key)) e.key: e.value,
    };
