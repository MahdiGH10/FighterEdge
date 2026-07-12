import 'package:flutter/material.dart';

import '../models/coach_cue.dart';
import '../models/fighter.dart';
import '../models/meal.dart';
import '../models/technique.dart';
import '../models/training_session.dart';
import '../models/weight_entry.dart';

class MockData {
  MockData._();

  static const fighter = Fighter(
    name: 'Ayoub',
    tagline: 'The Grind Never Lies.',
    division: 'Amateur Lightweight',
    heightCm: 179,
    weightKg: 77.2,
    trainingDays: 128,
    totalWorkouts: 312,
    wins: 7,
    losses: 2,
    currentStreak: 24,
    goals: [
      Goal('Improve striking', 0.80),
      Goal('Get to 74 kg', 0.60),
    ],
  );

  /// Weekly overview rings on the dashboard (0..1 completion per weekday).
  static const weeklyProgress = <double>[1.0, 1.0, 1.0, 0.7, 0.4, 0.0, 0.0];
  static const weekDayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const todayIndex = 2; // Wednesday highlighted

  static const recentActivity = <ActivityEntry>[
    ActivityEntry('Strength Training', 'Upper Body', 'Yesterday',
        Icons.fitness_center),
    ActivityEntry('Mobility', 'Hip Flow', '2 days ago', Icons.self_improvement),
    ActivityEntry('BJJ Rolling', 'Guard Retention', '3 days ago', Icons.sports_mma),
  ];

  static const week = <TrainingSession>[
    TrainingSession(
        day: 'Mon',
        title: 'Striking',
        subtitle: 'Boxing + Combinations',
        icon: Icons.sports_mma,
        completed: true),
    TrainingSession(
        day: 'Tue',
        title: 'Wrestling',
        subtitle: 'Takedowns + Control',
        icon: Icons.sports_kabaddi,
        completed: true),
    TrainingSession(
        day: 'Wed',
        title: 'Conditioning',
        subtitle: 'HIIT + Core · 45 min',
        icon: Icons.bolt,
        completed: true),
    TrainingSession(
        day: 'Thu',
        title: 'BJJ',
        subtitle: 'Transitions + Submissions · 60 min',
        icon: Icons.sports_martial_arts,
        completed: true),
    TrainingSession(
        day: 'Fri',
        title: 'Strength',
        subtitle: 'Upper Body · 60 min',
        icon: Icons.fitness_center,
        completed: false),
    TrainingSession(
        day: 'Sat',
        title: 'Conditioning',
        subtitle: 'Endurance + Sprints · 45 min',
        icon: Icons.directions_run,
        completed: false),
    TrainingSession(
        day: 'Sun',
        title: 'Rest / Active Recovery',
        subtitle: 'Mobility + Stretching',
        icon: Icons.spa,
        completed: false),
  ];

  static const techniques = <Technique>[
    Technique(
        category: 'BOXING',
        discipline: 'Striking',
        title: 'Jab Fundamentals',
        videoCount: 12),
    Technique(
        category: 'BOXING',
        discipline: 'Striking',
        title: 'Basic Combinations',
        videoCount: 18),
    Technique(
        category: 'KICKBOXING',
        discipline: 'Striking',
        title: 'Low Kick Setups',
        videoCount: 10),
    Technique(
        category: 'WRESTLING',
        discipline: 'Wrestling',
        title: 'Double Leg Takedown',
        videoCount: 14),
    Technique(
        category: 'BJJ',
        discipline: 'BJJ',
        title: 'Guard Retention',
        videoCount: 22),
    Technique(
        category: 'MUAY THAI',
        discipline: 'Clinch',
        title: 'Clinch Control & Knees',
        videoCount: 9),
  ];

  static const disciplines = ['All', 'Striking', 'Wrestling', 'BJJ', 'Clinch'];

  static const coachCues = <CoachCue>[
    CoachCue('FOCUS', 'Control the pace and stay composed.', Icons.center_focus_strong),
    CoachCue('DEFENSE', 'Keep your guard high. Avoid unnecessary risks.', Icons.shield),
    CoachCue('OFFENSE', 'Set up your combinations behind the jab.', Icons.sports_mma),
    CoachCue('CONDITIONING', 'You\'re strong. Keep your breathing under control.', Icons.favorite),
  ];

  static const timerStyles = <TimerStyle>[
    TimerStyle('Boxing', 12, 180, 60),
    TimerStyle('MMA', 5, 300, 60),
    TimerStyle('BJJ', 6, 300, 30),
  ];

  static const macroTarget = MacroTarget(
    calories: 2600,
    protein: 170,
    carbs: 260,
    fats: 70,
  );

  static List<Meal> seedMeals() => [
        Meal(
            name: 'Breakfast',
            items: 'Oats, Banana, Whey Protein',
            calories: 620,
            protein: 42,
            carbs: 78,
            fats: 14,
            eaten: true),
        Meal(
            name: 'Lunch',
            items: 'Chicken, Rice, Vegetables',
            calories: 750,
            protein: 55,
            carbs: 82,
            fats: 18,
            eaten: true),
        Meal(
            name: 'Snack',
            items: 'Greek Yogurt, Almonds',
            calories: 320,
            protein: 24,
            carbs: 22,
            fats: 16,
            eaten: true),
        Meal(
            name: 'Dinner',
            items: 'Salmon, Sweet Potato, Greens',
            calories: 666,
            protein: 44,
            carbs: 53,
            fats: 24,
            eaten: true),
        Meal(
            name: 'Late Snack',
            items: 'Casein Shake',
            calories: 180,
            protein: 30,
            carbs: 6,
            fats: 3,
            eaten: false),
      ];

  static List<WeightEntry> seedWeights() => [
        WeightEntry(DateTime(2024, 5, 6), 78.3),
        WeightEntry(DateTime(2024, 5, 13), 78.1),
        WeightEntry(DateTime(2024, 5, 20), 77.8),
        WeightEntry(DateTime(2024, 5, 27), 77.5),
        WeightEntry(DateTime(2024, 6, 3), 77.2),
      ];
}
