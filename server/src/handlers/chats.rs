use axum::{
    extract::{State, Path, Extension},
    http::StatusCode,
    Json,
};
use serde::{Deserialize, Serialize};
use sqlx::Row;
use uuid::Uuid;

use crate::state::AppState;

#[derive(Debug, Serialize)]
pub struct ChatResponse {
    pub id: Uuid,
    pub title: Option<String>,
    pub chat_type: String,
    pub other_user_id: Option<Uuid>,
    pub other_user_name: Option<String>,
    pub unread_count: i64,
}

#[derive(Debug, Deserialize)]
pub struct CreateChatRequest {
    pub other_user_id: Uuid,
}

#[derive(Debug, Serialize)]
pub struct MessageResponse {
    pub id: Uuid,
    pub chat_id: Uuid,
    pub sender_id: Uuid,
    pub content: String,
    pub is_read: bool,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Deserialize)]
pub struct SendMessageRequest {
    pub chat_id: Uuid,
    pub content: String,
}


pub async fn mark_messages_as_read(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
    Path(chat_id): Path<Uuid>,
) -> Result<StatusCode, (StatusCode, String)> {
    
    sqlx::query(
        "UPDATE messages SET is_read = true WHERE chat_id = $1 AND sender_id != $2"
    )
    .bind(chat_id)
    .bind(user_id)
    .execute(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    Ok(StatusCode::OK)
}

pub async fn get_or_create_chat(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
    Json(body): Json<CreateChatRequest>,
) -> Result<Json<ChatResponse>, (StatusCode, String)> {
    
    let existing_chat = sqlx::query(
        r#"
        SELECT c.id, c.title, c.type 
        FROM chats c
        JOIN chat_participants cp1 ON c.id = cp1.chat_id
        JOIN chat_participants cp2 ON c.id = cp2.chat_id
        WHERE c.type = 'private' 
          AND cp1.user_id = $1 
          AND cp2.user_id = $2
        "#
    )
    .bind(user_id)
    .bind(body.other_user_id)
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    if let Some(chat) = existing_chat {
        let chat_id: Uuid = chat.get("id");
        let title: Option<String> = chat.get("title");
        let chat_type: String = chat.get("type");
        
        let other_user = sqlx::query(
            "SELECT surname, name FROM users WHERE id = $1"
        )
        .bind(body.other_user_id)
        .fetch_one(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
        
        let other_name = format!(
            "{} {}",
            other_user.get::<String, _>("surname"),
            other_user.get::<String, _>("name")
        );
        
        return Ok(Json(ChatResponse {
            id: chat_id,
            title,
            chat_type,
            other_user_id: Some(body.other_user_id),
            other_user_name: Some(other_name),
            unread_count: 0,
        }));
    }
    
    let chat_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO chats (id, type)
        VALUES ($1, 'private')
        "#
    )
    .bind(chat_id)
    .execute(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    sqlx::query(
        "INSERT INTO chat_participants (chat_id, user_id) VALUES ($1, $2)"
    )
    .bind(chat_id)
    .bind(user_id)
    .execute(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    sqlx::query(
        "INSERT INTO chat_participants (chat_id, user_id) VALUES ($1, $2)"
    )
    .bind(chat_id)
    .bind(body.other_user_id)
    .execute(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    let other_user = sqlx::query(
        "SELECT surname, name FROM users WHERE id = $1"
    )
    .bind(body.other_user_id)
    .fetch_one(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    let other_name = format!(
        "{} {}",
        other_user.get::<String, _>("surname"),
        other_user.get::<String, _>("name")
    );
    
    Ok(Json(ChatResponse {
        id: chat_id,
        title: None,
        chat_type: "private".to_string(),
        other_user_id: Some(body.other_user_id),
        other_user_name: Some(other_name),
        unread_count: 0,
    }))
}

pub async fn get_user_chats(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
) -> Result<Json<Vec<ChatResponse>>, (StatusCode, String)> {
    
    let chats = sqlx::query(
        r#"
        SELECT c.id, c.title, c.type,
               CASE 
                   WHEN c.type = 'private' THEN (
                       SELECT u.surname || ' ' || u.name
                       FROM users u
                       JOIN chat_participants cp ON u.id = cp.user_id
                       WHERE cp.chat_id = c.id AND cp.user_id != $1
                       LIMIT 1
                   )
                   ELSE c.title
               END as other_name,
               (SELECT u2.id FROM users u2
                JOIN chat_participants cp2 ON u2.id = cp2.user_id
                WHERE cp2.chat_id = c.id AND cp2.user_id != $1
                LIMIT 1) as other_user_id,
               (SELECT COUNT(*) FROM messages m 
                WHERE m.chat_id = c.id 
                AND m.sender_id != $1 
                AND m.is_read = false) as unread_count
        FROM chats c
        JOIN chat_participants cp ON c.id = cp.chat_id
        WHERE cp.user_id = $1
        ORDER BY c.updated_at DESC
        "#
    )
    .bind(user_id)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    let result = chats.iter().map(|row| {
        ChatResponse {
            id: row.get("id"),
            title: row.get("title"),
            chat_type: row.get("type"),
            other_user_id: row.get("other_user_id"),
            other_user_name: row.get("other_name"),
            unread_count: row.get("unread_count"),
        }
    }).collect();
    
    Ok(Json(result))
}
pub async fn get_user_public_key(
    State(state): State<AppState>,
    Path(user_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    
    let user = sqlx::query!(
        "SELECT public_key FROM users WHERE id = $1",
        user_id
    )
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    match user {
        Some(u) => Ok(Json(serde_json::json!({ "public_key": u.public_key }))),
        None => Err((StatusCode::NOT_FOUND, "User not found".to_string())),
    }
}


pub async fn get_chat_messages(
    State(state): State<AppState>,
    Path(chat_id): Path<Uuid>,
) -> Result<Json<Vec<MessageResponse>>, (StatusCode, String)> {
    
    let messages = sqlx::query(
        r#"
        SELECT id, chat_id, sender_id, content, is_read, created_at
        FROM messages
        WHERE chat_id = $1
        ORDER BY created_at ASC
        LIMIT 100
        "#
    )
    .bind(chat_id)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    let result = messages.iter().map(|row| {
        MessageResponse {
            id: row.get("id"),
            chat_id: row.get("chat_id"),
            sender_id: row.get("sender_id"),
            content: row.get("content"),
            is_read: row.get("is_read"),
            created_at: row.get("created_at"),
        }
    }).collect();
    
    Ok(Json(result))
}

pub async fn send_message(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
    Json(body): Json<SendMessageRequest>,
) -> Result<Json<MessageResponse>, (StatusCode, String)> {
    
    let message_id = Uuid::new_v4();
    
    sqlx::query(
        r#"
        INSERT INTO messages (id, chat_id, sender_id, content)
        VALUES ($1, $2, $3, $4)
        "#
    )
    .bind(message_id)
    .bind(body.chat_id)
    .bind(user_id)
    .bind(&body.content)
    .execute(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    sqlx::query(
        "UPDATE chats SET updated_at = NOW() WHERE id = $1"
    )
    .bind(body.chat_id)
    .execute(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    Ok(Json(MessageResponse {
        id: message_id,
        chat_id: body.chat_id,
        sender_id: user_id,
        content: body.content,
        is_read: false,
        created_at: chrono::Utc::now(),
    }))
}