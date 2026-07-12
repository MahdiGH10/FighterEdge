import 'package:flutter/material.dart';

class CoachCue {
  final String label;
  final String message;
  final IconData icon;
  const CoachCue(this.label, this.message, this.icon);
}

class TimerStyle {
  final String name; // Boxing, MMA, BJJ
  final int rounds;
  final int workSeconds;
  final int restSeconds;
  const TimerStyle(this.name, this.rounds, this.workSeconds, this.restSeconds);
}
