import 'package:flutter/material.dart';
import '../models/department.dart';

class DepartmentTreeWidget extends StatelessWidget {
  final List<DepartmentNode> departments;
  final Function(String userId) onUserTap;

  const DepartmentTreeWidget({
    super.key,
    required this.departments,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: departments.length,
      itemBuilder: (context, index) {
        return _buildDepartmentTile(departments[index]);
      },
    );
  }

  Widget _buildDepartmentTile(DepartmentNode dept) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            dept.level == 1 ? Icons.account_balance :
            dept.level == 2 ? Icons.business :
            Icons.location_city,
            color: Colors.white,
            size: 18,
          ),
        ),
        title: Text(
          dept.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        textColor: Colors.white,
        iconColor: Colors.green,
        children: [
          // Сначала показываем сотрудников отдела
          if (dept.users.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
              child: Text(
                'Сотрудники:',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            ...dept.users.map((user) => _buildUserTile(user)),
          ],
          // Потом показываем подчинённые отделы
          if (dept.children.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
              child: Text(
                'Подразделения:',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            ...dept.children.map((child) => _buildDepartmentTile(child)),
          ],
          if (dept.users.isEmpty && dept.children.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Нет сотрудников и подразделений',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserTile(UserInfo user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.3),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (user.comment != null && user.comment!.isNotEmpty)
                  Text(
                    user.comment!,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => onUserTap(user.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Написать', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}