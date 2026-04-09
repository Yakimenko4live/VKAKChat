use serde::{Deserialize, Serialize};
use uuid::Uuid;

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

#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub token: String,
    pub user_id: Uuid,
    pub surname: String,
    pub name: String,
    pub patronymic: Option<String>,
    pub department_name: Option<String>,
    pub is_approved: bool,
    pub public_key: Option<String>,
    pub role: String,  // Добавить
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
    pub role: String,  // Добавить
}