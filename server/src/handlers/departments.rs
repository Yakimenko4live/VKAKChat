use axum::{
    extract::State,
    Json,
};
use sqlx::PgPool;

use crate::models::department::Department;

pub async fn get_departments(
    State(pool): State<PgPool>,
) -> Result<Json<Vec<Department>>, (axum::http::StatusCode, String)> {
    
    let departments = sqlx::query_as::<_, Department>(
        "SELECT id, name, level, parent_id FROM departments ORDER BY level, name"
    )
    .fetch_all(&pool)
    .await
    .map_err(|e| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e)))?;
    
    Ok(Json(departments))
}