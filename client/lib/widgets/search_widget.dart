import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../models/department.dart';
import 'department_tree_widget.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/chat.dart';
import '../screens/chat_screen.dart';

class SearchWidget extends StatefulWidget {
  const SearchWidget({super.key});

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  
  List<UserSearchResult> _searchResults = [];
  List<DepartmentNode> _departmentTree = [];
  bool _isLoading = false;
  bool _showResults = false;
  bool _showDepartments = true;
  bool _isLoadingDepartments = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    setState(() => _isLoadingDepartments = true);
    try {
      final tree = await _apiService.getDepartmentTree();
      setState(() {
        _departmentTree = tree;
        _isLoadingDepartments = false;
      });
    } catch (e) {
      setState(() => _isLoadingDepartments = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки отделов: $e')),
      );
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query.length >= 2) {
      setState(() => _showDepartments = false);
      _performSearch();
    } else if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
        _showDepartments = true;
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

 void _startChat(String userId) async {
  try {
    final apiService = ApiService();
    final chat = await apiService.createChat(userId);
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chat.id,
            otherUserName: chat.otherUserName ?? 'Чат',
            otherUserId: userId,
          ),
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ошибка создания чата: $e')),
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
                          _showDepartments = true;
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
                              return _buildUserTile(
                                id: user.id,
                                surname: user.surname,
                                name: user.name,
                                patronymic: user.patronymic,
                                departmentName: user.departmentName,
                                comment: user.comment,
                              );
                            },
                          )
                : _isLoadingDepartments
                    ? const Center(child: CircularProgressIndicator(color: Colors.green))
                    : DepartmentTreeWidget(
                        departments: _departmentTree,
                        onUserTap: _startChat,
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile({
    required String id,
    required String surname,
    required String name,
    String? patronymic,
    required String departmentName,
    String? comment,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.3),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Center(
              child: Icon(Icons.person, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patronymic != null && patronymic.isNotEmpty
                      ? '$surname $name $patronymic'
                      : '$surname $name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  departmentName,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                if (comment != null && comment.isNotEmpty)
                  Text(
                    comment,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _startChat(id),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Написать'),
          ),
        ],
      ),
    );
  }
}