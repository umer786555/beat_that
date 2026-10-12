part of 'category_details_bloc.dart';

abstract class SportDetailsEvent extends Equatable {
  const SportDetailsEvent();

  @override
  List<Object?> get props => [];
}

class LoadCategoryDetailsEvent extends SportDetailsEvent {
  final CategoryModel category;

  const LoadCategoryDetailsEvent({required this.category});

  @override
  List<Object?> get props => [category];
}
