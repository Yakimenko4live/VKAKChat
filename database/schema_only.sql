--
-- PostgreSQL database dump
--

\restrict tZoe86guI3kjydIJcyoqTofcmb1WhFWXxCeZR5o8bg9eQ1oOYoTCFEnhlFfqk6M

-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: chat_participants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_participants (
    chat_id uuid NOT NULL,
    user_id uuid NOT NULL,
    joined_at timestamp with time zone DEFAULT now(),
    encrypted_private_key text
);


--
-- Name: TABLE chat_participants; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.chat_participants IS 'Участники чатов';


--
-- Name: chats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chats (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title character varying(200),
    type character varying(20) NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    creator_id uuid,
    is_group boolean DEFAULT false,
    group_public_key text
);


--
-- Name: TABLE chats; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.chats IS 'Таблица чатов';


--
-- Name: COLUMN chats.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.chats.type IS 'private - личный чат, group - групповой чат';


--
-- Name: departments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(200) NOT NULL,
    level integer NOT NULL,
    parent_id uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: TABLE departments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.departments IS 'Структура отделов организации';


--
-- Name: COLUMN departments.level; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.departments.level IS '1=Окружной, 2=Субъектовый, 3=Местный';


--
-- Name: COLUMN departments.parent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.departments.parent_id IS 'Ссылка на вышестоящий отдел';


--
-- Name: favorite_contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.favorite_contacts (
    user_id uuid NOT NULL,
    contact_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT favorite_contacts_check CHECK ((user_id <> contact_id))
);


--
-- Name: TABLE favorite_contacts; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.favorite_contacts IS 'Избранные контакты пользователей';


--
-- Name: COLUMN favorite_contacts.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.favorite_contacts.user_id IS 'Пользователь, который добавил в избранное';


--
-- Name: COLUMN favorite_contacts.contact_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.favorite_contacts.contact_id IS 'Пользователь, которого добавили в избранное';


--
-- Name: group_admins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_admins (
    group_id uuid NOT NULL,
    user_id uuid NOT NULL
);


--
-- Name: group_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_keys (
    group_id uuid NOT NULL,
    user_id uuid NOT NULL,
    encrypted_key text NOT NULL
);


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    chat_id uuid NOT NULL,
    sender_id uuid NOT NULL,
    content text NOT NULL,
    is_read boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    surname character varying(100) NOT NULL,
    name character varying(100) NOT NULL,
    patronymic character varying(100),
    department_id uuid,
    comment text,
    password_hash character varying(255) NOT NULL,
    is_approved boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    public_key text,
    role character varying(20) DEFAULT 'user'::character varying,
    fcm_token text
);


--
-- Name: COLUMN users.department_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.users.department_id IS 'Ссылка на отдел пользователя';


--
-- Name: web_push_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.web_push_subscriptions (
    user_id uuid NOT NULL,
    subscription text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: chat_participants chat_participants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_participants
    ADD CONSTRAINT chat_participants_pkey PRIMARY KEY (chat_id, user_id);


--
-- Name: chats chats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chats
    ADD CONSTRAINT chats_pkey PRIMARY KEY (id);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- Name: favorite_contacts favorite_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorite_contacts
    ADD CONSTRAINT favorite_contacts_pkey PRIMARY KEY (user_id, contact_id);


--
-- Name: group_admins group_admins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_admins
    ADD CONSTRAINT group_admins_pkey PRIMARY KEY (group_id, user_id);


--
-- Name: group_keys group_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_keys
    ADD CONSTRAINT group_keys_pkey PRIMARY KEY (group_id, user_id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: web_push_subscriptions web_push_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_push_subscriptions
    ADD CONSTRAINT web_push_subscriptions_pkey PRIMARY KEY (user_id);


--
-- Name: idx_chat_participants_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chat_participants_user ON public.chat_participants USING btree (user_id);


--
-- Name: idx_chats_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chats_type ON public.chats USING btree (type);


--
-- Name: idx_departments_level; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_departments_level ON public.departments USING btree (level);


--
-- Name: idx_departments_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_departments_parent ON public.departments USING btree (parent_id);


--
-- Name: idx_favorite_contacts_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_favorite_contacts_user ON public.favorite_contacts USING btree (user_id);


--
-- Name: idx_messages_chat; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_chat ON public.messages USING btree (chat_id);


--
-- Name: idx_messages_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_created ON public.messages USING btree (created_at);


--
-- Name: idx_users_approved; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_approved ON public.users USING btree (is_approved) WHERE (is_approved = false);


--
-- Name: idx_users_department; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_department ON public.users USING btree (department_id);


--
-- Name: idx_users_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_name ON public.users USING btree (surname, name, patronymic);


--
-- Name: chat_participants chat_participants_chat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_participants
    ADD CONSTRAINT chat_participants_chat_id_fkey FOREIGN KEY (chat_id) REFERENCES public.chats(id) ON DELETE CASCADE;


--
-- Name: chat_participants chat_participants_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_participants
    ADD CONSTRAINT chat_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: chats chats_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chats
    ADD CONSTRAINT chats_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: departments departments_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.departments(id) ON DELETE CASCADE;


--
-- Name: favorite_contacts favorite_contacts_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorite_contacts
    ADD CONSTRAINT favorite_contacts_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: favorite_contacts favorite_contacts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorite_contacts
    ADD CONSTRAINT favorite_contacts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users fk_users_department; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_users_department FOREIGN KEY (department_id) REFERENCES public.departments(id);


--
-- Name: group_admins group_admins_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_admins
    ADD CONSTRAINT group_admins_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.chats(id) ON DELETE CASCADE;


--
-- Name: group_admins group_admins_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_admins
    ADD CONSTRAINT group_admins_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: group_keys group_keys_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_keys
    ADD CONSTRAINT group_keys_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.chats(id) ON DELETE CASCADE;


--
-- Name: group_keys group_keys_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_keys
    ADD CONSTRAINT group_keys_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: messages messages_chat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_chat_id_fkey FOREIGN KEY (chat_id) REFERENCES public.chats(id) ON DELETE CASCADE;


--
-- Name: messages messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: web_push_subscriptions web_push_subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_push_subscriptions
    ADD CONSTRAINT web_push_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict tZoe86guI3kjydIJcyoqTofcmb1WhFWXxCeZR5o8bg9eQ1oOYoTCFEnhlFfqk6M

