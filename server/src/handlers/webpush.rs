use axum::{
    extract::State,
    http::StatusCode,
    Json,
    Extension,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::state::AppState;

#[derive(Debug, Deserialize)]
pub struct SubscribeRequest {
    pub subscription: serde_json::Value,
}

pub async fn subscribe(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
    Json(req): Json<SubscribeRequest>,
) -> Result<StatusCode, (StatusCode, String)> {
    
    let subscription_json = req.subscription.to_string();
    
    sqlx::query(
        r#"
        INSERT INTO web_push_subscriptions (user_id, subscription)
        VALUES ($1, $2)
        ON CONFLICT (user_id) DO UPDATE SET 
            subscription = $2,
            updated_at = NOW()
        "#
    )
    .bind(user_id)
    .bind(subscription_json)
    .execute(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    println!("✅ WebPush subscription saved for user: {}", user_id);
    
    Ok(StatusCode::OK)
}