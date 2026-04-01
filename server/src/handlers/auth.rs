use axum::{
    extract::State,
    http::StatusCode,
    Json,
};
use sqlx::PgPool;
use uuid::Uuid;
use argon2::{
    password_hash::{PasswordHash, PasswordVerifier, rand_core::OsRng, PasswordHasher, SaltString},
    Argon2,
};
use serde::{Deserialize, Serialize};
use jsonwebtoken::{encode, Header, EncodingKey};
use tracing::info;

#[derive(Debug, Deserialize)]
pub struct RegisterRequest {
    pub surname: String,
    pub name: String,
    pub patronymic: Option<String>,
    pub department_id: Uuid,
    pub comment: Option<String>,
    pub password: String,
}

#[derive(Debug, Serialize)]
pub struct RegisterResponse {
    pub message: String,
    pub user_id: Uuid,
}

#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub identifier: String,
    pub password: String,
}

#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub token: String,
    pub user_id: Uuid,
    pub surname: String,
    pub name: String,
}

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

pub async fn login(
    State(pool): State<PgPool>,
    Json(req): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, (StatusCode, String)> {
    
    info!("Login attempt for identifier: {}", req.identifier);
    
    let user = sqlx::query!(
        r#"
        SELECT id, surname, name, password_hash, is_approved
        FROM users
        WHERE surname || ' ' || name = $1 OR surname = $1 OR name = $1
        "#,
        req.identifier
    )
    .fetch_optional(&pool)
    .await
    .map_err(|e| {
        info!("Database error: {}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e))
    })?;
    
    if let Some(ref u) = user {
        info!("Found user: {} {}, approved: {:?}", u.surname, u.name, u.is_approved);
    } else {
        info!("User not found");
        return Err((StatusCode::UNAUTHORIZED, "Неверный логин или пароль".to_string()));
    }
    
    let user = user.unwrap();
    
    if !user.is_approved.unwrap_or(false) {
        info!("User not approved");
        return Err((StatusCode::FORBIDDEN, "Аккаунт не подтверждён администратором".to_string()));
    }
    
    let parsed_hash = match PasswordHash::new(&user.password_hash) {
        Ok(h) => h,
        Err(e) => {
            info!("Parse hash error: {}", e);
            return Err((StatusCode::INTERNAL_SERVER_ERROR, format!("Parse error: {}", e)));
        }
    };
    
    let valid = Argon2::default()
        .verify_password(req.password.as_bytes(), &parsed_hash)
        .is_ok();
    
    if !valid {
        info!("Invalid password");
        return Err((StatusCode::UNAUTHORIZED, "Неверный логин или пароль".to_string()));
    }
    
    info!("Login successful for user: {}", user.id);
    
    let jwt_secret = std::env::var("JWT_SECRET").unwrap_or_else(|_| "secret".to_string());
    let token = match encode(
        &Header::default(),
        &serde_json::json!({ "sub": user.id.to_string() }),
        &EncodingKey::from_secret(jwt_secret.as_bytes()),
    ) {
        Ok(t) => t,
        Err(e) => {
            info!("Token encode error: {}", e);
            return Err((StatusCode::INTERNAL_SERVER_ERROR, format!("Token error: {}", e)));
        }
    };
    
    Ok(Json(LoginResponse {
        token,
        user_id: user.id,
        surname: user.surname,
        name: user.name,
    }))
}