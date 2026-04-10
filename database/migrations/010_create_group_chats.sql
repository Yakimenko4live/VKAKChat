-- Таблица групповых чатов (расширяет chats)
ALTER TABLE chats ADD COLUMN creator_id UUID REFERENCES users(id);
ALTER TABLE chats ADD COLUMN is_group BOOLEAN DEFAULT FALSE;

-- Таблица для управления админами групповых чатов
CREATE TABLE group_admins (
    group_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (group_id, user_id)
);

-- Общий ключ для группы (шифрование)
ALTER TABLE chats ADD COLUMN group_public_key TEXT;
ALTER TABLE chat_participants ADD COLUMN encrypted_private_key TEXT;