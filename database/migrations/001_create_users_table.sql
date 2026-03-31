-- Таблица пользователей
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    surname VARCHAR(100) NOT NULL,
    name VARCHAR(100) NOT NULL,
    patronymic VARCHAR(100),
    department_id UUID, -- связь с отделами, пока временно NULL
    comment TEXT,
    password_hash VARCHAR(255) NOT NULL,
    is_approved BOOLEAN DEFAULT FALSE, -- подтверждён ли администратором
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Индекс для поиска по ФИО
CREATE INDEX idx_users_name ON users (surname, name, patronymic);

-- Индекс для неподтверждённых пользователей
CREATE INDEX idx_users_approved ON users (is_approved) WHERE is_approved = FALSE;
