use axum::{
    extract::ws::{WebSocket, WebSocketUpgrade},
    response::Response,
    extract::State,
};
use futures_util::{SinkExt, StreamExt};
use tokio::sync::broadcast;
use tracing::info;
use uuid::Uuid;
use serde::{Deserialize, Serialize};

use crate::state::AppState;

#[derive(Debug, Serialize, Deserialize)]
struct WebSocketMessage {
    r#type: String,
    data: serde_json::Value,
}

pub async fn websocket_handler(
    ws: WebSocketUpgrade,
    State(state): State<AppState>,
) -> Response {
    ws.on_upgrade(|socket| handle_socket(socket, state))
}

async fn handle_socket(mut socket: WebSocket, state: AppState) {
    info!("WebSocket connected");
    
    let (mut sender, mut receiver) = socket.split();
    
    // Создаём канал для этого подключения
    let (tx, mut rx) = broadcast::channel::<String>(100);
    
    // Временный ID пользователя (будет получен после авторизации)
    // Пока используем заглушку, но нужно будет получать user_id из токена
    let mut current_user_id: Option<Uuid> = None;
    
    // Отправляем ping
    let _ = sender.send(axum::extract::ws::Message::Text("pong".to_string())).await;
    
    // Задача для отправки сообщений из канала в WebSocket
    let mut send_task = tokio::spawn({
        let mut sender = sender;
        async move {
            while let Ok(msg) = rx.recv().await {
                if sender.send(axum::extract::ws::Message::Text(msg)).await.is_err() {
                    break;
                }
            }
        }
    });
    
    // Обрабатываем входящие сообщения
    while let Some(Ok(msg)) = receiver.next().await {
        if let Ok(text) = msg.to_text() {
            if text == "ping" {
                let _ = sender.send(axum::extract::ws::Message::Text("pong".to_string())).await;
                continue;
            }
            
            // Пытаемся получить user_id из сообщения (первое сообщение с авторизацией)
            if current_user_id.is_none() {
                if let Ok(auth_msg) = serde_json::from_str::<serde_json::Value>(text) {
                    if auth_msg.get("type").and_then(|v| v.as_str()) == Some("auth") {
                        if let Some(user_id_str) = auth_msg.get("user_id").and_then(|v| v.as_str()) {
                            if let Ok(user_id) = Uuid::parse_str(user_id_str) {
                                current_user_id = Some(user_id);
                                // Регистрируем пользователя в комнатах
                                let mut rooms = state.rooms.lock().await;
                                rooms.insert(user_id, tx.clone());
                                info!("User {} authenticated via WebSocket", user_id);
                                continue;
                            }
                        }
                    }
                }
            }
            
            // Обработка сообщения чата
            if let Ok(ws_msg) = serde_json::from_str::<WebSocketMessage>(text) {
                if ws_msg.r#type == "message" {
                    if let (Some(chat_id), Some(content), Some(sender_id)) = (
                        ws_msg.data.get("chat_id").and_then(|v| v.as_str()),
                        ws_msg.data.get("content").and_then(|v| v.as_str()),
                        ws_msg.data.get("sender_id").and_then(|v| v.as_str()),
                    ) {
                        let chat_id = Uuid::parse_str(chat_id).ok();
                        let sender_id = Uuid::parse_str(sender_id).ok();
                        
                        if let (Some(chat_id), Some(sender_id)) = (chat_id, sender_id) {
                            // Сохраняем сообщение в БД
                            let message_id = Uuid::new_v4();
                            let now = chrono::Utc::now();
                            
                            let _ = sqlx::query(
                                r#"
                                INSERT INTO messages (id, chat_id, sender_id, content, created_at)
                                VALUES ($1, $2, $3, $4, $5)
                                "#
                            )
                            .bind(message_id)
                            .bind(chat_id)
                            .bind(sender_id)
                            .bind(content)
                            .bind(now)
                            .execute(&state.pool)
                            .await;
                            
                            // Обновляем время чата
                            let _ = sqlx::query(
                                "UPDATE chats SET updated_at = NOW() WHERE id = $1"
                            )
                            .bind(chat_id)
                            .execute(&state.pool)
                            .await;
                            
                            // Получаем всех участников чата
                            let participants = sqlx::query!(
                                r#"
                                SELECT user_id FROM chat_participants WHERE chat_id = $1
                                "#,
                                chat_id
                            )
                            .fetch_all(&state.pool)
                            .await;
                            
                            // Создаём сообщение для рассылки
                            let response = serde_json::json!({
                                "type": "new_message",
                                "data": {
                                    "id": message_id,
                                    "chat_id": chat_id,
                                    "sender_id": sender_id,
                                    "content": content,
                                    "created_at": now,
                                }
                            });
                            
                            let response_str = response.to_string();
                            
                            // Рассылаем всем участникам чата
                            if let Ok(participants) = participants {
                                let rooms = state.rooms.lock().await;
                                for p in participants {
                                    if let Some(room_tx) = rooms.get(&p.user_id) {
                                        let _ = room_tx.send(response_str.clone());
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // При отключении удаляем пользователя из комнат
    if let Some(user_id) = current_user_id {
        let mut rooms = state.rooms.lock().await;
        rooms.remove(&user_id);
        info!("User {} disconnected from WebSocket", user_id);
    }
    
    send_task.abort();
    info!("WebSocket disconnected");
}