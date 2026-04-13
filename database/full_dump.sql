--
-- PostgreSQL database dump
--

\restrict 9odwSUCTRZUVwGLbjzvWrQmhPPhhoXdEK8i5NVNZXGdvSbYzGtiSYaenmgM1BQ9

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

ALTER TABLE IF EXISTS ONLY public.messages DROP CONSTRAINT IF EXISTS messages_sender_id_fkey;
ALTER TABLE IF EXISTS ONLY public.messages DROP CONSTRAINT IF EXISTS messages_chat_id_fkey;
ALTER TABLE IF EXISTS ONLY public.group_keys DROP CONSTRAINT IF EXISTS group_keys_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.group_keys DROP CONSTRAINT IF EXISTS group_keys_group_id_fkey;
ALTER TABLE IF EXISTS ONLY public.group_admins DROP CONSTRAINT IF EXISTS group_admins_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.group_admins DROP CONSTRAINT IF EXISTS group_admins_group_id_fkey;
ALTER TABLE IF EXISTS ONLY public.users DROP CONSTRAINT IF EXISTS fk_users_department;
ALTER TABLE IF EXISTS ONLY public.favorite_contacts DROP CONSTRAINT IF EXISTS favorite_contacts_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.favorite_contacts DROP CONSTRAINT IF EXISTS favorite_contacts_contact_id_fkey;
ALTER TABLE IF EXISTS ONLY public.departments DROP CONSTRAINT IF EXISTS departments_parent_id_fkey;
ALTER TABLE IF EXISTS ONLY public.chats DROP CONSTRAINT IF EXISTS chats_creator_id_fkey;
ALTER TABLE IF EXISTS ONLY public.chat_participants DROP CONSTRAINT IF EXISTS chat_participants_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.chat_participants DROP CONSTRAINT IF EXISTS chat_participants_chat_id_fkey;
DROP INDEX IF EXISTS public.idx_users_name;
DROP INDEX IF EXISTS public.idx_users_department;
DROP INDEX IF EXISTS public.idx_users_approved;
DROP INDEX IF EXISTS public.idx_messages_created;
DROP INDEX IF EXISTS public.idx_messages_chat;
DROP INDEX IF EXISTS public.idx_favorite_contacts_user;
DROP INDEX IF EXISTS public.idx_departments_parent;
DROP INDEX IF EXISTS public.idx_departments_level;
DROP INDEX IF EXISTS public.idx_chats_type;
DROP INDEX IF EXISTS public.idx_chat_participants_user;
ALTER TABLE IF EXISTS ONLY public.users DROP CONSTRAINT IF EXISTS users_pkey;
ALTER TABLE IF EXISTS ONLY public.messages DROP CONSTRAINT IF EXISTS messages_pkey;
ALTER TABLE IF EXISTS ONLY public.group_keys DROP CONSTRAINT IF EXISTS group_keys_pkey;
ALTER TABLE IF EXISTS ONLY public.group_admins DROP CONSTRAINT IF EXISTS group_admins_pkey;
ALTER TABLE IF EXISTS ONLY public.favorite_contacts DROP CONSTRAINT IF EXISTS favorite_contacts_pkey;
ALTER TABLE IF EXISTS ONLY public.departments DROP CONSTRAINT IF EXISTS departments_pkey;
ALTER TABLE IF EXISTS ONLY public.chats DROP CONSTRAINT IF EXISTS chats_pkey;
ALTER TABLE IF EXISTS ONLY public.chat_participants DROP CONSTRAINT IF EXISTS chat_participants_pkey;
DROP TABLE IF EXISTS public.users;
DROP TABLE IF EXISTS public.messages;
DROP TABLE IF EXISTS public.group_keys;
DROP TABLE IF EXISTS public.group_admins;
DROP TABLE IF EXISTS public.favorite_contacts;
DROP TABLE IF EXISTS public.departments;
DROP TABLE IF EXISTS public.chats;
DROP TABLE IF EXISTS public.chat_participants;
SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: chat_participants; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.chat_participants (
    chat_id uuid NOT NULL,
    user_id uuid NOT NULL,
    joined_at timestamp with time zone DEFAULT now(),
    encrypted_private_key text
);


ALTER TABLE public.chat_participants OWNER TO postgres;

--
-- Name: TABLE chat_participants; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.chat_participants IS 'Участники чатов';


--
-- Name: chats; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.chats OWNER TO postgres;

--
-- Name: TABLE chats; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.chats IS 'Таблица чатов';


--
-- Name: COLUMN chats.type; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.chats.type IS 'private - личный чат, group - групповой чат';


--
-- Name: departments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.departments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(200) NOT NULL,
    level integer NOT NULL,
    parent_id uuid,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.departments OWNER TO postgres;

