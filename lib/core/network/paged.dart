/// Typed page wrapper for Spring Data paginated responses.
///
/// Parses the REAL wire shape (verified live against the backend):
/// `{content: [...], page: {size, number, totalElements, totalPages}}`,
/// with fallback to the OpenAPI-documented flat shape
/// (`{content, totalElements, totalPages, number}`).
class Paged<T> {
  const Paged({
    required this.items,
    required this.page,
    required this.totalElements,
    required this.totalPages,
    required this.isLast,
  });

  final List<T> items;
  final int page;
  final int totalElements;
  final int totalPages;
  final bool isLast;

  static Paged<T> fromJson<T>(
    dynamic json,
    T Function(Map<String, dynamic>) fromItem,
  ) {
    if (json is List) {
      // Unpaged list endpoints (e.g. GET /api/conversations).
      return Paged<T>(
        items: [
          for (final e in json)
            if (e is Map<String, dynamic>) fromItem(e),
        ],
        page: 0,
        totalElements: json.length,
        totalPages: 1,
        isLast: true,
      );
    }
    final map = (json as Map?)?.cast<String, dynamic>() ?? {};
    final rawItems = map['content'];
    final items = <T>[
      if (rawItems is List)
        for (final e in rawItems)
          if (e is Map<String, dynamic>) fromItem(e),
    ];
    final pageObj =
        (map['page'] as Map?)?.cast<String, dynamic>();
    int numOf(String key, int fallback) {
      final v = pageObj?[key] ?? map[key];
      return v is num ? v.toInt() : fallback;
    }

    final total = numOf('totalElements', items.length);
    final pages = numOf('totalPages', 1);
    final number = numOf('number', 0);
    final last = map['last'];
    return Paged<T>(
      items: items,
      page: number,
      totalElements: total,
      totalPages: pages,
      isLast: last is bool ? last : number >= pages - 1,
    );
  }

  bool get isEmpty => items.isEmpty;
}

/// Standard page/size query for Spring `Pageable`.
Map<String, String> pageQuery({int page = 0, int size = 20}) => {
      'page': '$page',
      'size': '$size',
    };
