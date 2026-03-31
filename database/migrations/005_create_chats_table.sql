-- Таблица чатов (индивидуальные и групповые)
CREATE TABLE chats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(200), -- название для групповых чатов (для индивидуальных NULL)
    type VARCHAR(20) NOT NULL, -- 'private' или 'group'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Индекс для поиска по типу
CREATE INDEX idx_chats_type ON chats(type);

COMMENT ON TABLE chats IS 'Таблица чатов';
COMMENT ON COLUMN chats.type IS 'private - личный чат, group - групповой чат';
