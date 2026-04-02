use axum::{
    extract::{State, Query},
    http::StatusCode,
    Json,
};
use serde::{Deserialize, Serialize};
use sqlx::{PgPool, Row};
use uuid::Uuid;

#[derive(Debug, Serialize)]
pub struct UserSearchResult {
    pub id: Uuid,
    pub surname: String,
    pub name: String,
    pub patronymic: Option<String>,
    pub department_id: Uuid,
    pub department_name: String,
    pub comment: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct SearchQuery {
    pub q: Option<String>,
}

pub async fn search_users(
    State(pool): State<PgPool>,
    Query(query): Query<SearchQuery>,
) -> Result<Json<Vec<UserSearchResult>>, (StatusCode, String)> {
    
    let search_term = query.q.unwrap_or_default();
    
    let rows = if search_term.is_empty() {
        sqlx::query(
            r#"
            SELECT u.id, u.surname, u.name, u.patronymic, 
                   u.department_id, COALESCE(d.name, '') as department_name, u.comment
            FROM users u
            LEFT JOIN departments d ON u.department_id = d.id
            WHERE u.is_approved = true
            ORDER BY u.surname, u.name
            LIMIT 50
            "#
        )
        .fetch_all(&pool)
        .await
    } else {
        let search_pattern = format!("%{}%", search_term);
        sqlx::query(
            r#"
            SELECT u.id, u.surname, u.name, u.patronymic, 
                   u.department_id, COALESCE(d.name, '') as department_name, u.comment
            FROM users u
            LEFT JOIN departments d ON u.department_id = d.id
            WHERE u.is_approved = true 
              AND (u.surname ILIKE $1 
                   OR u.name ILIKE $1 
                   OR u.patronymic ILIKE $1
                   OR u.surname || ' ' || u.name ILIKE $1)
            ORDER BY u.surname, u.name
            LIMIT 50
            "#
        )
        .bind(search_pattern)
        .fetch_all(&pool)
        .await
    };
    
    match rows {
        Ok(rows) => {
            let users = rows.iter().map(|row| {
                UserSearchResult {
                    id: row.get("id"),
                    surname: row.get("surname"),
                    name: row.get("name"),
                    patronymic: row.get("patronymic"),
                    department_id: row.get("department_id"),
                    department_name: row.get("department_name"),
                    comment: row.get("comment"),
                }
            }).collect();
            Ok(Json(users))
        }
        Err(e) => Err((StatusCode::INTERNAL_SERVER_ERROR, format!("Database error: {}", e))),
    }
}