--
-- PostgreSQL database dump
--

\restrict QlpAR3cHLYbTpW1aaCJjaRdBTFaGVVvDv63GwXyZvGXu26x5BopVjmqb5t6Ysoj

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

COMMENT ON TABLE public.departments IS '╨а╨О╨бтАЪ╨б╨В╨б╤У╨а╤Ф╨бтАЪ╨б╤У╨б╨В╨а┬░ ╨а╤Х╨бтАЪ╨а╥С╨а┬╡╨а┬╗╨а╤Х╨а╨Ж ╨а╤Х╨б╨В╨а╤Ц╨а┬░╨а╨Е╨а╤С╨а┬╖╨а┬░╨бтАа╨а╤С╨а╤С';


--
-- Name: COLUMN departments.level; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.departments.level IS '1=╨а╤Ы╨а╤Ф╨б╨В╨б╤У╨а┬╢╨а╨Е╨а╤Х╨атДЦ, 2=╨а╨О╨б╤У╨а┬▒╨б╨Й╨а┬╡╨а╤Ф╨бтАЪ╨а╤Х╨а╨Ж╨бтА╣╨атДЦ, 3=╨а╤Ъ╨а┬╡╨б╨Г╨бтАЪ╨а╨Е╨бтА╣╨атДЦ';


