import 'package:donaciones/core/models/domain_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable filter and sort state for [FeedScreen] (CU-19, CU-20, CU-22).
class FeedFilterState {
  static const Object _unset = Object();

  final String? selectedCategoryId;
  final TipoPublicacion? selectedType;
  final Urgencia? selectedUrgency;
  final bool sortByUrgency;
  final double? maxDistanceKm;
  final bool sortByDistance;

  const FeedFilterState({
    this.selectedCategoryId,
    this.selectedType,
    this.selectedUrgency,
    this.sortByUrgency = false,
    this.maxDistanceKm,
    this.sortByDistance = false,
  });

  bool get hasActiveFilters =>
      selectedCategoryId != null ||
      selectedType != null ||
      selectedUrgency != null ||
      sortByUrgency ||
      maxDistanceKm != null ||
      sortByDistance;

  FeedFilterState copyWith({
    Object? selectedCategoryId = _unset,
    Object? selectedType = _unset,
    Object? selectedUrgency = _unset,
    bool? sortByUrgency,
    Object? maxDistanceKm = _unset,
    bool? sortByDistance,
  }) {
    return FeedFilterState(
      selectedCategoryId: identical(selectedCategoryId, _unset)
          ? this.selectedCategoryId
          : selectedCategoryId as String?,
      selectedType: identical(selectedType, _unset)
          ? this.selectedType
          : selectedType as TipoPublicacion?,
      selectedUrgency: identical(selectedUrgency, _unset)
          ? this.selectedUrgency
          : selectedUrgency as Urgencia?,
      sortByUrgency: sortByUrgency ?? this.sortByUrgency,
      maxDistanceKm: identical(maxDistanceKm, _unset)
          ? this.maxDistanceKm
          : maxDistanceKm as double?,
      sortByDistance: sortByDistance ?? this.sortByDistance,
    );
  }
}

/// Reactive provider managing active feed filters and sorting options.
final feedFilterControllerProvider =
    StateNotifierProvider<FeedFilterController, FeedFilterState>(
      (ref) => FeedFilterController(),
    );

class FeedFilterController extends StateNotifier<FeedFilterState> {
  FeedFilterController() : super(const FeedFilterState());

  /// Selects a category, or clears it when tapping the same category again (CU-19).
  void selectCategory(String? categoryId) {
    if (categoryId == null) {
      state = state.copyWith(selectedCategoryId: null);
      return;
    }
    final next = state.selectedCategoryId == categoryId ? null : categoryId;
    state = state.copyWith(selectedCategoryId: next);
  }

  /// Filters by publication type without resetting other active filters (CU-19).
  void selectType(TipoPublicacion? type) {
    state = state.copyWith(selectedType: type);
  }

  /// Filters by urgency level, toggling off when tapping the active level (CU-22).
  void selectUrgency(Urgencia? urgency) {
    if (urgency == null) {
      state = state.copyWith(selectedUrgency: null);
      return;
    }
    final next = state.selectedUrgency == urgency ? null : urgency;
    state = state.copyWith(selectedUrgency: next);
  }

  void toggleSortByUrgency() {
    state = state.copyWith(
      sortByUrgency: !state.sortByUrgency,
      sortByDistance: false,
    );
  }

  /// Sets the proximity radius filter in kilometers (CU-20).
  void selectMaxDistance(double? maxDistanceKm) {
    state = state.copyWith(maxDistanceKm: maxDistanceKm);
  }

  void toggleSortByDistance() {
    state = state.copyWith(
      sortByDistance: !state.sortByDistance,
      sortByUrgency: false,
    );
  }

  /// Clears all active filters and sort toggles (CU-19 2a).
  void clearFilters() {
    state = const FeedFilterState();
  }
}
