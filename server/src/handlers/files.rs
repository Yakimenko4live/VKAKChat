use axum::{
    extract::{State, Multipart, Path},
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde::Serialize;
use std::fs;
use std::io::Write;
use uuid::Uuid;

use crate::state::AppState;

#[derive(Debug, Serialize)]
pub struct UploadResponse {
    pub file_id: Uuid,
    pub filename: String,
    pub size: usize,
}

pub async fn upload_file(
    State(_state): State<AppState>,
    mut multipart: Multipart,
) -> Result<Json<UploadResponse>, (StatusCode, String)> {
    
    let mut chat_id_opt: Option<Uuid> = None;
    let mut filename = String::new();
    let mut file_data = Vec::new();
    
    loop {
        match multipart.next_field().await {
            Ok(Some(field)) => {
                let name = field.name().unwrap_or("").to_string();
                
                if name == "chat_id" {
                    match field.text().await {
                        Ok(text) => {
                            match Uuid::parse_str(&text) {
                                Ok(id) => chat_id_opt = Some(id),
                                Err(e) => return Err((StatusCode::BAD_REQUEST, format!("Invalid chat_id: {}", e))),
                            }
                        }
                        Err(e) => return Err((StatusCode::BAD_REQUEST, format!("Failed to read chat_id: {}", e))),
                    }
                } else if name == "filename" {
                    match field.text().await {
                        Ok(text) => filename = text,
                        Err(e) => return Err((StatusCode::BAD_REQUEST, format!("Failed to read filename: {}", e))),
                    }
                } else if name == "file" {
                    match field.bytes().await {
                        Ok(bytes) => file_data = bytes.to_vec(),
                        Err(e) => return Err((StatusCode::BAD_REQUEST, format!("Failed to read file: {}", e))),
                    }
                }
            }
            Ok(None) => break,
            Err(e) => return Err((StatusCode::BAD_REQUEST, format!("Multipart error: {}", e))),
        }
    }
    
    let chat_id = match chat_id_opt {
        Some(id) => id,
        None => return Err((StatusCode::BAD_REQUEST, "Missing chat_id".to_string())),
    };
    
    if file_data.is_empty() {
        return Err((StatusCode::BAD_REQUEST, "No file uploaded".to_string()));
    }
    
    if filename.is_empty() {
        filename = "unknown".to_string();
    }
    
    // Создаём папку для чата если не существует
    let chat_dir = format!("uploads/{}", chat_id);
    match fs::create_dir_all(&chat_dir) {
        Ok(_) => {},
        Err(e) => return Err((StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to create dir: {}", e))),
    }
    
    // Генерируем уникальное имя файла
    let file_uuid = Uuid::new_v4();
    let file_path = format!("{}/{}.encrypted", chat_dir, file_uuid);
    
    // Сохраняем зашифрованный файл
    match fs::write(&file_path, &file_data) {
        Ok(_) => {},
        Err(e) => return Err((StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to save file: {}", e))),
    }
    
    Ok(Json(UploadResponse {
        file_id: file_uuid,
        filename,
        size: file_data.len(),
    }))
}

pub async fn download_file(
    Path((chat_id, file_id)): Path<(Uuid, Uuid)>,
) -> Response {
    let file_path = format!("uploads/{}/{}.encrypted", chat_id, file_id);
    
    match fs::read(&file_path) {
        Ok(data) => (StatusCode::OK, data).into_response(),
        Err(e) => (StatusCode::NOT_FOUND, format!("File not found: {}", e)).into_response(),
    }
}