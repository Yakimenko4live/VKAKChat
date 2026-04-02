import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user.dart';

class SearchWidget extends StatefulWidget {
  const SearchWidget({super.key});

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  
  List<UserSearchResult> _searchResults = [];
  bool _isLoading = false;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query.length >= 2) {
      _performSearch();
    } else if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
    }
  }

  Future<void> _performSearch() async {
    setState(() {
      _isLoading = true;
      _showResults = true;
    });

    try {
      final results = await _apiService.searchUsers(_searchController.text);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка поиска: $e')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Поиск',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Поиск по фамилии, имени, отчеству...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _showResults = false;
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.green),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _showResults
                ? _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.green))
                    : _searchResults.isEmpty
                        ? const Center(
                            child: Text(
                              'Ничего не найдено',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              return _buildUserTile(user);
                            },
                          )
                : const Center(
                    child: Text(
                      'Введите имя или фамилию для поиска',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(UserSearchResult user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.3),
            borderRadius: BorderRadius.circular(25),
          ),
          child: const Center(
            child: Icon(Icons.person, color: Colors.white),
          ),
        ),
        title: Text(
          '${user.surname} ${user.name}${user.patronymic != null ? ' ${user.patronymic}' : ''}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              user.departmentName,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (user.comment != null && user.comment!.isNotEmpty)
              Text(
                user.comment!,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () {
            print('Start chat with: ${user.id}');
            // TODO: начать чат с пользователем
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text('Написать'),
        ),
      ),
    );
  }
}