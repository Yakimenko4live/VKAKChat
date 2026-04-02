use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::{Mutex, broadcast};
use uuid::Uuid;

pub type RoomMap = Arc<Mutex<HashMap<Uuid, broadcast::Sender<String>>>>;

#[derive(Clone)]
pub struct AppState {
    pub pool: sqlx::PgPool,
    pub rooms: RoomMap,
}

impl AppState {
    pub fn new(pool: sqlx::PgPool) -> Self {
        Self {
            pool,
            rooms: Arc::new(Mutex::new(HashMap::new())),
        }
    }
}