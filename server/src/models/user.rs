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
}

#[derive(Debug, Serialize)]
pub struct RegisterResponse {
    pub message: String,
    pub user_id: Uuid,
}