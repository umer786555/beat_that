import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/models/category.dart';
import 'package:beat_that/models/subcategory.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

part 'category_details_event.dart';
part 'category_details_state.dart';

class SportDetailsBloc extends Bloc<SportDetailsEvent, SportDetailsState> {
  final SupabaseService _supabaseService = locator<SupabaseService>();

  SportDetailsBloc() : super(const CategoryDetailsInitial()) {
    // Register event handlers
    on<LoadCategoryDetailsEvent>(_onLoadCategoryDetails);
  }

  /// Load sport details with subcategories from Supabase
  Future<void> _onLoadCategoryDetails(
    LoadCategoryDetailsEvent event,
    Emitter<SportDetailsState> emit,
  ) async {
    try {
      emit(const CategoryDetailsLoading());

      // Fetch all sports with their subcategories from Supabase
      final subcategoriesMap = await _supabaseService.getSubcategories(
        event.category.name.trim(),
      );

      // Sort subcategories alphabetically with "other" at the bottom
      final sortedSubcategories = _sortSubcategoriesWithOtherLast(subcategoriesMap);

      // Create an updated sport model with the fetched subcategories
      final updatedCategory = event.category.copyWith(
        subcategories: sortedSubcategories,
      );

      emit(CategoryDetailsLoaded(sport: updatedCategory));
    } catch (e) {
      emit(
        CategoryDetailsError(
          message: AppStrings.somethingWentWrongPleaseTryAgain,
        ),
      );
    }
  }

  /// Sort subcategories alphabetically by name, with "other" always at the bottom.
  List<Subcategorys> _sortSubcategoriesWithOtherLast(
    List<Subcategorys> subcategories,
  ) {
    final notOther = <Subcategorys>[];
    Subcategorys? other;

    for (final sub in subcategories) {
      if (sub.name.toLowerCase() == 'other') {
        other = sub;
      } else {
        notOther.add(sub);
      }
    }

    // Sort alphabetically by name
    notOther.sort((a, b) => a.name.compareTo(b.name));

    // Add "other" at the end if it exists
    if (other != null) {
      notOther.add(other);
    }

    return notOther;
  }
}
