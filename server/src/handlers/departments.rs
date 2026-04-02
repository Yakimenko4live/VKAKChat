use axum::{
    extract::State,
    http::StatusCode,
    Json,
};
use serde::Serialize;
use sqlx::{PgPool, Row};
use uuid::Uuid;
use std::collections::HashMap;

#[derive(Debug, Serialize, Clone)]
pub struct UserInfo {
    pub id: Uuid,
    pub surname: String,
    pub name: String,
    pub patronymic: Option<String>,
    pub comment: Option<String>,
}

#[derive(Debug, Serialize, Clone)]
pub struct DepartmentNode {
    pub id: Uuid,
    pub name: String,
    pub level: i32,
    pub users: Vec<UserInfo>,
    pub children: Vec<DepartmentNode>,
}

#[derive(Debug, Serialize)]
pub struct Department {
    pub id: Uuid,
    pub name: String,
    pub level: i32,
    pub parent_id: Option<Uuid>,
}

pub async fn get_departments(
    State(pool): State<PgPool>,
) -> Result<Json<Vec<Department>>, (StatusCode, String)> {
    
    let rows = sqlx::query(
        "SELECT id, name, level, parent_id FROM departments ORDER BY level, name"
    )
    .fetch_all(&pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    let departments: Vec<Department> = rows.iter().map(|row| {
        Department {
            id: row.get("id"),
            name: row.get("name"),
            level: row.get("level"),
            parent_id: row.get("parent_id"),
        }
    }).collect();
    
    Ok(Json(departments))
}

fn build_children(
    parent_id: &Uuid,
    children_map: &HashMap<Uuid, Vec<Uuid>>,
    dept_map: &HashMap<Uuid, DepartmentNode>,
) -> Vec<DepartmentNode> {
    let mut children = Vec::new();
    
    if let Some(child_ids) = children_map.get(parent_id) {
        for child_id in child_ids {
            let mut child_node = dept_map.get(child_id).unwrap().clone();
            child_node.children = build_children(child_id, children_map, dept_map);
            children.push(child_node);
        }
    }
    
    children
}

pub async fn get_department_tree(
    State(pool): State<PgPool>,
) -> Result<Json<Vec<DepartmentNode>>, (StatusCode, String)> {
    
    // Получаем все отделы
    let dept_rows = sqlx::query(
        r#"
        SELECT id, name, level, parent_id
        FROM departments
        ORDER BY level, name
        "#
    )
    .fetch_all(&pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    // Получаем всех утверждённых пользователей
    let user_rows = sqlx::query(
        r#"
        SELECT u.id, u.surname, u.name, u.patronymic, u.comment, u.department_id
        FROM users u
        WHERE u.is_approved = true
        ORDER BY u.surname, u.name
        "#
    )
    .fetch_all(&pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    // Группируем пользователей по отделам
    let mut dept_users: HashMap<Uuid, Vec<UserInfo>> = HashMap::new();
    for row in &user_rows {
        let dept_id: Uuid = row.get("department_id");
        let user_info = UserInfo {
            id: row.get("id"),
            surname: row.get("surname"),
            name: row.get("name"),
            patronymic: row.get("patronymic"),
            comment: row.get("comment"),
        };
        dept_users.entry(dept_id).or_insert_with(Vec::new).push(user_info);
    }
    
    // Создаём карту отделов
    let mut dept_map: HashMap<Uuid, DepartmentNode> = HashMap::new();
    for row in &dept_rows {
        let id: Uuid = row.get("id");
        let node = DepartmentNode {
            id,
            name: row.get("name"),
            level: row.get("level"),
            users: dept_users.get(&id).cloned().unwrap_or_default(),
            children: Vec::new(),
        };
        dept_map.insert(id, node);
    }
    
    // Строим карту детей
    let mut children_map: HashMap<Uuid, Vec<Uuid>> = HashMap::new();
    for row in &dept_rows {
        let id: Uuid = row.get("id");
        let parent_id: Option<Uuid> = row.get("parent_id");
        if let Some(parent) = parent_id {
            children_map.entry(parent).or_insert_with(Vec::new).push(id);
        }
    }
    
    // Строим корневые узлы
    let mut roots = Vec::new();
    for row in &dept_rows {
        let id: Uuid = row.get("id");
        let parent_id: Option<Uuid> = row.get("parent_id");
        
        if parent_id.is_none() {
            let mut node = dept_map.get(&id).unwrap().clone();
            node.children = build_children(&id, &children_map, &dept_map);
            roots.push(node);
        }
    }
    
    Ok(Json(roots))
}