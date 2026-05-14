import 'package:equatable/equatable.dart';

abstract class WardrobeEvent extends Equatable {
  const WardrobeEvent();

  @override
  List<Object?> get props => [];
}

class WardrobeLoadRequested extends WardrobeEvent {
  const WardrobeLoadRequested();
}

class WardrobeFilterChanged extends WardrobeEvent {
  final String category;

  const WardrobeFilterChanged(this.category);

  @override
  List<Object?> get props => [category];
}

class WardrobeItemAdded extends WardrobeEvent {
  const WardrobeItemAdded();
}
