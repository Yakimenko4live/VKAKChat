import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/encryption_service.dart';
import '../models/user.dart';
import '../models/department.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onToggle;

  const RegisterScreen({super.key, required this.onToggle});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  final _surnameController = TextEditingController();
  final _nameController = TextEditingController();
  final _patronymicController = TextEditingController();
  final _commentController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Department? _selectedDepartment;
  List<Department> _departments = [];
  List<Department> _level1Departments = [];
  List<Department> _level2Departments = [];
  List<Department> _level3Departments = [];

  Department? _selectedLevel1;
  Department? _selectedLevel2;

  bool _isLoading = false;
  bool _isLoadingDepartments = true;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final departments = await _apiService.getDepartments();
      setState(() {
        _departments = departments;
        _level1Departments = departments.where((d) => d.level == 1).toList();
        _isLoadingDepartments = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingDepartments = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка загрузки отделов: $e')));
    }
  }

  void _onLevel1Selected(Department? dept) {
    setState(() {
      _selectedLevel1 = dept;
      _selectedLevel2 = null;
      _selectedDepartment = dept;
      _level2Departments = _departments
          .where((d) => d.level == 2 && d.parentId == dept?.id)
          .toList();
      _level3Departments = [];
    });
  }

  void _onLevel2Selected(Department? dept) {
    setState(() {
      _selectedLevel2 = dept;
      _selectedDepartment = dept;
      _level3Departments = _departments
          .where((d) => d.level == 3 && d.parentId == dept?.id)
          .toList();
    });
  }

  void _onLevel3Selected(Department? dept) {
    setState(() {
      _selectedDepartment = dept;
    });
  }

  String _truncateName(String name, int maxLength) {
    if (name.length <= maxLength) return name;
    return '${name.substring(0, maxLength - 3)}...';
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDepartment == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Выберите отдел')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Генерируем ключевую пару
      final keyPair = EncryptionService.generateKeyPair();

      // Сохраняем приватный ключ на устройстве
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('private_key', keyPair.privateKey);

      final user = User(
        surname: _surnameController.text.trim(),
        name: _nameController.text.trim(),
        patronymic: _patronymicController.text.trim().isEmpty
            ? null
            : _patronymicController.text.trim(),
        departmentId: _selectedDepartment!.id,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
        publicKey: keyPair.publicKey,
      );

      await _apiService.register(user, _passwordController.text);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[800],
            title: const Text(
              'Регистрация отправлена',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Ваша заявка отправлена администратору. После подтверждения вы сможете войти в приложение.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onToggle();
                },
                child: const Text('OK', style: TextStyle(color: Colors.green)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _isLoadingDepartments
            ? const Center(
                child: CircularProgressIndicator(color: Colors.green),
              )
            : Container(
                width: MediaQuery.of(context).size.width > 600
                    ? 500
                    : double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[900]?.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.person_add,
                          size: 32,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Регистрация',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Заполните данные для регистрации',
                        style: TextStyle(fontSize: 14, color: Colors.white54),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _surnameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Фамилия *',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.green),
                          ),
                        ),
                        validator: (v) =>
                            v?.isEmpty ?? true ? 'Введите фамилию' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Имя *',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.green),
                          ),
                        ),
                        validator: (v) =>
                            v?.isEmpty ?? true ? 'Введите имя' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _patronymicController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Отчество',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
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
                      DropdownButtonFormField<Department>(
                        value: _selectedLevel1,
                        dropdownColor: Colors.grey[800],
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Окружной отдел *',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.green),
                          ),
                        ),
                        items: _level1Departments.map((dept) {
                          return DropdownMenuItem(
                            value: dept,
                            child: Text(_truncateName(dept.name, 30)),
                          );
                        }).toList(),
                        onChanged: _onLevel1Selected,
                        validator: (v) =>
                            v == null ? 'Выберите окружной отдел' : null,
                      ),

                      if (_level2Departments.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<Department>(
                          value: _selectedLevel2,
                          dropdownColor: Colors.grey[800],
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Субъектовый отдел',
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.green),
                            ),
                          ),
                          items: _level2Departments.map((dept) {
                            return DropdownMenuItem(
                              value: dept,
                              child: Text(_truncateName(dept.name, 30)),
                            );
                          }).toList(),
                          onChanged: _onLevel2Selected,
                        ),
                      ],

                      if (_level3Departments.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<Department>(
                          value:
                              _selectedDepartment != null &&
                                  _selectedDepartment!.level == 3
                              ? _selectedDepartment
                              : null,
                          dropdownColor: Colors.grey[800],
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Местный отдел',
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.green),
                            ),
                          ),
                          items: _level3Departments.map((dept) {
                            return DropdownMenuItem(
                              value: dept,
                              child: Text(_truncateName(dept.name, 30)),
                            );
                          }).toList(),
                          onChanged: _onLevel3Selected,
                        ),
                      ],

                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _commentController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Род деятельности',
                          hintText: 'Например: учет сотрудников',
                          hintStyle: const TextStyle(color: Colors.white38),
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
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
                      TextFormField(
                        controller: _passwordController,
                        style: const TextStyle(color: Colors.white),
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Пароль *',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.green),
                          ),
                        ),
                        validator: (v) {
                          if (v?.isEmpty ?? true) return 'Введите пароль';
                          if (v!.length < 6)
                            return 'Пароль не менее 6 символов';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        style: const TextStyle(color: Colors.white),
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Подтверждение пароля *',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.green),
                          ),
                        ),
                        validator: (v) {
                          if (v != _passwordController.text) {
                            return 'Пароли не совпадают';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Зарегистрироваться',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Уже есть аккаунт?',
                            style: TextStyle(color: Colors.white54),
                          ),
                          TextButton(
                            onPressed: widget.onToggle,
                            child: const Text(
                              'Войти',
                              style: TextStyle(color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
