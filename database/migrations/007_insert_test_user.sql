-- Добавляем тестового пользователя (пароль: test123)
-- Пароль пока в открытом виде, позже заменим на хеш
INSERT INTO users (id, surname, name, patronymic, department_id, comment, password_hash, is_approved) VALUES 
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 
 'Иванов', 
 'Иван', 
 'Иванович',
 '33333333-3333-3333-3333-333333333333', -- Московский городской отдел
 'Учет сотрудников',
 'test123', -- временно, позже добавим хеширование
 false
);
