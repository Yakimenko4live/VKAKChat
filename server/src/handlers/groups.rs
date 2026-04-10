use axum::{
    extract::{State, Path, Extension},
    http::StatusCode,
    Json,
};
use serde::{Deserialize, Serialize};
use sqlx::{PgPool, Row};
use uuid::Uuid;
use chrono::Utc;
use std::collections::HashMap;

use crate::state::AppState;

#[derive(Debug, Deserialize)]
pub struct CreateGroupRequest {
    pub title: String,
    pub participant_ids: Vec<Uuid>,
    pub encrypted_keys: HashMap<Uuid, String>,
}

#[derive(Debug, Deserialize)]
pub struct AddParticipantsRequest {
    pub user_ids: Vec<Uuid>,
}

#[derive(Debug, Serialize)]
pub struct GroupParticipant {
    pub user_id: Uuid,
    pub surname: String,
    pub name: String,
    pub patronymic: Option<String>,
    pub is_admin: bool,
}

#[derive(Debug, Serialize)]
pub struct GroupChatResponse {
    pub id: Uuid,
    pub title: String,
    pub creator_id: Uuid,
    pub participants: Vec<GroupParticipant>,
    pub admin_ids: Vec<Uuid>,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

pub async fn create_group(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
    Json(req): Json<CreateGroupRequest>,
) -> Result<Json<GroupChatResponse>, (StatusCode, String)> {
    println!("📝 Creating group: title={}, participants={:?}", req.title, req.participant_ids);
    println!("📝 Encrypted keys: {:?}", req.encrypted_keys);
    // Проверяем права
    let user_role: Option<String> = sqlx::query_scalar(
        "SELECT role FROM users WHERE id = $1"
    )
    .bind(user_id)
    .fetch_one(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    let user_role = user_role.unwrap_or_default();
    if user_role != "admin" && user_role != "super_admin" {
        return Err((StatusCode::FORBIDDEN, "Только администраторы могут создавать групповые чаты".to_string()));
    }
    
    // Создаём групповой чат
    let group_id = Uuid::new_v4();
    let now = Utc::now();
    
    sqlx::query(
        r#"
        INSERT INTO chats (id, title, type, creator_id, is_group, created_at, updated_at)
        VALUES ($1, $2, 'group', $3, true, $4, $4)
        "#
    )
    .bind(group_id)
    .bind(&req.title)
    .bind(user_id)
    .bind(now)
    .execute(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    // Добавляем создателя как админа
    sqlx::query(
        "INSERT INTO group_admins (group_id, user_id) VALUES ($1, $2)"
    )
    .bind(group_id)
    .bind(user_id)
    .execute(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    // Добавляем всех участников
    let mut all_participants = req.participant_ids.clone();
    all_participants.push(user_id);
    
    for participant_id in &all_participants {
        sqlx::query(
            "INSERT INTO chat_participants (chat_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING"
        )
        .bind(group_id)
        .bind(participant_id)
        .execute(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    }
    
    // Сохраняем зашифрованные ключи
    for (user_uuid, encrypted_key) in &req.encrypted_keys {
        sqlx::query(
            "INSERT INTO group_keys (group_id, user_id, encrypted_key) VALUES ($1, $2, $3)"
        )
        .bind(group_id)
        .bind(user_uuid)
        .bind(encrypted_key)
        .execute(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    }
    
    // Загружаем участников для ответа
    let participants = get_group_participants(&state.pool, group_id).await?;
    let admin_ids = get_group_admins(&state.pool, group_id).await?;
    
    Ok(Json(GroupChatResponse {
        id: group_id,
        title: req.title,
        creator_id: user_id,
        participants,
        admin_ids,
        created_at: now,
    }))
}

pub async fn get_user_groups(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
) -> Result<Json<Vec<GroupChatResponse>>, (StatusCode, String)> {
    
    let groups = sqlx::query!(
        r#"
        SELECT c.id, c.title, c.creator_id, c.created_at
        FROM chats c
        JOIN chat_participants cp ON c.id = cp.chat_id
        WHERE cp.user_id = $1 AND c.is_group = true
        ORDER BY c.updated_at DESC
        "#,
        user_id
    )
    .fetch_all(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    let mut result = Vec::new();
    for group in groups {
        let participants = get_group_participants(&state.pool, group.id).await?;
        let admin_ids = get_group_admins(&state.pool, group.id).await?;
        
        result.push(GroupChatResponse {
            id: group.id,
            title: group.title.unwrap_or_default(),
            creator_id: group.creator_id.unwrap(),
            participants,
            admin_ids,
            created_at: group.created_at.unwrap(),
        });
    }
    
    Ok(Json(result))
}

pub async fn get_group(
    State(state): State<AppState>,
    Path(group_id): Path<Uuid>,
) -> Result<Json<GroupChatResponse>, (StatusCode, String)> {
    
    let group = sqlx::query!(
        r#"
        SELECT id, title, creator_id, created_at
        FROM chats
        WHERE id = $1 AND is_group = true
        "#,
        group_id
    )
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?
    .ok_or((StatusCode::NOT_FOUND, "Групповой чат не найден".to_string()))?;
    
    let participants = get_group_participants(&state.pool, group_id).await?;
    let admin_ids = get_group_admins(&state.pool, group_id).await?;
    
    Ok(Json(GroupChatResponse {
        id: group.id,
        title: group.title.unwrap_or_default(),
        creator_id: group.creator_id.unwrap(),
        participants,
        admin_ids,
        created_at: group.created_at.unwrap(),
    }))
}
pub async fn get_group_key(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
    Path(group_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    
    let row = sqlx::query(
        "SELECT encrypted_key FROM group_keys WHERE group_id = $1 AND user_id = $2"
    )
    .bind(group_id)
    .bind(user_id)
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    match row {
        Some(r) => {
            let encrypted_key: String = r.get("encrypted_key");
            Ok(Json(serde_json::json!({ "encrypted_key": encrypted_key })))
        }
        None => Err((StatusCode::NOT_FOUND, "Key not found".to_string())),
    }
}pub async fn add_participants(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
    Path(group_id): Path<Uuid>,
    Json(req): Json<AddParticipantsRequest>,
) -> Result<StatusCode, (StatusCode, String)> {
    
    let is_admin: Option<bool> = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM group_admins WHERE group_id = $1 AND user_id = $2)"
    )
    .bind(group_id)
    .bind(user_id)
    .fetch_one(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    if !is_admin.unwrap_or(false) {
        return Err((StatusCode::FORBIDDEN, "Только администраторы группы могут добавлять участников".to_string()));
    }
    
    for participant_id in req.user_ids {
        sqlx::query(
            "INSERT INTO chat_participants (chat_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING"
        )
        .bind(group_id)
        .bind(participant_id)
        .execute(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    }
    
    Ok(StatusCode::OK)
}

pub async fn remove_participant(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
    Path((group_id, target_user_id)): Path<(Uuid, Uuid)>,
) -> Result<StatusCode, (StatusCode, String)> {
    
    let is_admin: Option<bool> = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM group_admins WHERE group_id = $1 AND user_id = $2)"
    )
    .bind(group_id)
    .bind(user_id)
    .fetch_one(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    if !is_admin.unwrap_or(false) {
        return Err((StatusCode::FORBIDDEN, "Только администраторы группы могут удалять участников".to_string()));
    }
    
    sqlx::query(
        "DELETE FROM chat_participants WHERE chat_id = $1 AND user_id = $2"
    )
    .bind(group_id)
    .bind(target_user_id)
    .execute(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    Ok(StatusCode::OK)
}

pub async fn leave_group(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
    Path(group_id): Path<Uuid>,
) -> Result<StatusCode, (StatusCode, String)> {
    
    sqlx::query(
        "DELETE FROM chat_participants WHERE chat_id = $1 AND user_id = $2"
    )
    .bind(group_id)
    .bind(user_id)
    .execute(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    Ok(StatusCode::OK)
}

async fn get_group_participants(pool: &PgPool, group_id: Uuid) -> Result<Vec<GroupParticipant>, (StatusCode, String)> {
    let rows = sqlx::query(
        r#"
        SELECT u.id, u.surname, u.name, u.patronymic, 
               EXISTS(SELECT 1 FROM group_admins ga WHERE ga.group_id = $1 AND ga.user_id = u.id) as is_admin
        FROM chat_participants cp
        JOIN users u ON cp.user_id = u.id
        WHERE cp.chat_id = $1
        "#
    )
    .bind(group_id)
    .fetch_all(pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    let participants = rows.iter().map(|row| {
        GroupParticipant {
            user_id: row.get("id"),
            surname: row.get("surname"),
            name: row.get("name"),
            patronymic: row.get("patronymic"),
            is_admin: row.get("is_admin"),
        }
    }).collect();
    
    Ok(participants)
}

async fn get_group_admins(pool: &PgPool, group_id: Uuid) -> Result<Vec<Uuid>, (StatusCode, String)> {
    let rows = sqlx::query(
        "SELECT user_id FROM group_admins WHERE group_id = $1"
    )
    .bind(group_id)
    .fetch_all(pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    let admin_ids = rows.iter().map(|row| row.get("user_id")).collect();
    Ok(admin_ids)
}