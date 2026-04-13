use axum::{
    extract::{State, Path, Extension},
    http::StatusCode,
    Json,
};
use serde::{Serialize, Deserialize};
use sqlx::Row;
use uuid::Uuid;

use crate::state::AppState;

#[derive(Debug, Serialize)]
pub struct PendingUser {
    pub id: Uuid,
    pub surname: String,
    pub name: String,
    pub patronymic: Option<String>,
    pub department_name: String,
    pub comment: Option<String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Deserialize)]
pub struct SetRoleRequest {
    pub role: String, // "admin" или "user"
}

#[derive(Debug, Serialize)]
pub struct AllUser {
    pub id: Uuid,
    pub surname: String,
    pub name: String,
    pub patronymic: Option<String>,
    pub department_name: String,
    pub role: String,
    pub is_approved: bool,
}

pub async fn get_all_users(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
) -> Result<Json<Vec<AllUser>>, (StatusCode, String)> {
    
    println!("🔵 get_all_users called by user: {}", user_id);
    
    let user_role: Option<String> = sqlx::query_scalar(
        "SELECT role FROM users WHERE id = $1"
    )
    .bind(user_id)
    .fetch_one(&state.pool)
    .await
    .map_err(|e| {
        println!("❌ Database error in role check: {}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e))
    })?;
    
    println!("🔵 User role: {:?}", user_role);
    
    let user_role = user_role.unwrap_or_default();
    if user_role != "super_admin" {
        println!("❌ Access denied for user {}", user_id);
        return Err((StatusCode::FORBIDDEN, "Access denied".to_string()));
    }
    
    let rows = sqlx::query(
        r#"
        SELECT u.id, u.surname, u.name, u.patronymic, u.role, u.is_approved, d.name as department_name
        FROM users u
        LEFT JOIN departments d ON u.department_id = d.id
        ORDER BY u.surname, u.name
        "#
    )
    .fetch_all(&state.pool)
    .await
    .map_err(|e| {
        println!("❌ Database error in query: {}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e))
    })?;
    
    println!("✅ Found {} users", rows.len());
    
    let users: Vec<AllUser> = rows.iter().map(|row| {
        AllUser {
            id: row.get("id"),
            surname: row.get("surname"),
            name: row.get("name"),
            patronymic: row.get("patronymic"),
            department_name: row.get("department_name"),
            role: row.get("role"),
            is_approved: row.get("is_approved"),
        }
    }).collect();
    
    Ok(Json(users))
}

pub async fn set_user_role(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
    Path(target_user_id): Path<Uuid>,
    Json(req): Json<SetRoleRequest>,
) -> Result<StatusCode, (StatusCode, String)> {
    
    println!("🔵 set_user_role called by user: {} for target: {} with role: {}", 
             user_id, target_user_id, req.role);
    
    let user_role: Option<String> = sqlx::query_scalar(
        "SELECT role FROM users WHERE id = $1"
    )
    .bind(user_id)
    .fetch_one(&state.pool)
    .await
    .map_err(|e| {
        println!("❌ Database error in role check: {}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e))
    })?;
    
    let user_role = user_role.unwrap_or_default();
    if user_role != "super_admin" {
        println!("❌ Access denied for user {}", user_id);
        return Err((StatusCode::FORBIDDEN, "Access denied".to_string()));
    }
    
    let target_role: Option<String> = sqlx::query_scalar(
        "SELECT role FROM users WHERE id = $1"
    )
    .bind(target_user_id)
    .fetch_one(&state.pool)
    .await
    .map_err(|e| {
        println!("❌ Database error in target role check: {}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e))
    })?;
    
    if target_role == Some("super_admin".to_string()) {
        println!("❌ Cannot change super_admin role for user {}", target_user_id);
        return Err((StatusCode::FORBIDDEN, "Cannot change super_admin role".to_string()));
    }
    
    sqlx::query(
        "UPDATE users SET role = $1 WHERE id = $2"
    )
    .bind(&req.role)
    .bind(target_user_id)
    .execute(&state.pool)
    .await
    .map_err(|e| {
        println!("❌ Database error in update: {}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e))
    })?;
    
    println!("✅ Role updated for user {} to {}", target_user_id, req.role);
    Ok(StatusCode::OK)
}

pub async fn get_pending_users(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
) -> Result<Json<Vec<PendingUser>>, (StatusCode, String)> {
    
    println!("🔐 get_pending_users called by user: {}", user_id);
    
    let user_role: Option<String> = sqlx::query_scalar(
        "SELECT role FROM users WHERE id = $1"
    )
    .bind(user_id)
    .fetch_one(&state.pool)
    .await
    .map_err(|e| {
        println!("❌ Database error in role check: {}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e))
    })?;
    
    println!("🔐 User role: {:?}", user_role);
    
    let user_role = user_role.unwrap_or_default();
    if user_role != "super_admin" && user_role != "admin" {
        println!("❌ Access denied for user {}", user_id);
        return Err((StatusCode::FORBIDDEN, "Access denied".to_string()));
    }
    
    let rows = sqlx::query(
        r#"
        SELECT u.id, u.surname, u.name, u.patronymic, u.comment, u.created_at, d.name as department_name
        FROM users u
        LEFT JOIN departments d ON u.department_id = d.id
        WHERE u.is_approved = false
        ORDER BY u.created_at DESC
        "#
    )
    .fetch_all(&state.pool)
    .await
    .map_err(|e| {
        println!("❌ Database error in query: {}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e))
    })?;
    
    println!("✅ Found {} pending users", rows.len());
    
    let users: Vec<PendingUser> = rows.iter().map(|row| {
        PendingUser {
            id: row.get("id"),
            surname: row.get("surname"),
            name: row.get("name"),
            patronymic: row.get("patronymic"),
            department_name: row.get("department_name"),
            comment: row.get("comment"),
            created_at: row.get("created_at"),
        }
    }).collect();
    
    Ok(Json(users))
}

pub async fn approve_user(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
    Path(target_user_id): Path<Uuid>,
) -> Result<StatusCode, (StatusCode, String)> {
    
    println!("✅ approve_user called by user: {} for target: {}", user_id, target_user_id);
    
    let user_role: Option<String> = sqlx::query_scalar(
        "SELECT role FROM users WHERE id = $1"
    )
    .bind(user_id)
    .fetch_one(&state.pool)
    .await
    .map_err(|e| {
        println!("❌ Database error in role check: {}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e))
    })?;
    
    let user_role = user_role.unwrap_or_default();
    if user_role != "super_admin" && user_role != "admin" {
        println!("❌ Access denied for user {}", user_id);
        return Err((StatusCode::FORBIDDEN, "Access denied".to_string()));
    }
    
    sqlx::query(
        "UPDATE users SET is_approved = true WHERE id = $1"
    )
    .bind(target_user_id)
    .execute(&state.pool)
    .await
    .map_err(|e| {
        println!("❌ Database error in approve: {}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e))
    })?;
    
    println!("✅ User {} approved successfully", target_user_id);
    Ok(StatusCode::OK)
}

pub async fn reject_user(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
    Path(target_user_id): Path<Uuid>,
) -> Result<StatusCode, (StatusCode, String)> {
    
    println!("❌ reject_user called by user: {} for target: {}", user_id, target_user_id);
    
    let user_role: Option<String> = sqlx::query_scalar(
        "SELECT role FROM users WHERE id = $1"
    )
    .bind(user_id)
    .fetch_one(&state.pool)
    .await
    .map_err(|e| {
        println!("❌ Database error in role check: {}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e))
    })?;
    
    let user_role = user_role.unwrap_or_default();
    if user_role != "super_admin" {
        println!("❌ Access denied for user {} (only super_admin can reject)", user_id);
        return Err((StatusCode::FORBIDDEN, "Access denied".to_string()));
    }
    
    sqlx::query(
        "DELETE FROM users WHERE id = $1"
    )
    .bind(target_user_id)
    .execute(&state.pool)
    .await
    .map_err(|e| {
        println!("❌ Database error in reject: {}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e))
    })?;
    
    println!("✅ User {} rejected and deleted successfully", target_user_id);
    Ok(StatusCode::OK)
}