import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'api.dart';
import 'local_db.dart';
import 'wallpaper_detail.dart';

class SearchScreen extends StatefulWidget {
  final int? initialCategoryId;
  final String? initialCategoryName;

  const SearchScreen({
    super.key,
    this.initialCategoryId,
    this.initialCategoryName,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<dynamic> _allWallpapers = [];
  List<dynamic> _displayWallpapers = [];
  List<String> _history = [];

  int _currentPage = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _showBackToTop = false;

  int? _selectedCategoryId;
  String? _selectedCategoryName;

  // Sorting: newest, downloads, alphabet
  String _sortOption = 'newest'; 

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    _selectedCategoryName = widget.initialCategoryName;

    _loadHistory();
    _scrollController.addListener(_scrollListener);

    if (_selectedCategoryId != null) {
      _fetchResults();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.offset > 400 && !_showBackToTop) {
      setState(() => _showBackToTop = true);
    } else if (_scrollController.offset <= 400 && _showBackToTop) {
      setState(() => _showBackToTop = false);
    }

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadHistory() async {
    final list = await LocalDb.instance.getSearchHistory();
    setState(() => _history = list);
  }

  Future<void> _clearHistory() async {
    await HapticFeedback.lightImpact();
    await LocalDb.instance.clearSearchHistory();
    _loadHistory();
  }

  Future<void> _deleteHistoryItem(String query) async {
    await HapticFeedback.lightImpact();
    await LocalDb.instance.deleteSearchQuery(query);
    _loadHistory();
  }

  Future<void> _fetchResults() async {
    if (_loading) return;
    setState(() => _loading = true);

    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      await LocalDb.instance.addSearchQuery(query);
      _loadHistory();
    }

    try {
      final data = await Api.getWallpapers(
        page: 1,
        categoryId: _selectedCategoryId,
        search: query.isNotEmpty ? query : null,
      );

      if (!mounted) return;
      setState(() {
        _allWallpapers = data['wallpapers'] as List;
        _currentPage = 1;
        _totalPages = data['pagination']['totalPages'] ?? 1;
        _applySortAndFilter();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _currentPage >= _totalPages) return;
    setState(() => _loadingMore = true);

    final query = _searchController.text.trim();
    try {
      final data = await Api.getWallpapers(
        page: _currentPage + 1,
        categoryId: _selectedCategoryId,
        search: query.isNotEmpty ? query : null,
      );

      if (!mounted) return;
      setState(() {
        _allWallpapers.addAll(data['wallpapers'] as List);
        _currentPage++;
        _totalPages = data['pagination']['totalPages'] ?? 1;
        _applySortAndFilter();
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _applySortAndFilter() {
    List<dynamic> temp = List.from(_allWallpapers);

    if (_sortOption == 'newest') {
      temp.sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
    } else if (_sortOption == 'downloads') {
      temp.sort((a, b) => (b['downloads'] ?? 0).compareTo(a['downloads'] ?? 0));
    } else if (_sortOption == 'alphabet') {
      temp.sort((a, b) =>
          (a['title'] ?? '').toLowerCase().compareTo((b['title'] ?? '').toLowerCase()));
    }

    setState(() {
      _displayWallpapers = temp;
    });
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty && _selectedCategoryId == null) return;
    _fetchResults();
  }

  void _selectHistoryItem(String query) {
    HapticFeedback.lightImpact();
    _searchController.text = query;
    _fetchResults();
  }

  void _showSortSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Sort Wallpapers By',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _sortTile(ctx, 'Newest Uploads', 'newest', Icons.new_releases_rounded),
              _sortTile(ctx, 'Most Downloaded', 'downloads', Icons.trending_up_rounded),
              _sortTile(ctx, 'A – Z Alphabetical', 'alphabet', Icons.sort_by_alpha_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortTile(BuildContext ctx, String label, String value, IconData icon) {
    final isSelected = _sortOption == value;
    final primaryColor = Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Icon(icon, color: isSelected ? primaryColor : null),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? primaryColor : null,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: primaryColor)
          : null,
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _sortOption = value;
          _applySortAndFilter();
        });
        Navigator.pop(ctx);
      },
    );
  }

  void _showWallpaperDetail(Map<String, dynamic> wallpaper) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => WallpaperDetail(
        wallpaper: wallpaper,
        onDownloaded: () => _fetchResults(),
      ),
    );
  }