--
-- Name: TABLE departments; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.departments IS 'Структура отделов организации';


--
-- Name: COLUMN departments.level; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.departments.level IS '1=Окружной, 2=Субъектовый, 3=Местный';


--
-- Name: COLUMN departments.parent_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.departments.parent_id IS 'Ссылка на вышестоящий отдел';


--
-- Name: favorite_contacts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.favorite_contacts (
    user_id uuid NOT NULL,
    contact_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT favorite_contacts_check CHECK ((user_id <> contact_id))
);


ALTER TABLE public.favorite_contacts OWNER TO postgres;

--
-- Name: TABLE favorite_contacts; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.favorite_contacts IS 'Избранные контакты пользователей';


--
-- Name: COLUMN favorite_contacts.user_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.favorite_contacts.user_id IS 'Пользователь, который добавил в избранное';


--
-- Name: COLUMN favorite_contacts.contact_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.favorite_contacts.contact_id IS 'Пользователь, которого добавили в избранное';


--
-- Name: group_admins; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.group_admins (
    group_id uuid NOT NULL,
    user_id uuid NOT NULL
);


ALTER TABLE public.group_admins OWNER TO postgres;

--
-- Name: group_keys; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.group_keys (
    group_id uuid NOT NULL,
    user_id uuid NOT NULL,
    encrypted_key text NOT NULL
);


ALTER TABLE public.group_keys OWNER TO postgres;

--
-- Name: messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    chat_id uuid NOT NULL,
    sender_id uuid NOT NULL,
    content text NOT NULL,
    is_read boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.messages OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
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
    role character varying(20) DEFAULT 'user'::character varying
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: COLUMN users.department_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.users.department_id IS 'Ссылка на отдел пользователя';


--
-- Data for Name: chat_participants; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.chat_participants (chat_id, user_id, joined_at, encrypted_private_key) FROM stdin;
dbb843dc-b8a7-4fa3-9bed-45c83a1a2f62	052fe3e1-d60a-40f7-af4c-3879478a665a	2026-04-11 15:38:21.912822+07	\N
dbb843dc-b8a7-4fa3-9bed-45c83a1a2f62	02ceda99-6da3-480d-8fec-8e80e82706b5	2026-04-11 15:38:21.933706+07	\N
d584d70f-3c3e-4d59-aa52-d7e952e09606	c857e7a4-6624-44ef-99cc-f796cdb90c7b	2026-04-11 15:51:23.139078+07	\N
d584d70f-3c3e-4d59-aa52-d7e952e09606	052fe3e1-d60a-40f7-af4c-3879478a665a	2026-04-11 15:51:23.169179+07	\N
1da00278-6c7b-477b-a9ce-2946967c9205	c857e7a4-6624-44ef-99cc-f796cdb90c7b	2026-04-11 16:00:41.007259+07	\N
1da00278-6c7b-477b-a9ce-2946967c9205	052fe3e1-d60a-40f7-af4c-3879478a665a	2026-04-11 16:00:41.018406+07	\N
\.


--
-- Data for Name: chats; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.chats (id, title, type, created_at, updated_at, creator_id, is_group, group_public_key) FROM stdin;
dbb843dc-b8a7-4fa3-9bed-45c83a1a2f62	\N	private	2026-04-11 15:38:21.905287+07	2026-04-11 15:38:27.202223+07	\N	f	\N
d584d70f-3c3e-4d59-aa52-d7e952e09606	\N	private	2026-04-11 15:51:23.13351+07	2026-04-11 15:53:09.478417+07	\N	f	\N
1da00278-6c7b-477b-a9ce-2946967c9205	1	group	2026-04-11 16:00:40.729424+07	2026-04-11 16:04:49.620456+07	052fe3e1-d60a-40f7-af4c-3879478a665a	t	\N
\.


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.departments (id, name, level, parent_id, created_at) FROM stdin;
11111111-1111-1111-1111-111111111111	Центральный окружной отдел	1	\N	2026-03-31 23:42:13.455775+07
22222222-2222-2222-2222-222222222222	Московский областной отдел	2	11111111-1111-1111-1111-111111111111	2026-03-31 23:42:13.497377+07
22222222-2222-2222-2222-222222222223	Санкт-Петербургский областной отдел	2	11111111-1111-1111-1111-111111111111	2026-03-31 23:42:13.497377+07
33333333-3333-3333-3333-333333333333	Московский городской отдел	3	22222222-2222-2222-2222-222222222222	2026-03-31 23:42:13.502337+07
33333333-3333-3333-3333-333333333334	Подольский отдел	3	22222222-2222-2222-2222-222222222222	2026-03-31 23:42:13.502337+07
33333333-3333-3333-3333-333333333335	Коломенский отдел	3	22222222-2222-2222-2222-222222222222	2026-03-31 23:42:13.502337+07
33333333-3333-3333-3333-333333333336	Санкт-Петербургский городской отдел	3	22222222-2222-2222-2222-222222222223	2026-03-31 23:42:13.502337+07
\.


