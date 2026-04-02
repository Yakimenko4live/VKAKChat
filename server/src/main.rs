use axum::{
    http::{HeaderValue, Request},
    response::Response,
    routing::get,
    Router,
};
use sqlx::postgres::{PgPoolOptions, PgConnectOptions};
use std::{env, net::SocketAddr};
use tower::ServiceBuilder;
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;

mod handlers;
mod models;

async fn utf8_middleware(
    req: Request<axum::body::Body>,
    next: axum::middleware::Next,
) -> Response {
    let mut response = next.run(req).await;
    
    // Удаляем старый заголовок, если он есть, и ставим свой
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
    
    // Используем PgConnectOptions для более точной настройки
    let options = database_url.parse::<PgConnectOptions>()?;
    
    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect_with(options)
        .await?;
    
    // Принудительно устанавливаем UTF-8 для соединения
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
    
    // Проверяем вывод отдела
    let test_dept: Option<String> = sqlx::query_scalar("SELECT name FROM departments LIMIT 1")
        .fetch_one(&pool)
        .await?;
    println!("🔍 Тестовый отдел из БД: {:?}", test_dept);
    
    // CORS для веб-клиента
    let cors = CorsLayer::permissive()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);
    
let app = Router::new()
    .route("/health", get(handlers::health::health_check))
    .route("/ws", get(handlers::websocket::websocket_handler))
    .route("/api/departments", get(handlers::departments::get_departments))
    .route("/api/register", axum::routing::post(handlers::auth::register))
    .route("/api/login", axum::routing::post(handlers::auth::login))
    .route("/api/me", axum::routing::get(handlers::auth::me))
    .route("/api/users/search", get(handlers::users::search_users))
    .route("/api/departments/tree", get(handlers::departments::get_department_tree))
    .layer(ServiceBuilder::new().layer(axum::middleware::from_fn(utf8_middleware)))
    .layer(cors)
    .layer(TraceLayer::new_for_http())
    .with_state(pool);
    
    let addr: SocketAddr = "0.0.0.0:3000".parse()?;
    println!("🚀 Server running on http://{}", addr);
    println!("🔌 WebSocket available at ws://{}/ws", addr);
    
    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;
    
    Ok(())
}