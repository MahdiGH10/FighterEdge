import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/edge_fuel_repository.dart';
import '../../domain/calculators/nutrition_target_calculator.dart';
import '../../domain/models/nutrition_enums.dart';
import '../../domain/models/nutrition_profile.dart';
import '../../domain/models/nutrition_setup_draft.dart';
import '../../domain/models/nutrition_target.dart';

/// Drives the six-step EdgeFuel setup wizard (master prompt §6). Every
/// field-level setter autosaves immediately, so closing the app mid-setup
/// and reopening it resumes exactly where the user left off. The clock is
/// injected so `confirm()` is testable without a live DateTime.now() call.
class EdgeFuelSetupController extends ChangeNotifier {
  EdgeFuelSetupController({
    required EdgeFuelRepository repository,
    required String userId,
    DateTime Function()? clock,
  })  : _repository = repository,
        _userId = userId,
        _clock = clock ?? DateTime.now {
    unawaited(_load());
  }

  final EdgeFuelRepository _repository;
  final String _userId;
  final DateTime Function() _clock;

  bool _isLoading = true;
  NutritionSetupDraft _draft = const NutritionSetupDraft.empty();
  NutritionTarget? _previewTarget;
  Future<void> _pendingSave = Future<void>.value();
  bool _draftSaveFailed = false;

  bool get isLoading => _isLoading;
  NutritionSetupDraft get draft => _draft;
  NutritionTarget? get previewTarget => _previewTarget;

  /// Every field the calculator needs is present. Does not mean the values
  /// are safe/valid — that's checked when [confirm] actually calculates.
  bool get canReview =>
      _draft.hasRequiredCalculatorInputs &&
      _draft.screeningStatus != NutritionScreeningStatus.unanswered;

  Future<void> _load() async {
    final existing = await _repository.watchProfileDraft(_userId).first;
    if (existing != null) _draft = existing;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _update(
    NutritionSetupDraft Function(NutritionSetupDraft) mutate,
  ) async {
    _draft = mutate(_draft).copyWith(confirmed: false);
    notifyListeners();
    await _enqueueDraftSave();
  }

  Future<void> _enqueueDraftSave() {
    final snapshot = _draft;
    _pendingSave = _pendingSave.then((_) async {
      try {
        await _repository.saveProfileDraft(_userId, snapshot);
        _draftSaveFailed = false;
      } catch (_) {
        // Field callbacks are not awaited by every widget. Keep the draft
        // restricted and let the next write or confirmation retry it.
        _draftSaveFailed = true;
      }
    });
    return _pendingSave;
  }

  // ---- Step 1: Goal ----
  Future<void> setGoal(NutritionGoal goal) =>
      _update((d) => d.copyWith(goal: goal));

  // ---- Step 2: Body inputs ----
  Future<void> setBodyInputs({
    int? ageYears,
    double? heightCm,
    double? currentWeightKg,
    double? targetWeightKg,
    EquationProfile? equationProfile,
  }) =>
      _update((d) => d.copyWith(
            confirmed: false,
            ageYears: ageYears,
            heightCm: heightCm,
            currentWeightKg: currentWeightKg,
            targetWeightKg: targetWeightKg,
            equationProfile: equationProfile,
          ));

  // ---- Step 3: Normal activity ----
  Future<void> setActivityLevel(ActivityLevel level) =>
      _update((d) => d.copyWith(normalActivityLevel: level));

  // ---- Step 4: Training ----
  Future<void> setTraining({int? weeklyTrainingDays, GoalPace? goalPace}) =>
      _update((d) => d.copyWith(
            weeklyTrainingDays: weeklyTrainingDays,
            goalPace: goalPace,
          ));

  // ---- Step 5: Food preferences (stored for later sprints) ----
  Future<void> setFoodPreferences({
    String? dietType,
    List<String>? allergens,
    List<String>? dislikedFoods,
    int? mealsPerDay,
    String? budgetBand,
    String? cookingTimeBand,
  }) =>
      _update((d) => d.copyWith(
            dietType: dietType,
            allergens: allergens,
            dislikedFoods: dislikedFoods,
            mealsPerDay: mealsPerDay,
            budgetBand: budgetBand,
            cookingTimeBand: cookingTimeBand,
          ));

  Future<void> setSafetyFlags(NutritionSafetyFlags flags) =>
      _update((d) => d.copyWith(
            safetyFlags: flags,
            screeningStatus: NutritionScreeningStatus.unanswered,
            confirmed: false,
          ));

  Future<void> setScreeningReviewed(bool reviewed) => _update((d) => d.copyWith(
        screeningStatus: !reviewed
            ? NutritionScreeningStatus.unanswered
            : d.safetyFlags.any
                ? NutritionScreeningStatus.needsReview
                : NutritionScreeningStatus.completed,
        confirmed: false,
      ));

  Future<void> goToStep(int step) async {
    _draft = _draft.copyWith(currentStep: step);
    notifyListeners();
    await _enqueueDraftSave();
  }

  /// Recomputes a live preview for the Review step without persisting
  /// anything — lets the user see the plan before committing to it.
  void refreshPreview() {
    final profile = _draft.toProfile();
    _previewTarget = profile == null
        ? null
        : NutritionTargetCalculator.calculate(profile, now: _clock());
    notifyListeners();
  }

  /// Step 6: Review confirmation. Calculates the real target and persists
  /// both the confirmed draft and the target. Returns false (does nothing)
  /// if required inputs are still missing — callers should check
  /// [canReview] before offering this action.
  Future<bool> confirm() async {
    await _pendingSave;
    if (_draftSaveFailed) {
      await _enqueueDraftSave();
      if (_draftSaveFailed) throw StateError('Could not save setup draft');
    }
    final profile = _draft.toProfile();
    if (profile == null) return false;
    final target = NutritionTargetCalculator.calculate(profile, now: _clock());
    _previewTarget = target;
    if (!target.isSuccess) {
      notifyListeners();
      return false;
    }
    final confirmed = _draft.copyWith(confirmed: true);
    await _repository.saveConfirmedPlan(_userId, confirmed, target);
    _draft = confirmed;
    notifyListeners();
    return true;
  }
}