--
-- Data for Name: favorite_contacts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.favorite_contacts (user_id, contact_id, created_at) FROM stdin;
\.


--
-- Data for Name: group_admins; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.group_admins (group_id, user_id) FROM stdin;
1da00278-6c7b-477b-a9ce-2946967c9205	052fe3e1-d60a-40f7-af4c-3879478a665a
\.


--
-- Data for Name: group_keys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.group_keys (group_id, user_id, encrypted_key) FROM stdin;
1da00278-6c7b-477b-a9ce-2946967c9205	c857e7a4-6624-44ef-99cc-f796cdb90c7b	u7wcYy+C0PjcFI0xJrcIQMBxx6zJ/Q1G0fVFh2++F7t7pdKr6pchS/EUNRSVjVzSPCXSbH2lw5MPjjYrvOLO0A==
1da00278-6c7b-477b-a9ce-2946967c9205	052fe3e1-d60a-40f7-af4c-3879478a665a	gB96P0Uvo/yjKUJ/BS8nBsX4ZeBMU1n6Fu2/3ZoPg1vyJnNYJ/0buRo7T7gg4AVDX9nQD6lcRpv2qSvkr5X/OA==
\.


--
-- Data for Name: messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.messages (id, chat_id, sender_id, content, is_read, created_at) FROM stdin;
7f64b9ba-8273-485f-862b-18ec5c72eca5	dbb843dc-b8a7-4fa3-9bed-45c83a1a2f62	052fe3e1-d60a-40f7-af4c-3879478a665a	zOtN1jzj68XvYvNEa/VfNajnG6f9HIFnmdN3hHYpGt8=	f	2026-04-11 15:38:27.177264+07
41d2c601-fb26-4b6d-b502-4aa59656aeea	d584d70f-3c3e-4d59-aa52-d7e952e09606	c857e7a4-6624-44ef-99cc-f796cdb90c7b	fjpGvpyn8+JEiYfJVooBTUB6ygDzkUl0zHNym49VZYE=	f	2026-04-11 15:51:28.723618+07
dbbbf1f6-377a-40d4-bb57-763381a6f4f4	d584d70f-3c3e-4d59-aa52-d7e952e09606	052fe3e1-d60a-40f7-af4c-3879478a665a	xHmnZaU/GxYEsxbNIyfFHTVWkBPES4cgpaUQwXo0/c0=	f	2026-04-11 15:51:51.804031+07
05abf0a2-788a-4d29-a00e-7294c9b6e160	d584d70f-3c3e-4d59-aa52-d7e952e09606	052fe3e1-d60a-40f7-af4c-3879478a665a	{"type":"image","data":{"file_id":"9c0c983a-5659-4962-b7ae-fa1c5ef4e3cb","filename":"hero1.png","size":1201119,"mime_type":"image/png"}}	f	2026-04-11 15:53:08.367432+07
9b600613-19ad-4500-b2ba-d02491b9fa8f	1da00278-6c7b-477b-a9ce-2946967c9205	052fe3e1-d60a-40f7-af4c-3879478a665a	Fz+zKLeNJyOH1YQuTD6W6T67IB+e/HTB3g2ETCzllnY=	f	2026-04-11 16:00:54.469574+07
0ab0d191-cbb5-4aa5-9adb-deb9041d725a	1da00278-6c7b-477b-a9ce-2946967c9205	052fe3e1-d60a-40f7-af4c-3879478a665a	ZtlClfQx4aLpAhAk60CFUbmx3iTp0ldAzrGRZ5UBeWM=	f	2026-04-11 16:04:49.353166+07
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, surname, name, patronymic, department_id, comment, password_hash, is_approved, created_at, updated_at, public_key, role) FROM stdin;
02ceda99-6da3-480d-8fec-8e80e82706b5	Я	Я	Я	11111111-1111-1111-1111-111111111111	Я	$argon2id$v=19$m=19456,t=2,p=1$6sUiUhGrIfCHl7nkl7eYMw$hTuGH5EPmwvA3OuyWsZZroiWPMLrwJzeC0knWlgFxGI	t	2026-04-11 15:31:26.490888+07	2026-04-11 15:31:26.490888+07	043bbf6685a7eafa99a9fe7806b329c72688eed5b43e00d4a694b8756450ba4dc16b1ae91489e9bd20bcd6cee84b39c33fe5396681cb006da31e8c1db0f9077c2c	super_admin
c857e7a4-6624-44ef-99cc-f796cdb90c7b	Й	Й	Й	11111111-1111-1111-1111-111111111111	Й	$argon2id$v=19$m=19456,t=2,p=1$ecpbeq8z29bHncya15dEbg$oXcp6JCLV6rxkKMXXNSyeNF+FCJruigXdCzaJyQmtG0	t	2026-04-11 15:50:37.804128+07	2026-04-11 15:50:37.804128+07	04c74bd401daebd60cbd90b9095d1e949372e31b64c905f6b31b8760f3f37bf5a2c95b4e3a88aa082a3426b27066729230c2d77d0bf10134b0ceebfd5cd960fb74	user
052fe3e1-d60a-40f7-af4c-3879478a665a	Ф	Ф	Ф	11111111-1111-1111-1111-111111111111	Ф	$argon2id$v=19$m=19456,t=2,p=1$IHzi8YP7iK5eZqCbkGUisQ$aOfdeLAFQHR1JJX6SRbheWCw5blc4mFfrdAjhS9z5qQ	t	2026-04-11 15:37:35.915097+07	2026-04-11 15:37:35.915097+07	04dc268b9794abfb235cbbde441afaf7ec0d5ba6da651275e5fdcdc270974f358cf4cb4c04728d788498f4d6a737df97fe9594be0ab0145832f6af52d5009721be	super_admin
\.


