import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../models/department.dart';
import 'department_tree_widget.dart';
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
  List<UserSearchResult> _pendingUsers = [];
  List<DepartmentNode> _departmentTree = [];
  bool _isLoading = false;
  bool _showResults = false;
  bool _showDepartments = true;
  bool _isLoadingDepartments = true;
  bool _isAdmin = false;
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _searchController.addListener(_onSearchChanged);
    _loadDepartments();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'user';
    setState(() {
      _isAdmin = role == 'admin' || role == 'super_admin';
      _isSuperAdmin = role == 'super_admin';
    });

    if (_isAdmin) {
      _loadPendingUsers();
    }
  }

  Future<void> _loadPendingUsers() async {
    try {
      final pending = await _apiService.getPendingUsers();
      setState(() {
        _pendingUsers = pending;
      });
    } catch (e) {
      print('Ошибка загрузки неподтверждённых пользователей: $e');
    }
  }

  Future<void> _approveUser(String userId) async {
    try {
      await _apiService.approveUser(userId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Пользователь подтверждён')));
      _loadPendingUsers();
      _loadDepartments();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _rejectUser(String userId) async {
    if (!_isSuperAdmin) return;

    try {
      await _apiService.rejectUser(userId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Пользователь отклонён')));
      _loadPendingUsers();
      _loadDepartments();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка загрузки отделов: $e')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка поиска: $e')));
    }
  }

  void _startChat(String userId) async {
    try {
      final chat = await _apiService.createChat(userId);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chat.id,
              otherUserName: chat.otherUserName ?? 'Чат',
              otherUserId: userId,
              initialUnreadCount: 0, // ✅ Для нового чата непрочитанных нет
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка создания чата: $e')));
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
          // Секция неподтверждённых пользователей (только для админа)
          if (_isAdmin && _pendingUsers.isNotEmpty) ...[
            const Text(
              'Неподтверждённые пользователи',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingUsers.length,
                itemBuilder: (context, index) {
                  final user = _pendingUsers[index];
                  return Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user.surname} ${user.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.departmentName,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              onPressed: () => _approveUser(user.id),
                              iconSize: 28,
                            ),
                            if (_isSuperAdmin)
                              IconButton(
                                icon: const Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                ),
                                onPressed: () => _rejectUser(user.id),
                                iconSize: 28,
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: _showResults
                ? _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.green),
                        )
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
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  )
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
