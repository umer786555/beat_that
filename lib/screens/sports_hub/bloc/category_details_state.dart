part of 'category_details_bloc.dart';

abstract class SportDetailsState extends Equatable {
  const SportDetailsState();

  @override
  List<Object?> get props => [];
}

class CategoryDetailsInitial extends SportDetailsState {
  const CategoryDetailsInitial();
}

class CategoryDetailsLoading extends SportDetailsState {
  const CategoryDetailsLoading();
}

class CategoryDetailsLoaded extends SportDetailsState {
  final CategoryModel sport;

  const CategoryDetailsLoaded({required this.sport});

  @override
  List<Object?> get props => [sport];
}

class CategoryDetailsError extends SportDetailsState {
  final String message;

  const CategoryDetailsError({required this.message});

  @override
  List<Object?> get props => [message];
}
