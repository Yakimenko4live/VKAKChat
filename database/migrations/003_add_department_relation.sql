-- Добавляем внешний ключ для связи с отделами
ALTER TABLE users 
ADD CONSTRAINT fk_users_department 
FOREIGN KEY (department_id) REFERENCES departments(id);

-- Индекс для связи
CREATE INDEX idx_users_department ON users(department_id);

COMMENT ON COLUMN users.department_id IS 'Ссылка на отдел пользователя';