--
-- Name: chat_participants chat_participants_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chat_participants
    ADD CONSTRAINT chat_participants_pkey PRIMARY KEY (chat_id, user_id);


--
-- Name: chats chats_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chats
    ADD CONSTRAINT chats_pkey PRIMARY KEY (id);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- Name: favorite_contacts favorite_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favorite_contacts
    ADD CONSTRAINT favorite_contacts_pkey PRIMARY KEY (user_id, contact_id);


--
-- Name: group_admins group_admins_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_admins
    ADD CONSTRAINT group_admins_pkey PRIMARY KEY (group_id, user_id);


--
-- Name: group_keys group_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_keys
    ADD CONSTRAINT group_keys_pkey PRIMARY KEY (group_id, user_id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_chat_participants_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_chat_participants_user ON public.chat_participants USING btree (user_id);


--
-- Name: idx_chats_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_chats_type ON public.chats USING btree (type);


--
-- Name: idx_departments_level; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_departments_level ON public.departments USING btree (level);


--
-- Name: idx_departments_parent; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_departments_parent ON public.departments USING btree (parent_id);


--
-- Name: idx_favorite_contacts_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_favorite_contacts_user ON public.favorite_contacts USING btree (user_id);


--
-- Name: idx_messages_chat; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_messages_chat ON public.messages USING btree (chat_id);


--
-- Name: idx_messages_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_messages_created ON public.messages USING btree (created_at);


--
-- Name: idx_users_approved; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_approved ON public.users USING btree (is_approved) WHERE (is_approved = false);


--
-- Name: idx_users_department; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_department ON public.users USING btree (department_id);


--
-- Name: idx_users_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_name ON public.users USING btree (surname, name, patronymic);


--
-- Name: chat_participants chat_participants_chat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chat_participants
    ADD CONSTRAINT chat_participants_chat_id_fkey FOREIGN KEY (chat_id) REFERENCES public.chats(id) ON DELETE CASCADE;


--
-- Name: chat_participants chat_participants_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chat_participants
    ADD CONSTRAINT chat_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: chats chats_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chats
    ADD CONSTRAINT chats_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: departments departments_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.departments(id) ON DELETE CASCADE;


--
-- Name: favorite_contacts favorite_contacts_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favorite_contacts
    ADD CONSTRAINT favorite_contacts_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: favorite_contacts favorite_contacts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favorite_contacts
    ADD CONSTRAINT favorite_contacts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users fk_users_department; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_users_department FOREIGN KEY (department_id) REFERENCES public.departments(id);


--
-- Name: group_admins group_admins_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_admins
    ADD CONSTRAINT group_admins_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.chats(id) ON DELETE CASCADE;


--
-- Name: group_admins group_admins_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_admins
    ADD CONSTRAINT group_admins_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: group_keys group_keys_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_keys
    ADD CONSTRAINT group_keys_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.chats(id) ON DELETE CASCADE;


--
-- Name: group_keys group_keys_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_keys
    ADD CONSTRAINT group_keys_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: messages messages_chat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_chat_id_fkey FOREIGN KEY (chat_id) REFERENCES public.chats(id) ON DELETE CASCADE;


--
-- Name: messages messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict 9odwSUCTRZUVwGLbjzvWrQmhPPhhoXdEK8i5NVNZXGdvSbYzGtiSYaenmgM1BQ9

