use axum::{
    extract::State,
    http::StatusCode,
    Json,
};
use sqlx::PgPool;
use uuid::Uuid;
use argon2::{
    password_hash::{rand_core::OsRng, PasswordHasher, SaltString},
    Argon2,
};

use crate::models::user::{RegisterRequest, RegisterResponse};

pub async fn register(
    State(pool): State<PgPool>,
    Json(req): Json<RegisterRequest>,
) -> Result<(StatusCode, Json<RegisterResponse>), (StatusCode, String)> {
    
    let department_exists: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM departments WHERE id = $1)"
    )
    .bind(req.department_id)
    .fetch_one(&pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    if !department_exists {
        return Err((StatusCode::BAD_REQUEST, "Отдел не найден".to_string()));
    }
    
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();
    let password_hash = argon2
        .hash_password(req.password.as_bytes(), &salt)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Hash error: {}", e)))?
        .to_string();
    
    let user_id = Uuid::new_v4();
    
    sqlx::query(
        r#"
        INSERT INTO users (id, surname, name, patronymic, department_id, comment, password_hash, is_approved)
        VALUES ($1, $2, $3, $4, $5, $6, $7, false)
        "#
    )
    .bind(user_id)
    .bind(&req.surname)
    .bind(&req.name)
    .bind(&req.patronymic)
    .bind(req.department_id)
    .bind(&req.comment)
    .bind(&password_hash)
    .execute(&pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Insert error: {}", e)))?;
    
    Ok((
        StatusCode::OK,
        Json(RegisterResponse {
            message: "Регистрация отправлена на подтверждение".to_string(),
            user_id,
        }),
    ))
}