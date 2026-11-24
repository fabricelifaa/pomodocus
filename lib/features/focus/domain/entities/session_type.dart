enum SessionType {
  focus,
  shortBreak,
  longBreak;

  bool get isBreak => this != SessionType.focus;

  static SessionType fromName(String? name) => SessionType.values.firstWhere(
    (e) => e.name == name,
    orElse: () => SessionType.focus,
  );
}

enum SessionStatus {
  completed,
  interrupted;

  static SessionStatus fromName(String? name) => SessionStatus.values
      .firstWhere((e) => e.name == name, orElse: () => SessionStatus.completed);
}
