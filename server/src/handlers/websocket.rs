use axum::{
    extract::ws::{WebSocket, WebSocketUpgrade},
    response::Response,
};
use tracing::info;

pub async fn websocket_handler(ws: WebSocketUpgrade) -> Response {
    ws.on_upgrade(handle_socket)
}

async fn handle_socket(mut socket: WebSocket) {
    info!("WebSocket connected");
    
    while let Some(msg) = socket.recv().await {
        let msg = match msg {
            Ok(msg) => msg,
            Err(e) => {
                info!("Error receiving message: {}", e);
                break;
            }
        };
        
        if socket.send(msg).await.is_err() {
            break;
        }
    }
    
    info!("WebSocket disconnected");
}
