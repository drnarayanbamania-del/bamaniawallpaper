import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'api.dart';
import 'theme.dart';
import 'wallpaper_detail.dart';

/// Category Screen — Horizontal chips + filtered wallpaper grid.
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<dynamic> _categories = [];
  List<dynamic> _wallpapers = [];
  int? _selectedCategoryId;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _loadingCategories = true;
  bool _loadingWallpapers = true;
  bool _loadingMore = false;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final data = await Api.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = data['categories'] as List;
        _loadingCategories = false;
      });
      _loadWallpapers();
    } catch (e) {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  Future<void> _loadWallpapers() async {
    setState(() => _loadingWallpapers = true);

    try {
      final data = await Api.getWallpapers(
        page: 1,
        categoryId: _selectedCategoryId,
      );
      if (!mounted) return;
      setState(() {
        _wallpapers = data['wallpapers'] as List;
        _currentPage = 1;
        _totalPages = data['pagination']['totalPages'] ?? 1;
        _loadingWallpapers = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingWallpapers = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _currentPage >= _totalPages) return;
    setState(() => _loadingMore = true);

    try {
      final data = await Api.getWallpapers(
        page: _currentPage + 1,
        categoryId: _selectedCategoryId,
      );
      if (!mounted) return;
      setState(() {
        _wallpapers.addAll(data['wallpapers'] as List);
        _currentPage++;
        _totalPages = data['pagination']['totalPages'] ?? 1;
        _loadingMore = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _selectCategory(int? id) {
    setState(() => _selectedCategoryId = id);
    _loadWallpapers();
  }

  void _showWallpaperDetail(Map<String, dynamic> wallpaper) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => WallpaperDetail(
        wallpaper: wallpaper,
        onDownloaded: () => _loadWallpapers(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Categories',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: Column(
        children: [
          // Category chips
          SizedBox(
            height: 48,
            child: _loadingCategories
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _categories.length + 1, // +1 for "All"
                    itemBuilder: (ctx, i) {
                      if (i == 0) {
                        return _buildChip('All', null);
                      }
                      final cat = _categories[i - 1];
                      return _buildChip(
                          cat['name'], cat['id'] as int);
                    },
                  ),
          ),
          const SizedBox(height: 8),

          // Wallpaper grid
          Expanded(
            child: _loadingWallpapers
                ? _buildShimmerGrid()
                : _wallpapers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.category_rounded,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No wallpapers in this category',
                              style: TextStyle(
                                fontSize: 15,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadWallpapers,
                        color: Theme.of(context).colorScheme.primary,
                        child: GridView.builder(
                          controller: _scrollController,
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.65,
                          ),
                          itemCount:
                              _wallpapers.length + (_loadingMore ? 2 : 0),
                          itemBuilder: (ctx, i) {
                            if (i >= _wallpapers.length) {
                              return _buildShimmerCard();
                            }
                            return _buildWallpaperCard(_wallpapers[i]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, int? categoryId) {
    final selected = _selectedCategoryId == categoryId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _selectCategory(categoryId),
        selectedColor: Theme.of(context).colorScheme.primary,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : null,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide(
          color:
              selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
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
                baseColor:
                    Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                highlightColor:
                    Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                child: Container(color: Colors.white),
              ),
              errorWidget: (ctx, url, err) => Container(
                color:
                    Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
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
                child: Text(
                  wallpaper['title'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.65,
      ),
      itemCount: 6,
      itemBuilder: (ctx, i) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
      highlightColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
