-- Таблица отделов с иерархической структурой
CREATE TABLE departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL, -- название отдела
    level INTEGER NOT NULL, -- 1=Окружной, 2=Субъектовый, 3=Местный
    parent_id UUID, -- ссылка на вышестоящий отдел (NULL для окружных)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- внешний ключ для иерархии
    FOREIGN KEY (parent_id) REFERENCES departments(id) ON DELETE CASCADE
);

-- индексы для быстрого поиска
CREATE INDEX idx_departments_level ON departments(level);
CREATE INDEX idx_departments_parent ON departments(parent_id);

-- комментарии к таблице и полям (на русском)
COMMENT ON TABLE departments IS 'Структура отделов организации';
COMMENT ON COLUMN departments.level IS '1=Окружной, 2=Субъектовый, 3=Местный';
COMMENT ON COLUMN departments.parent_id IS 'Ссылка на вышестоящий отдел';
