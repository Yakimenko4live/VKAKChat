use axum::{routing::get, Router};
use sqlx::postgres::PgPoolOptions;
use std::{env, net::SocketAddr};

mod handlers;

async fn health() -> &'static str {
    "OK"
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenvy::dotenv().ok();

    tracing_subscriber::fmt::init();

    let database_url = env::var("DATABASE_URL")?;
    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await?;

    let result: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users")
        .fetch_one(&pool)
        .await?;

    println!("✅ Подключение к БД успешно!");
    println!("📊 В таблице users: {} записей", result.0);

    let app = Router::new()
        .route("/health", get(health))
        .route("/ws", get(handlers::websocket::websocket_handler));

    let addr: SocketAddr = "0.0.0.0:3000".parse()?;
    println!("🚀 Server running on http://{}", addr);
    println!("🔌 WebSocket available at ws://{}/ws", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}
