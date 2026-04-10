use axum::{
    http::{HeaderValue, Request},
    response::Response,
    routing::{get, post, delete, put},
    Router,
};
use sqlx::postgres::{PgConnectOptions, PgPoolOptions};
use std::{env, net::SocketAddr};
use tower::ServiceBuilder;
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;

mod handlers;
mod middleware;
mod state;

use crate::middleware::auth::auth_middleware;
use crate::state::AppState;

async fn utf8_middleware(
    req: Request<axum::body::Body>,
    next: axum::middleware::Next,
) -> Response {
    let mut response = next.run(req).await;
    response.headers_mut().insert(
        axum::http::header::CONTENT_TYPE,
        HeaderValue::from_static("application/json; charset=utf-8"),
    );
    response
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenvy::dotenv().ok();
    
    tracing_subscriber::fmt::init();
    
    let database_url = env::var("DATABASE_URL")?;
    
    let options = database_url.parse::<PgConnectOptions>()?;
    
    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect_with(options)
        .await?;
    
    sqlx::query("SET client_encoding = 'UTF8'")
        .execute(&pool)
        .await?;
    
    sqlx::query("SET standard_conforming_strings = on")
        .execute(&pool)
        .await?;
    
    let result: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users")
        .fetch_one(&pool)
        .await?;
    
    println!("✅ Подключение к БД успешно!");
    println!("📊 В таблице users: {} записей", result.0);
    
    let test_dept: Option<String> = sqlx::query_scalar("SELECT name FROM departments LIMIT 1")
        .fetch_one(&pool)
        .await?;
    println!("🔍 Тестовый отдел из БД: {:?}", test_dept);
    
    let cors = CorsLayer::permissive()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);
    
    let app_state = AppState::new(pool);
    
let protected_routes = Router::new()
    .route("/api/chats", get(handlers::chats::get_user_chats))
    .route("/api/chats/create", post(handlers::chats::get_or_create_chat))
    .route("/api/chats/:chat_id/messages", get(handlers::chats::get_chat_messages))
    .route("/api/messages/send", post(handlers::chats::send_message))
    .route("/api/users/search", get(handlers::users::search_users))
    .route("/api/departments/tree", get(handlers::departments::get_department_tree))
    .route("/api/users/:user_id/public_key", get(handlers::chats::get_user_public_key))
    .route("/api/admin/pending", get(handlers::admin::get_pending_users))
    .route("/api/admin/approve/:user_id", post(handlers::admin::approve_user))
    .route("/api/admin/reject/:user_id", delete(handlers::admin::reject_user))
    .route("/api/groups/create", post(handlers::groups::create_group))
    .route("/api/groups", get(handlers::groups::get_user_groups))
    .route("/api/groups/:group_id", get(handlers::groups::get_group))
    .route("/api/groups/:group_id/add", post(handlers::groups::add_participants))
    .route("/api/groups/:group_id/remove/:user_id", delete(handlers::groups::remove_participant))
    .route("/api/groups/:group_id/leave", post(handlers::groups::leave_group))
    .route("/api/groups/:group_id/key", get(handlers::groups::get_group_key))
    .layer(axum::middleware::from_fn(auth_middleware));
    
let app = Router::new()
    .route("/health", get(handlers::health::health_check))
    .route("/ws", get(handlers::websocket::websocket_handler))
    .route("/api/departments", get(handlers::departments::get_departments))
    .route("/api/register", post(handlers::auth::register))
    .route("/api/login", post(handlers::auth::login))
    .route("/api/me", get(handlers::auth::me))
    .route("/api/me/update", put(handlers::auth::update_profile))
    .route("/api/change-password", post(handlers::auth::change_password))
    .route("/api/files/upload", post(handlers::files::upload_file))
    .route("/api/files/download/:chat_id/:file_id", get(handlers::files::download_file))
    // .route("/api/groups/create", post(handlers::groups::create_group))
    // .route("/api/groups", get(handlers::groups::get_user_groups))
    // .route("/api/groups/:group_id", get(handlers::groups::get_group))
    // .route("/api/groups/:group_id/add", post(handlers::groups::add_participants))
    // .route("/api/groups/:group_id/remove/:user_id", delete(handlers::groups::remove_participant))
    // .route("/api/groups/:group_id/leave", post(handlers::groups::leave_group))
    // .route("/api/groups/:group_id/key", get(handlers::groups::get_group_key))
    .nest("/", protected_routes)
    .layer(ServiceBuilder::new().layer(axum::middleware::from_fn(utf8_middleware)))
    .layer(cors)
    .layer(TraceLayer::new_for_http())
    .with_state(app_state);
    
    let addr: SocketAddr = "0.0.0.0:3000".parse()?;
    println!("🚀 Server running on http://{}", addr);
    println!("🔌 WebSocket available at ws://{}/ws", addr);
    
    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;
    
    Ok(())
}