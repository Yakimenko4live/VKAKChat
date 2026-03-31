-- Таблица участников чатов
CREATE TABLE chat_participants (
    chat_id UUID NOT NULL,
    user_id UUID NOT NULL,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    PRIMARY KEY (chat_id, user_id),
    FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Индекс для поиска чатов пользователя
CREATE INDEX idx_chat_participants_user ON chat_participants(user_id);

COMMENT ON TABLE chat_participants IS 'Участники чатов';
