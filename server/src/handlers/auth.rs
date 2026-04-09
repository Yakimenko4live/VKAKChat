use axum::{
    extract::State,
    http::{Request, StatusCode},
    Json,
};
use jsonwebtoken::{decode, DecodingKey, Validation, encode, Header, EncodingKey};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use argon2::{
    password_hash::{PasswordHash, PasswordVerifier, rand_core::OsRng, PasswordHasher, SaltString},
    Argon2,
};
use tracing::info;

use crate::state::AppState;

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,
    pub exp: usize,
}

#[derive(Debug, Serialize)]
pub struct MeResponse {
    pub user_id: Uuid,
    pub surname: String,
    pub name: String,
    pub patronymic: Option<String>,
    pub department_name: Option<String>,
    pub comment: Option<String>,
    pub is_approved: bool,
    pub public_key: Option<String>,
    pub role: String,
}

#[derive(Debug, Deserialize)]
pub struct RegisterRequest {
    pub surname: String,
    pub name: String,
    pub patronymic: Option<String>,
    pub department_id: Uuid,
    pub comment: Option<String>,
    pub password: String,
    pub public_key: Option<String>,
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
    pub public_key: Option<String>,
    pub role: String,
}

pub async fn me(
    State(state): State<AppState>,
    req: Request<axum::body::Body>,
) -> Result<Json<MeResponse>, (StatusCode, String)> {
    
    let auth_header = req.headers()
        .get("authorization")
        .and_then(|h| h.to_str().ok())
        .ok_or((StatusCode::UNAUTHORIZED, "Требуется авторизация".to_string()))?;
    
    if !auth_header.starts_with("Bearer ") {
        return Err((StatusCode::UNAUTHORIZED, "Неверный формат токена".to_string()));
    }
    
    let token = &auth_header[7..];
    
    let jwt_secret = std::env::var("JWT_SECRET").unwrap_or_else(|_| "secret".to_string());
    
    let claims = decode::<Claims>(
        token,
        &DecodingKey::from_secret(jwt_secret.as_bytes()),
        &Validation::default(),
    )
    .map_err(|_| (StatusCode::UNAUTHORIZED, "Неверный токен".to_string()))?;
    
    let user_id = Uuid::parse_str(&claims.claims.sub)
        .map_err(|_| (StatusCode::UNAUTHORIZED, "Неверный ID пользователя".to_string()))?;
    
    let user = sqlx::query!(
        r#"
        SELECT u.id, u.surname, u.name, u.patronymic, u.comment, u.is_approved, u.public_key, u.role, d.name as department_name
        FROM users u
        LEFT JOIN departments d ON u.department_id = d.id
        WHERE u.id = $1
        "#,
        user_id
    )
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    let user = match user {
        Some(u) => u,
        None => return Err((StatusCode::NOT_FOUND, "Пользователь не найден".to_string())),
    };
    
    Ok(Json(MeResponse {
        user_id: user.id,
        surname: user.surname,
        name: user.name,
        patronymic: user.patronymic,
        department_name: Some(user.department_name),
        comment: user.comment,
        is_approved: user.is_approved.unwrap_or(false),
        public_key: user.public_key,
        role: user.role.unwrap_or_default(),
    }))
}

pub async fn register(
    State(state): State<AppState>,
    Json(req): Json<RegisterRequest>,
) -> Result<(StatusCode, Json<RegisterResponse>), (StatusCode, String)> {
    
    let department_exists: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM departments WHERE id = $1)"
    )
    .bind(req.department_id)
    .fetch_one(&state.pool)
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
        INSERT INTO users (id, surname, name, patronymic, department_id, comment, password_hash, is_approved, public_key)
        VALUES ($1, $2, $3, $4, $5, $6, $7, false, $8)
        "#
    )
    .bind(user_id)
    .bind(&req.surname)
    .bind(&req.name)
    .bind(&req.patronymic)
    .bind(req.department_id)
    .bind(&req.comment)
    .bind(&password_hash)
    .bind(&req.public_key)
    .execute(&state.pool)
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
    State(state): State<AppState>,
    Json(req): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, (StatusCode, String)> {
    
    info!("Login attempt for identifier: {}", req.identifier);
    
    let user = sqlx::query!(
        r#"
        SELECT id, surname, name, password_hash, is_approved, public_key, role
        FROM users
        WHERE surname || ' ' || name = $1 OR surname = $1 OR name = $1
        "#,
        req.identifier
    )
    .fetch_optional(&state.pool)
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
        &Claims { sub: user.id.to_string(), exp: 9999999999 },
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
        public_key: user.public_key,
        role: user.role.unwrap_or_default(),
    }))
}