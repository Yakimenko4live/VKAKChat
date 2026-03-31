-- Таблица избранных контактов
CREATE TABLE favorite_contacts (
    user_id UUID NOT NULL, -- пользователь, который добавляет в избранное
    contact_id UUID NOT NULL, -- пользователь, которого добавили в избранное
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    PRIMARY KEY (user_id, contact_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (contact_id) REFERENCES users(id) ON DELETE CASCADE,
    
    -- Нельзя добавить самого себя в избранное
    CHECK (user_id != contact_id)
);

-- Индекс для быстрого получения избранных контактов пользователя
CREATE INDEX idx_favorite_contacts_user ON favorite_contacts(user_id);

COMMENT ON TABLE favorite_contacts IS 'Избранные контакты пользователей';
COMMENT ON COLUMN favorite_contacts.user_id IS 'Пользователь, который добавил в избранное';
COMMENT ON COLUMN favorite_contacts.contact_id IS 'Пользователь, которого добавили в избранное';