--
-- Name: COLUMN departments.parent_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.departments.parent_id IS '╨а╨О╨б╨Г╨бтА╣╨а┬╗╨а╤Ф╨а┬░ ╨а╨Е╨а┬░ ╨а╨Ж╨бтА╣╨бтВм╨а┬╡╨б╨Г╨бтАЪ╨а╤Х╨б╨П╨бтА░╨а╤С╨атДЦ ╨а╤Х╨бтАЪ╨а╥С╨а┬╡╨а┬╗';


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
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: COLUMN users.department_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.users.department_id IS '╨а╨О╨б╨Г╨бтА╣╨а┬╗╨а╤Ф╨а┬░ ╨а╨Е╨а┬░ ╨а╤Х╨бтАЪ╨а╥С╨а┬╡╨а┬╗ ╨а╤Ч╨а╤Х╨а┬╗╨б╨К╨а┬╖╨а╤Х╨а╨Ж╨а┬░╨бтАЪ╨а┬╡╨а┬╗╨б╨П';


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.departments (id, name, level, parent_id, created_at) FROM stdin;
11111111-1111-1111-1111-111111111111	╨а┬ж╨а┬╡╨а╨Е╨бтАЪ╨б╨В╨а┬░╨а┬╗╨б╨К╨а╨Е╨бтА╣╨атДЦ ╨а╤Х╨а╤Ф╨б╨В╨б╤У╨а┬╢╨а╨Е╨а╤Х╨атДЦ ╨а╤Х╨бтАЪ╨а╥С╨а┬╡╨а┬╗	1	\N	2026-04-01 16:14:03.908231+07
22222222-2222-2222-2222-222222222222	╨а╤Ъ╨а╤Х╨б╨Г╨а╤Ф╨а╤Х╨а╨Ж╨б╨Г╨а╤Ф╨а╤С╨атДЦ ╨а╤Х╨а┬▒╨а┬╗╨а┬░╨б╨Г╨бтАЪ╨а╨Е╨а╤Х╨атДЦ ╨а╤Х╨бтАЪ╨а╥С╨а┬╡╨а┬╗	2	11111111-1111-1111-1111-111111111111	2026-04-01 16:14:03.913122+07
22222222-2222-2222-2222-222222222223	╨а╨О╨а┬░╨а╨Е╨а╤Ф╨бтАЪ-╨а╤Я╨а┬╡╨бтАЪ╨а┬╡╨б╨В╨а┬▒╨б╤У╨б╨В╨а╤Ц╨б╨Г╨а╤Ф╨а╤С╨атДЦ ╨а╤Х╨а┬▒╨а┬╗╨а┬░╨б╨Г╨бтАЪ╨а╨Е╨а╤Х╨атДЦ ╨а╤Х╨бтАЪ╨а╥С╨а┬╡╨а┬╗	2	11111111-1111-1111-1111-111111111111	2026-04-01 16:14:03.913122+07
33333333-3333-3333-3333-333333333333	╨а╤Ъ╨а╤Х╨б╨Г╨а╤Ф╨а╤Х╨а╨Ж╨б╨Г╨а╤Ф╨а╤С╨атДЦ ╨а╤Ц╨а╤Х╨б╨В╨а╤Х╨а╥С╨б╨Г╨а╤Ф╨а╤Х╨атДЦ ╨а╤Х╨бтАЪ╨а╥С╨а┬╡╨а┬╗	3	22222222-2222-2222-2222-222222222222	2026-04-01 16:14:03.917518+07
33333333-3333-3333-3333-333333333334	╨а╤Я╨а╤Х╨а╥С╨а╤Х╨а┬╗╨б╨К╨б╨Г╨а╤Ф╨а╤С╨атДЦ ╨а╤Х╨бтАЪ╨а╥С╨а┬╡╨а┬╗	3	22222222-2222-2222-2222-222222222222	2026-04-01 16:14:03.917518+07
33333333-3333-3333-3333-333333333335	╨а╤Щ╨а╤Х╨а┬╗╨а╤Х╨а╤Ш╨а┬╡╨а╨Е╨б╨Г╨а╤Ф╨а╤С╨атДЦ ╨а╤Х╨бтАЪ╨а╥С╨а┬╡╨а┬╗	3	22222222-2222-2222-2222-222222222222	2026-04-01 16:14:03.917518+07
33333333-3333-3333-3333-333333333336	╨а╨О╨а┬░╨а╨Е╨а╤Ф╨бтАЪ-╨а╤Я╨а┬╡╨бтАЪ╨а┬╡╨б╨В╨а┬▒╨б╤У╨б╨В╨а╤Ц╨б╨Г╨а╤Ф╨а╤С╨атДЦ ╨а╤Ц╨а╤Х╨б╨В╨а╤Х╨а╥С╨б╨Г╨а╤Ф╨а╤Х╨атДЦ ╨а╤Х╨бтАЪ╨а╥С╨а┬╡╨а┬╗	3	22222222-2222-2222-2222-222222222223	2026-04-01 16:14:03.917518+07
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, surname, name, patronymic, department_id, comment, password_hash, is_approved, created_at, updated_at) FROM stdin;
0f2466cd-c7ba-4ba9-9bc2-3fc644cc6f46	12345678	12345678	12345678	33333333-3333-3333-3333-333333333335	12345678	$argon2id$v=19$m=19456,t=2,p=1$VmPDaUVhu/nvOI3zgJB7Og$KaTtpfMm8j36CppkVG7m4obIYlKCXXdbFbl0F01+raM	f	2026-04-01 16:57:26.759049+07	2026-04-01 16:57:26.759049+07
5c985393-4c98-4d66-913a-d2f7d6a6e690	222222	222222	2222222	11111111-1111-1111-1111-111111111111	222222	$argon2id$v=19$m=19456,t=2,p=1$kXAN/PGTHjYHosJX8suHpw$ZWrm45g3IEY7QFXY/NrG2HzNdpyYM+NAnGPFgFWNESY	f	2026-04-01 17:06:00.06429+07	2026-04-01 17:06:00.06429+07
\.


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_departments_level; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_departments_level ON public.departments USING btree (level);


--
-- Name: idx_departments_parent; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_departments_parent ON public.departments USING btree (parent_id);


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
-- Name: departments departments_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.departments(id) ON DELETE CASCADE;


--
-- Name: users fk_users_department; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_users_department FOREIGN KEY (department_id) REFERENCES public.departments(id);


--
-- PostgreSQL database dump complete
--

\unrestrict QlpAR3cHLYbTpW1aaCJjaRdBTFaGVVvDv63GwXyZvGXu26x5BopVjmqb5t6Ysoj

