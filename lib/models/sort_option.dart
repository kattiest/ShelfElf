enum SortField { name, percentRemaining, expiryDate, location }
enum SortDirection { asc, desc }

class SortOption {
  final SortField field;
  final SortDirection direction;

  const SortOption({
    required this.field,
    required this.direction,
  });

  static const defaultSort =
      SortOption(field: SortField.name, direction: SortDirection.asc);

  String get label {
    final dir = direction == SortDirection.asc ? '↑' : '↓';
    switch (field) {
      case SortField.name:
        return direction == SortDirection.asc ? 'A → Z' : 'Z → A';
      case SortField.percentRemaining:
        return direction == SortDirection.asc
            ? 'Least remaining $dir'
            : 'Most remaining $dir';
      case SortField.expiryDate:
        return direction == SortDirection.asc
            ? 'Expiring soon $dir'
            : 'Expiring last $dir';
      case SortField.location:
        return 'Location $dir';
    }
  }

  SortOption toggleDirection() => SortOption(
        field: field,
        direction: direction == SortDirection.asc
            ? SortDirection.desc
            : SortDirection.asc,
      );

  SortOption withField(SortField f) =>
      SortOption(field: f, direction: direction);
}
