use axum::{
    extract::{State, Extension, Path},
    http::StatusCode,
    Json,
};
use serde::Serialize;
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

pub async fn get_pending_users(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
) -> Result<Json<Vec<PendingUser>>, (StatusCode, String)> {
    
    println!("🔐 get_pending_users called by user: {}", user_id);
    
    // Проверяем права
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
    
    let user_role: Option<String> = sqlx::query_scalar(
        "SELECT role FROM users WHERE id = $1"
    )
    .bind(user_id)
    .fetch_one(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    let user_role = user_role.unwrap_or_default();
    if user_role != "super_admin" && user_role != "admin" {
        return Err((StatusCode::FORBIDDEN, "Access denied".to_string()));
    }
    
    sqlx::query(
        "UPDATE users SET is_approved = true WHERE id = $1"
    )
    .bind(target_user_id)
    .execute(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    Ok(StatusCode::OK)
}

pub async fn reject_user(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
    Path(target_user_id): Path<Uuid>,
) -> Result<StatusCode, (StatusCode, String)> {
    
    let user_role: Option<String> = sqlx::query_scalar(
        "SELECT role FROM users WHERE id = $1"
    )
    .bind(user_id)
    .fetch_one(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    let user_role = user_role.unwrap_or_default();
    if user_role != "super_admin" {
        return Err((StatusCode::FORBIDDEN, "Access denied".to_string()));
    }
    
    sqlx::query(
        "DELETE FROM users WHERE id = $1"
    )
    .bind(target_user_id)
    .execute(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    Ok(StatusCode::OK)
}