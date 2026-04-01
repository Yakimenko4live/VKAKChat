use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize, FromRow)]
pub struct Department {
    pub id: Uuid,
    pub name: String,
    pub level: i32,
    pub parent_id: Option<Uuid>,
}