  void _clearFilters() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedCategoryId = null;
      _selectedCategoryName = null;
      _searchController.clear();
      _allWallpapers.clear();
      _displayWallpapers.clear();
    });
  }

  void _scrollToTop() {
    HapticFeedback.lightImpact();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          if (_displayWallpapers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.swap_vert_rounded),
              tooltip: 'Sort options',
              onPressed: _showSortSheet,
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onSubmitted: _onSearchSubmitted,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search wallpapers...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      onPressed: () => _onSearchSubmitted(_searchController.text),
                    ),
                  ],
                ),
              ),
              onChanged: (v) => setState(() {}),
            ),
          ),

          // Active filter chip row
          if (_selectedCategoryName != null || _sortOption != 'newest')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_selectedCategoryName != null) ...[
                      InputChip(
                        label: Text('Category: $_selectedCategoryName'),
                        onDeleted: () {
                          setState(() {
                            _selectedCategoryId = null;
                            _selectedCategoryName = null;
                          });
                          _fetchResults();
                        },
                        deleteIconColor: Colors.redAccent,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (_sortOption != 'newest') ...[
                      InputChip(
                        label: Text('Sort: ${_sortOption.toUpperCase()}'),
                        onDeleted: () {
                          setState(() {
                            _sortOption = 'newest';
                            _applySortAndFilter();
                          });
                        },
                        deleteIconColor: Colors.redAccent,
                      ),
                      const SizedBox(width: 8),
                    ],
                    TextButton(
                      onPressed: _clearFilters,
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      child: const Text('Reset All', style: TextStyle(fontSize: 12)),
                    )
                  ],
                ),
              ),
            ),

          // Main search display area
          Expanded(
            child: _loading
                ? _buildShimmerGrid()
                : _displayWallpapers.isNotEmpty
                    ? GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.65,
                        ),
                        itemCount:
                            _displayWallpapers.length + (_loadingMore ? 2 : 0),
                        itemBuilder: (ctx, i) {
                          if (i >= _displayWallpapers.length) {
                            return _buildShimmerCard();
                          }
                          final wallpaper = _displayWallpapers[i];
                          return _buildWallpaperCard(wallpaper);
                        },
                      )
                    : _searchController.text.isEmpty && _selectedCategoryId == null
                        ? _buildSearchHistory()
                        : _buildEmptyState(),
          ),
        ],
      ),
      floatingActionButton: _showBackToTop
          ? FloatingActionButton(
              onPressed: _scrollToTop,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              mini: true,
              child: const Icon(Icons.arrow_upward_rounded),
            )
          : null,
    );
  }

  Widget _buildWallpaperCard(Map<String, dynamic> wallpaper) {
    return GestureDetector(
      onTap: () => _showWallpaperDetail(wallpaper),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: wallpaper['file_url'] ?? '',
              fit: BoxFit.cover,
              placeholder: (ctx, url) => Shimmer.fromColors(
                baseColor: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                highlightColor: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                child: Container(color: Colors.white),
              ),
              errorWidget: (ctx, url, err) => Container(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                child: const Icon(Icons.broken_image_rounded, size: 32),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      wallpaper['title'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.download_rounded, color: Colors.white70, size: 10),
                        const SizedBox(width: 2),
                        Text(
                          '${wallpaper['downloads'] ?? 0}',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHistory() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            ),
            const SizedBox(height: 12),
            const Text(
              'Search History Empty',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Search for beautiful wallpapers now.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Searches',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            TextButton(
              onPressed: _clearHistory,
              child: const Text('Clear All', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        ..._history.map((query) => ListTile(
              leading: const Icon(Icons.history_rounded, size: 20),
              title: Text(query),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: () => _deleteHistoryItem(query),
              ),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onTap: () => _selectHistoryItem(query),
            )),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Wallpapers Found',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Try searching for something else or clearing filters.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.65,
      ),
      itemCount: 4,
      itemBuilder: (ctx, i) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.outline.withOpacity(0.3),
      highlightColor: Theme.of(context).colorScheme.outline.withOpacity(0.1),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
