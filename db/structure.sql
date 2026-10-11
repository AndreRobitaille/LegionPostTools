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

--
-- Name: prevent_membership_approved_minutes_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_membership_approved_minutes_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF OLD.status = 'membership_approved' THEN
    RAISE EXCEPTION 'membership-approved minutes are immutable';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: prevent_minutes_official_record_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_minutes_official_record_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'official minutes records are append-only';
END;
$$;


--
-- Name: protect_completed_endeavor_history_run(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_completed_endeavor_history_run() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' OR OLD.status IN ('succeeded', 'failed', 'superseded') OR
     NEW.manifest IS DISTINCT FROM OLD.manifest OR NEW.fingerprint IS DISTINCT FROM OLD.fingerprint OR
     NEW.endeavor_id IS DISTINCT FROM OLD.endeavor_id OR NEW.requested_by_id IS DISTINCT FROM OLD.requested_by_id THEN
    RAISE EXCEPTION 'endeavor history run inputs and completed results are immutable';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: protect_endeavor_history(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_endeavor_history() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'endeavor history evidence is append-only';
END;
$$;


--
-- Name: protect_endeavor_history_result(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_endeavor_history_result() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'verified endeavor history results are append-only';
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: action_text_rich_texts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.action_text_rich_texts (
    id bigint NOT NULL,
    name character varying NOT NULL,
    body text,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: action_text_rich_texts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.action_text_rich_texts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: action_text_rich_texts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.action_text_rich_texts_id_seq OWNED BY public.action_text_rich_texts.id;


--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: agenda_item_catalog_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agenda_item_catalog_entries (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    title character varying NOT NULL,
    slug character varying NOT NULL,
    summary text DEFAULT ''::text NOT NULL,
    category character varying NOT NULL,
    behavior_type character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    source_key character varying,
    source_label character varying,
    seeded_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    show_wording_on_agenda boolean DEFAULT true NOT NULL,
    show_wording_in_minutes boolean DEFAULT true NOT NULL,
    removed_from_catalog_at timestamp(6) without time zone
);


--
-- Name: agenda_item_catalog_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agenda_item_catalog_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agenda_item_catalog_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agenda_item_catalog_entries_id_seq OWNED BY public.agenda_item_catalog_entries.id;


--
-- Name: agent_access_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_access_tokens (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    public_id character varying NOT NULL,
    secret_digest character varying NOT NULL,
    display_hint character varying NOT NULL,
    name character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    last_used_at timestamp(6) without time zone,
    revoked_at timestamp(6) without time zone,
    revoked_by_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: agent_access_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_access_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_access_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_access_tokens_id_seq OWNED BY public.agent_access_tokens.id;


--
-- Name: agent_api_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_api_executions (
    id bigint NOT NULL,
    agent_access_token_id bigint NOT NULL,
    user_id bigint NOT NULL,
    idempotency_key character varying NOT NULL,
    request_method character varying NOT NULL,
    request_path character varying NOT NULL,
    request_fingerprint character varying NOT NULL,
    state character varying DEFAULT 'processing'::character varying NOT NULL,
    response_status integer,
    response_body text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT agent_api_executions_state_check CHECK (((state)::text = ANY ((ARRAY['processing'::character varying, 'completed'::character varying])::text[])))
);


--
-- Name: agent_api_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_api_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_api_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_api_executions_id_seq OWNED BY public.agent_api_executions.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: calendar_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.calendar_events (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    endeavor_id bigint,
    created_by_id bigint NOT NULL,
    updated_by_id bigint NOT NULL,
    title character varying NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    location character varying DEFAULT ''::character varying NOT NULL,
    starts_at timestamp(6) without time zone NOT NULL,
    ends_at timestamp(6) without time zone,
    all_day boolean DEFAULT false NOT NULL,
    visibility character varying DEFAULT 'members'::character varying NOT NULL,
    cancelled boolean DEFAULT false NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    calendar_category character varying,
    website_designation character varying DEFAULT 'unreviewed'::character varying NOT NULL,
    website_listing character varying DEFAULT 'default'::character varying NOT NULL,
    website_public_id character varying DEFAULT replace((gen_random_uuid())::text, '-'::text, ''::text) NOT NULL,
    website_title character varying,
    website_description text,
    attendance character varying DEFAULT 'members'::character varying NOT NULL,
    CONSTRAINT calendar_events_date_order CHECK (((ends_at IS NULL) OR (ends_at >= starts_at))),
    CONSTRAINT calendar_events_visibility CHECK (((visibility)::text = ANY ((ARRAY['members'::character varying, 'public'::character varying])::text[])))
);


--
-- Name: calendar_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.calendar_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: calendar_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.calendar_events_id_seq OWNED BY public.calendar_events.id;


--
-- Name: dated_agenda_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dated_agenda_items (
    id bigint NOT NULL,
    dated_agenda_id bigint NOT NULL,
    meeting_type_agenda_item_id bigint,
    agenda_item_catalog_entry_id bigint,
    "position" integer DEFAULT 0 NOT NULL,
    title character varying NOT NULL,
    summary text DEFAULT ''::text NOT NULL,
    behavior_type character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    source_key character varying,
    source_label character varying,
    seeded_at timestamp(6) without time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    dated_agenda_section_id bigint NOT NULL,
    endeavor_id bigint,
    show_wording_on_agenda boolean DEFAULT true NOT NULL,
    show_wording_in_minutes boolean DEFAULT true NOT NULL
);


--
-- Name: dated_agenda_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dated_agenda_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dated_agenda_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dated_agenda_items_id_seq OWNED BY public.dated_agenda_items.id;


--
-- Name: dated_agenda_roll_call_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dated_agenda_roll_call_entries (
    id bigint NOT NULL,
    dated_agenda_item_id bigint NOT NULL,
    position_title_id bigint,
    person_id bigint,
    office_name character varying NOT NULL,
    person_name character varying,
    "position" integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: dated_agenda_roll_call_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dated_agenda_roll_call_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dated_agenda_roll_call_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dated_agenda_roll_call_entries_id_seq OWNED BY public.dated_agenda_roll_call_entries.id;


--
-- Name: dated_agenda_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dated_agenda_sections (
    id bigint NOT NULL,
    dated_agenda_id bigint NOT NULL,
    meeting_type_agenda_section_id bigint,
    title character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: dated_agenda_sections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dated_agenda_sections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dated_agenda_sections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dated_agenda_sections_id_seq OWNED BY public.dated_agenda_sections.id;


--
-- Name: dated_agendas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dated_agendas (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    meeting_body_id bigint NOT NULL,
    meeting_type_id bigint NOT NULL,
    starts_at timestamp(6) without time zone NOT NULL,
    title character varying NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    approved_by_id bigint,
    approved_at timestamp(6) without time zone,
    published_by_id bigint,
    published_at timestamp(6) without time zone,
    reopened_by_id bigint,
    reopened_at timestamp(6) without time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    meeting_id bigint NOT NULL,
    location_name character varying NOT NULL,
    location_address text
);


--
-- Name: dated_agendas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dated_agendas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dated_agendas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dated_agendas_id_seq OWNED BY public.dated_agendas.id;


--
-- Name: endeavor_history_editions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.endeavor_history_editions (
    id bigint NOT NULL,
    endeavor_id bigint NOT NULL,
    endeavor_history_run_id bigint NOT NULL,
    payload jsonb NOT NULL,
    manifest jsonb NOT NULL,
    sha256 character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: endeavor_history_editions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.endeavor_history_editions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: endeavor_history_editions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.endeavor_history_editions_id_seq OWNED BY public.endeavor_history_editions.id;


--
-- Name: endeavor_history_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.endeavor_history_events (
    id bigint NOT NULL,
    endeavor_id bigint NOT NULL,
    actor_id bigint,
    endeavor_history_run_id bigint,
    agent_access_token_id bigint,
    action character varying NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: endeavor_history_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.endeavor_history_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: endeavor_history_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.endeavor_history_events_id_seq OWNED BY public.endeavor_history_events.id;


--
-- Name: endeavor_history_guidances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.endeavor_history_guidances (
    id bigint NOT NULL,
    endeavor_id bigint NOT NULL,
    author_id bigint NOT NULL,
    body text NOT NULL,
    agent_access_token_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: endeavor_history_guidances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.endeavor_history_guidances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: endeavor_history_guidances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.endeavor_history_guidances_id_seq OWNED BY public.endeavor_history_guidances.id;


--
-- Name: endeavor_history_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.endeavor_history_results (
    id bigint NOT NULL,
    endeavor_id bigint NOT NULL,
    endeavor_history_run_id bigint NOT NULL,
    stage character varying NOT NULL,
    fingerprint character varying NOT NULL,
    input jsonb NOT NULL,
    candidate jsonb NOT NULL,
    verification jsonb NOT NULL,
    configuration jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: endeavor_history_results_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.endeavor_history_results_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: endeavor_history_results_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.endeavor_history_results_id_seq OWNED BY public.endeavor_history_results.id;


--
-- Name: endeavor_history_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.endeavor_history_runs (
    id bigint NOT NULL,
    endeavor_id bigint NOT NULL,
    requested_by_id bigint,
    agent_access_token_id bigint,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    fingerprint character varying NOT NULL,
    manifest jsonb DEFAULT '{}'::jsonb NOT NULL,
    steps jsonb DEFAULT '[]'::jsonb NOT NULL,
    error_category character varying,
    started_at timestamp(6) without time zone,
    heartbeat_at timestamp(6) without time zone,
    finished_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT endeavor_history_run_status CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'running'::character varying, 'succeeded'::character varying, 'failed'::character varying, 'superseded'::character varying])::text[])))
);


--
-- Name: endeavor_history_runs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.endeavor_history_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: endeavor_history_runs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.endeavor_history_runs_id_seq OWNED BY public.endeavor_history_runs.id;


--
-- Name: endeavor_source_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.endeavor_source_links (
    id bigint NOT NULL,
    endeavor_id bigint NOT NULL,
    endeavor_history_edition_id bigint NOT NULL,
    minutes_revision_id bigint NOT NULL,
    record_key character varying NOT NULL,
    source_ids jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: endeavor_source_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.endeavor_source_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: endeavor_source_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.endeavor_source_links_id_seq OWNED BY public.endeavor_source_links.id;


--
-- Name: endeavor_tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.endeavor_tasks (
    id bigint NOT NULL,
    endeavor_id bigint NOT NULL,
    title character varying NOT NULL,
    due_on date,
    created_by_id bigint NOT NULL,
    updated_by_id bigint NOT NULL,
    completed_at timestamp(6) without time zone,
    completed_by_id bigint,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT endeavor_tasks_completion_provenance CHECK (((completed_at IS NULL) = (completed_by_id IS NULL)))
);


--
-- Name: endeavor_tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.endeavor_tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: endeavor_tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.endeavor_tasks_id_seq OWNED BY public.endeavor_tasks.id;


--
-- Name: endeavor_updates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.endeavor_updates (
    id bigint CONSTRAINT tracked_item_updates_id_not_null NOT NULL,
    endeavor_id bigint CONSTRAINT tracked_item_updates_tracked_item_id_not_null NOT NULL,
    author_id bigint CONSTRAINT tracked_item_updates_author_id_not_null NOT NULL,
    created_at timestamp(6) without time zone CONSTRAINT tracked_item_updates_created_at_not_null NOT NULL,
    updated_at timestamp(6) without time zone CONSTRAINT tracked_item_updates_updated_at_not_null NOT NULL
);


--
-- Name: endeavor_updates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.endeavor_updates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: endeavor_updates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.endeavor_updates_id_seq OWNED BY public.endeavor_updates.id;


--
-- Name: endeavors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.endeavors (
    id bigint CONSTRAINT tracked_items_id_not_null NOT NULL,
    organization_id bigint CONSTRAINT tracked_items_organization_id_not_null NOT NULL,
    meeting_body_id bigint,
    created_by_id bigint CONSTRAINT tracked_items_created_by_id_not_null NOT NULL,
    completed_by_id bigint,
    title character varying CONSTRAINT tracked_items_title_not_null NOT NULL,
    summary text DEFAULT ''::text CONSTRAINT tracked_items_summary_not_null NOT NULL,
    importance character varying DEFAULT 'standard'::character varying CONSTRAINT tracked_items_importance_not_null NOT NULL,
    raise_by_on date,
    status character varying DEFAULT 'active'::character varying CONSTRAINT tracked_items_status_not_null NOT NULL,
    completed_at timestamp(6) without time zone,
    lock_version integer DEFAULT 0 CONSTRAINT tracked_items_lock_version_not_null NOT NULL,
    created_at timestamp(6) without time zone CONSTRAINT tracked_items_created_at_not_null NOT NULL,
    updated_at timestamp(6) without time zone CONSTRAINT tracked_items_updated_at_not_null NOT NULL,
    history_withdrawn boolean DEFAULT false NOT NULL,
    history_generation integer DEFAULT 0 NOT NULL,
    CONSTRAINT endeavors_importance_check CHECK (((importance)::text = ANY ((ARRAY['standard'::character varying, 'important'::character varying])::text[]))),
    CONSTRAINT endeavors_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'completed'::character varying])::text[])))
);


--
-- Name: endeavors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.endeavors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: endeavors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.endeavors_id_seq OWNED BY public.endeavors.id;


--
-- Name: installations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.installations (
    id bigint NOT NULL,
    singleton_key character varying NOT NULL,
    setup_completed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: installations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.installations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: installations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.installations_id_seq OWNED BY public.installations.id;


--
-- Name: loops_roster_syncs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.loops_roster_syncs (
    id bigint NOT NULL,
    roster_import_id bigint NOT NULL,
    requested_by_id bigint,
    status character varying DEFAULT 'queued'::character varying NOT NULL,
    eligible_count integer DEFAULT 0 NOT NULL,
    synced_count integer DEFAULT 0 NOT NULL,
    failed_count integer DEFAULT 0 NOT NULL,
    missing_email_count integer DEFAULT 0 NOT NULL,
    invalid_email_count integer DEFAULT 0 NOT NULL,
    shared_email_count integer DEFAULT 0 NOT NULL,
    failures jsonb DEFAULT '[]'::jsonb NOT NULL,
    error_message text,
    started_at timestamp(6) without time zone,
    finished_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: loops_roster_syncs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.loops_roster_syncs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: loops_roster_syncs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.loops_roster_syncs_id_seq OWNED BY public.loops_roster_syncs.id;


--
-- Name: magic_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.magic_links (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    token_digest character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    used_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    code_digest character varying,
    browser_challenge_digest character varying,
    failed_attempts integer DEFAULT 0 NOT NULL,
    purpose character varying DEFAULT 'sign_in'::character varying NOT NULL,
    session_id bigint,
    CONSTRAINT magic_links_purpose_check CHECK (((purpose)::text = ANY ((ARRAY['sign_in'::character varying, 'create_agent_access_token'::character varying, 'official_minutes_action'::character varying, 'enroll_passkey'::character varying])::text[])))
);


--
-- Name: magic_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.magic_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: magic_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.magic_links_id_seq OWNED BY public.magic_links.id;


--
-- Name: meeting_bodies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meeting_bodies (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    default_location_name character varying,
    default_location_address text,
    default_distribution character varying DEFAULT 'print'::character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: meeting_bodies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.meeting_bodies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: meeting_bodies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.meeting_bodies_id_seq OWNED BY public.meeting_bodies.id;


--
-- Name: meeting_minutes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meeting_minutes (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    meeting_id bigint NOT NULL,
    meeting_body_id bigint NOT NULL,
    meeting_type_id bigint,
    title character varying NOT NULL,
    starts_at timestamp(6) without time zone NOT NULL,
    location_name character varying NOT NULL,
    location_address text,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    current_revision_id bigint,
    CONSTRAINT meeting_minutes_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'approved'::character varying, 'attested'::character varying, 'membership_approved'::character varying])::text[])))
);


--
-- Name: meeting_minutes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.meeting_minutes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: meeting_minutes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.meeting_minutes_id_seq OWNED BY public.meeting_minutes.id;


--
-- Name: meeting_transcripts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meeting_transcripts (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    meeting_id bigint NOT NULL,
    created_by_id bigint NOT NULL,
    source_kind character varying NOT NULL,
    content text,
    original_filename character varying,
    byte_size bigint NOT NULL,
    media_type character varying NOT NULL,
    sha256_digest character varying NOT NULL,
    retention_policy character varying DEFAULT 'delete_after_acceptance'::character varying NOT NULL,
    purge_scheduled_at timestamp(6) without time zone,
    purged_at timestamp(6) without time zone,
    purged_by_id bigint,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT meeting_transcripts_byte_size_check CHECK ((byte_size >= 0)),
    CONSTRAINT meeting_transcripts_retention_policy_check CHECK (((retention_policy)::text = ANY ((ARRAY['delete_after_acceptance'::character varying, 'retain_restricted'::character varying])::text[]))),
    CONSTRAINT meeting_transcripts_source_kind_check CHECK (((source_kind)::text = ANY ((ARRAY['pasted_text'::character varying, 'text_upload'::character varying])::text[])))
);


--
-- Name: meeting_transcripts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.meeting_transcripts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: meeting_transcripts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.meeting_transcripts_id_seq OWNED BY public.meeting_transcripts.id;


--
-- Name: meeting_type_agenda_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meeting_type_agenda_items (
    id bigint NOT NULL,
    meeting_type_id bigint NOT NULL,
    agenda_item_catalog_entry_id bigint NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    title character varying NOT NULL,
    summary text DEFAULT ''::text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    source_key character varying,
    source_label character varying,
    seeded_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    meeting_type_agenda_section_id bigint CONSTRAINT meeting_type_agenda_items_meeting_type_agenda_section__not_null NOT NULL,
    show_wording_on_agenda boolean DEFAULT true NOT NULL,
    show_wording_in_minutes boolean DEFAULT true NOT NULL
);


--
-- Name: meeting_type_agenda_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.meeting_type_agenda_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: meeting_type_agenda_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.meeting_type_agenda_items_id_seq OWNED BY public.meeting_type_agenda_items.id;


--
-- Name: meeting_type_agenda_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meeting_type_agenda_sections (
    id bigint NOT NULL,
    meeting_type_id bigint NOT NULL,
    title character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: meeting_type_agenda_sections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.meeting_type_agenda_sections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: meeting_type_agenda_sections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.meeting_type_agenda_sections_id_seq OWNED BY public.meeting_type_agenda_sections.id;


--
-- Name: meeting_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meeting_types (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    source_key character varying,
    source_label character varying,
    seeded_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: meeting_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.meeting_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: meeting_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.meeting_types_id_seq OWNED BY public.meeting_types.id;


--
-- Name: meetings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meetings (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    meeting_body_id bigint NOT NULL,
    meeting_type_id bigint,
    starts_at timestamp(6) without time zone NOT NULL,
    title character varying NOT NULL,
    location_name character varying NOT NULL,
    location_address text,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    calendar_category character varying,
    website_listing character varying DEFAULT 'default'::character varying NOT NULL,
    website_public_id character varying DEFAULT replace((gen_random_uuid())::text, '-'::text, ''::text) NOT NULL,
    website_title character varying,
    website_description text,
    attendance character varying DEFAULT 'members'::character varying NOT NULL,
    cancelled boolean DEFAULT false NOT NULL
);


--
-- Name: meetings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.meetings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: meetings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.meetings_id_seq OWNED BY public.meetings.id;


--
-- Name: minutes_attendance_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.minutes_attendance_entries (
    id bigint NOT NULL,
    meeting_minutes_id bigint NOT NULL,
    dated_agenda_roll_call_entry_id bigint,
    position_title_id bigint,
    person_id bigint,
    office_name character varying NOT NULL,
    person_name character varying,
    status character varying DEFAULT 'not_recorded'::character varying NOT NULL,
    "position" integer NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT minutes_attendance_position_check CHECK (("position" > 0)),
    CONSTRAINT minutes_attendance_status_check CHECK (((status)::text = ANY ((ARRAY['present'::character varying, 'absent'::character varying, 'excused'::character varying, 'vacant'::character varying, 'not_recorded'::character varying])::text[])))
);


--
-- Name: minutes_attendance_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.minutes_attendance_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: minutes_attendance_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.minutes_attendance_entries_id_seq OWNED BY public.minutes_attendance_entries.id;


--
-- Name: minutes_attestations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.minutes_attestations (
    id bigint NOT NULL,
    minutes_revision_id bigint NOT NULL,
    attested_by_id bigint NOT NULL,
    recorded_by_id bigint NOT NULL,
    official_action_confirmation_id bigint NOT NULL,
    attester_name character varying NOT NULL,
    attester_office character varying NOT NULL,
    attested_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: minutes_attestations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.minutes_attestations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: minutes_attestations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.minutes_attestations_id_seq OWNED BY public.minutes_attestations.id;


--
-- Name: minutes_draft_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.minutes_draft_runs (
    id bigint NOT NULL,
    meeting_minutes_id bigint NOT NULL,
    meeting_transcript_id bigint NOT NULL,
    requested_by_id bigint NOT NULL,
    provider character varying NOT NULL,
    model character varying NOT NULL,
    reasoning_effort character varying NOT NULL,
    prompt_version character varying NOT NULL,
    prompt_sha256 character varying NOT NULL,
    schema_version character varying NOT NULL,
    source_sha256 character varying NOT NULL,
    source_line_count integer NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    provider_response_id character varying,
    provider_request_id character varying,
    input_tokens integer,
    output_tokens integer,
    reasoning_tokens integer,
    total_tokens integer,
    error_category character varying,
    started_at timestamp(6) without time zone,
    completed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    text_verbosity character varying NOT NULL,
    retry_of_id bigint,
    discarded_by_id bigint,
    discarded_at timestamp(6) without time zone,
    CONSTRAINT minutes_draft_runs_source_line_count_check CHECK ((source_line_count > 0)),
    CONSTRAINT minutes_draft_runs_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'running'::character varying, 'succeeded'::character varying, 'failed'::character varying])::text[])))
);


--
-- Name: minutes_draft_runs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.minutes_draft_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: minutes_draft_runs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.minutes_draft_runs_id_seq OWNED BY public.minutes_draft_runs.id;


--
-- Name: minutes_draft_suggestions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.minutes_draft_suggestions (
    id bigint NOT NULL,
    minutes_draft_run_id bigint NOT NULL,
    minutes_item_id bigint,
    minutes_attendance_entry_id bigint,
    minutes_section_id bigint,
    source_dated_agenda_item_id bigint,
    kind character varying NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    source_start_line integer NOT NULL,
    source_end_line integer NOT NULL,
    confidence character varying NOT NULL,
    missing_facts jsonb DEFAULT '[]'::jsonb NOT NULL,
    review_state character varying DEFAULT 'unreviewed'::character varying NOT NULL,
    reviewed_by_id bigint,
    reviewed_at timestamp(6) without time zone,
    applied_record_type character varying,
    applied_record_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT minutes_draft_suggestions_confidence_check CHECK (((confidence)::text = ANY ((ARRAY['high'::character varying, 'medium'::character varying, 'low'::character varying])::text[]))),
    CONSTRAINT minutes_draft_suggestions_kind_check CHECK (((kind)::text = ANY ((ARRAY['item_summary'::character varying, 'outcome'::character varying, 'attendance'::character varying, 'additional_item'::character varying, 'endeavor_proposal'::character varying])::text[]))),
    CONSTRAINT minutes_draft_suggestions_review_state_check CHECK (((review_state)::text = ANY ((ARRAY['unreviewed'::character varying, 'used'::character varying, 'edited'::character varying, 'discarded'::character varying])::text[]))),
    CONSTRAINT minutes_draft_suggestions_source_range_check CHECK (((source_start_line > 0) AND (source_end_line >= source_start_line)))
);


--
-- Name: minutes_draft_suggestions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.minutes_draft_suggestions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: minutes_draft_suggestions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.minutes_draft_suggestions_id_seq OWNED BY public.minutes_draft_suggestions.id;


--
-- Name: minutes_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.minutes_items (
    id bigint NOT NULL,
    minutes_section_id bigint NOT NULL,
    source_dated_agenda_item_id bigint,
    endeavor_id bigint,
    record_key character varying NOT NULL,
    title character varying NOT NULL,
    behavior_type character varying NOT NULL,
    "position" integer NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT minutes_items_position_check CHECK (("position" > 0))
);


--
-- Name: minutes_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.minutes_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: minutes_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.minutes_items_id_seq OWNED BY public.minutes_items.id;


--
-- Name: minutes_lifecycle_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.minutes_lifecycle_events (
    id bigint NOT NULL,
    meeting_minutes_id bigint NOT NULL,
    minutes_revision_id bigint NOT NULL,
    actor_id bigint NOT NULL,
    recorded_by_id bigint NOT NULL,
    official_action_confirmation_id bigint CONSTRAINT minutes_lifecycle_events_official_action_confirmation__not_null NOT NULL,
    event_type character varying NOT NULL,
    from_status character varying NOT NULL,
    to_status character varying NOT NULL,
    actor_name character varying NOT NULL,
    actor_office character varying NOT NULL,
    occurred_at timestamp(6) without time zone NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT minutes_lifecycle_events_type_check CHECK (((event_type)::text = ANY ((ARRAY['approved'::character varying, 'attested'::character varying, 'reopened'::character varying, 'membership_approved'::character varying])::text[])))
);


--
-- Name: minutes_lifecycle_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.minutes_lifecycle_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: minutes_lifecycle_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.minutes_lifecycle_events_id_seq OWNED BY public.minutes_lifecycle_events.id;


--
-- Name: minutes_membership_approvals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.minutes_membership_approvals (
    id bigint NOT NULL,
    meeting_minutes_id bigint NOT NULL,
    minutes_revision_id bigint NOT NULL,
    approving_meeting_id bigint NOT NULL,
    recorded_by_id bigint NOT NULL,
    official_action_confirmation_id bigint CONSTRAINT minutes_membership_approval_official_action_confirmati_not_null NOT NULL,
    disposition character varying NOT NULL,
    factual_note text,
    recorder_name character varying NOT NULL,
    recorder_office character varying NOT NULL,
    recorded_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT minutes_membership_approvals_disposition_check CHECK (((disposition)::text = ANY ((ARRAY['approved_as_presented'::character varying, 'approved_as_corrected'::character varying, 'approved_by_motion'::character varying, 'other'::character varying])::text[])))
);


--
-- Name: minutes_membership_approvals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.minutes_membership_approvals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: minutes_membership_approvals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.minutes_membership_approvals_id_seq OWNED BY public.minutes_membership_approvals.id;


--
-- Name: minutes_outcomes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.minutes_outcomes (
    id bigint NOT NULL,
    minutes_item_id bigint NOT NULL,
    kind character varying NOT NULL,
    text text NOT NULL,
    mover_person_id bigint,
    mover_name character varying,
    seconder_person_id bigint,
    seconder_name character varying,
    disposition character varying DEFAULT 'not_recorded'::character varying NOT NULL,
    vote_summary character varying,
    "position" integer NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT minutes_outcomes_disposition_check CHECK (((disposition)::text = ANY ((ARRAY['adopted'::character varying, 'lost'::character varying, 'withdrawn'::character varying, 'postponed'::character varying, 'referred'::character varying, 'no_vote'::character varying, 'not_recorded'::character varying])::text[]))),
    CONSTRAINT minutes_outcomes_kind_check CHECK (((kind)::text = ANY ((ARRAY['motion'::character varying, 'decision'::character varying])::text[]))),
    CONSTRAINT minutes_outcomes_position_check CHECK (("position" > 0))
);


--
-- Name: minutes_outcomes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.minutes_outcomes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: minutes_outcomes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.minutes_outcomes_id_seq OWNED BY public.minutes_outcomes.id;


--
-- Name: minutes_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.minutes_revisions (
    id bigint NOT NULL,
    meeting_minutes_id bigint NOT NULL,
    number integer NOT NULL,
    payload jsonb NOT NULL,
    sha256 character varying NOT NULL,
    approved_by_id bigint,
    approver_name character varying,
    approver_office character varying,
    approved_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT minutes_revisions_commander_endorsement_check CHECK ((((approved_by_id IS NULL) AND (approver_name IS NULL) AND (approver_office IS NULL) AND (approved_at IS NULL)) OR ((approved_by_id IS NOT NULL) AND (approver_name IS NOT NULL) AND (approver_office IS NOT NULL) AND (approved_at IS NOT NULL)))),
    CONSTRAINT minutes_revisions_number_check CHECK ((number > 0))
);


--
-- Name: minutes_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.minutes_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: minutes_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.minutes_revisions_id_seq OWNED BY public.minutes_revisions.id;


--
-- Name: minutes_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.minutes_sections (
    id bigint NOT NULL,
    meeting_minutes_id bigint NOT NULL,
    source_dated_agenda_section_id bigint,
    title character varying NOT NULL,
    "position" integer NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT minutes_sections_position_check CHECK (("position" > 0))
);


--
-- Name: minutes_sections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.minutes_sections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: minutes_sections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.minutes_sections_id_seq OWNED BY public.minutes_sections.id;


--
-- Name: official_action_confirmations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.official_action_confirmations (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    session_id bigint,
    agent_access_token_id bigint,
    meeting_minutes_id bigint NOT NULL,
    action character varying NOT NULL,
    record_lock_version integer NOT NULL,
    content_digest character varying NOT NULL,
    confirmation_method character varying DEFAULT 'in_app'::character varying NOT NULL,
    evidence_note text,
    expires_at timestamp(6) without time zone NOT NULL,
    confirmed_at timestamp(6) without time zone,
    consumed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    action_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT official_action_confirmations_action_check CHECK (((action)::text = ANY ((ARRAY['approve'::character varying, 'attest'::character varying, 'reopen'::character varying, 'record_membership_approval'::character varying])::text[]))),
    CONSTRAINT official_action_confirmations_method_check CHECK (((confirmation_method)::text = ANY ((ARRAY['in_app'::character varying, 'delegated_agent'::character varying, 'external_written_confirmation'::character varying])::text[])))
);


--
-- Name: official_action_confirmations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.official_action_confirmations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: official_action_confirmations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.official_action_confirmations_id_seq OWNED BY public.official_action_confirmations.id;


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations (
    id bigint NOT NULL,
    name character varying NOT NULL,
    unit_type character varying NOT NULL,
    unit_number character varying,
    timezone character varying DEFAULT 'America/Chicago'::character varying NOT NULL,
    default_location_name character varying,
    default_location_address text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    locality character varying,
    mailing_address text,
    public_email character varying,
    website_calendar_enabled boolean DEFAULT false NOT NULL,
    website_calendar_types jsonb DEFAULT '["member_meeting", "public_event"]'::jsonb NOT NULL,
    website_calendar_version integer DEFAULT 0 NOT NULL
);


--
-- Name: organizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organizations_id_seq OWNED BY public.organizations.id;


--
-- Name: passkey_credentials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.passkey_credentials (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    external_id text NOT NULL,
    public_key text NOT NULL,
    sign_count integer DEFAULT 0 NOT NULL,
    nickname character varying,
    last_used_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: passkey_credentials_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.passkey_credentials_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: passkey_credentials_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.passkey_credentials_id_seq OWNED BY public.passkey_credentials.id;


--
-- Name: people; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.people (
    id bigint NOT NULL,
    first_name character varying NOT NULL,
    last_name character varying NOT NULL,
    email_address character varying,
    phone_number character varying,
    member_number character varying,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    roster_name character varying,
    roster_post character varying,
    roster_membership_type character varying,
    roster_address text,
    roster_undeliverable boolean DEFAULT false NOT NULL,
    roster_email_address character varying,
    roster_phone_number character varying,
    roster_branch character varying,
    roster_war_era character varying,
    roster_continuous_years integer,
    roster_paid_through_year integer,
    roster_member_status character varying,
    roster_imported_at timestamp(6) without time zone,
    roster_removed_at timestamp(6) without time zone
);


--
-- Name: people_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.people_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: people_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.people_id_seq OWNED BY public.people.id;


--
-- Name: permission_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permission_grants (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    capability character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT permission_grants_capability_check CHECK (((capability)::text = ANY ((ARRAY['manage_settings'::character varying, 'manage_people'::character varying, 'manage_meeting_bodies'::character varying, 'manage_agendas'::character varying, 'manage_minutes'::character varying, 'approve_minutes'::character varying, 'attest_minutes'::character varying, 'record_minutes_approval'::character varying, 'view_internal_records'::character varying, 'publish_public_content'::character varying])::text[])))
);


--
-- Name: permission_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.permission_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: permission_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.permission_grants_id_seq OWNED BY public.permission_grants.id;


--
-- Name: position_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.position_assignments (
    id bigint NOT NULL,
    person_id bigint NOT NULL,
    position_title_id bigint NOT NULL,
    starts_on date NOT NULL,
    ends_on date,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT position_assignments_date_order_check CHECK (((ends_on IS NULL) OR (ends_on >= starts_on)))
);


--
-- Name: position_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.position_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: position_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.position_assignments_id_seq OWNED BY public.position_assignments.id;


--
-- Name: position_capability_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.position_capability_grants (
    id bigint NOT NULL,
    position_title_id bigint NOT NULL,
    capability character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT position_capability_grants_capability_check CHECK (((capability)::text = ANY ((ARRAY['manage_people'::character varying, 'manage_meeting_bodies'::character varying, 'manage_agendas'::character varying, 'manage_minutes'::character varying, 'approve_minutes'::character varying, 'attest_minutes'::character varying, 'record_minutes_approval'::character varying, 'view_internal_records'::character varying, 'publish_public_content'::character varying])::text[])))
);


--
-- Name: position_capability_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.position_capability_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: position_capability_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.position_capability_grants_id_seq OWNED BY public.position_capability_grants.id;


--
-- Name: position_titles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.position_titles (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    name character varying NOT NULL,
    display_order integer DEFAULT 0 NOT NULL,
    required_by_default boolean DEFAULT false NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    grants_full_membership_access boolean DEFAULT false NOT NULL
);


--
-- Name: position_titles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.position_titles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: position_titles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.position_titles_id_seq OWNED BY public.position_titles.id;


--
-- Name: roster_imports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roster_imports (
    id bigint NOT NULL,
    uploaded_filename character varying NOT NULL,
    status character varying DEFAULT 'completed'::character varying NOT NULL,
    created_count integer DEFAULT 0 NOT NULL,
    updated_count integer DEFAULT 0 NOT NULL,
    unchanged_count integer DEFAULT 0 NOT NULL,
    problem_count integer DEFAULT 0 NOT NULL,
    summary jsonb DEFAULT '{}'::jsonb NOT NULL,
    imported_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    removed_count integer DEFAULT 0 NOT NULL
);


--
-- Name: roster_imports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.roster_imports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roster_imports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.roster_imports_id_seq OWNED BY public.roster_imports.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    ip_address character varying,
    user_agent character varying,
    last_seen_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    authenticated_at timestamp(6) without time zone
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sessions_id_seq OWNED BY public.sessions.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    person_id bigint NOT NULL,
    email_address character varying NOT NULL,
    email_verified_at timestamp(6) without time zone,
    disabled_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    webauthn_id character varying NOT NULL,
    roster_email_reviewed_address character varying,
    roster_email_review_decision character varying,
    roster_email_reviewed_at timestamp(6) without time zone,
    login_access_override boolean DEFAULT false NOT NULL,
    login_access_override_at timestamp(6) without time zone,
    disabled_reason character varying,
    disabled_reason_detail character varying
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: website_access_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.website_access_tokens (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    created_by_id bigint NOT NULL,
    revoked_by_id bigint,
    name character varying NOT NULL,
    public_id character varying NOT NULL,
    secret_digest character varying NOT NULL,
    display_hint character varying NOT NULL,
    last_used_at timestamp(6) without time zone,
    revoked_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: website_access_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.website_access_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: website_access_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.website_access_tokens_id_seq OWNED BY public.website_access_tokens.id;


--
-- Name: website_calendar_changes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.website_calendar_changes (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    actor_id bigint,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    action character varying NOT NULL,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: website_calendar_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.website_calendar_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: website_calendar_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.website_calendar_changes_id_seq OWNED BY public.website_calendar_changes.id;


--
-- Name: website_portraits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.website_portraits (
    id bigint NOT NULL,
    website_publication_id bigint NOT NULL,
    revision character varying NOT NULL,
    small bytea NOT NULL,
    large bytea NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: website_portraits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.website_portraits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: website_portraits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.website_portraits_id_seq OWNED BY public.website_portraits.id;


--
-- Name: website_publication_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.website_publication_events (
    id bigint NOT NULL,
    website_publication_id bigint NOT NULL,
    actor_id bigint,
    action character varying NOT NULL,
    version integer NOT NULL,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: website_publication_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.website_publication_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: website_publication_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.website_publication_events_id_seq OWNED BY public.website_publication_events.id;


--
-- Name: website_publications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.website_publications (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    calendar_event_id bigint,
    original_calendar_event_id bigint,
    kind character varying NOT NULL,
    public_id character varying NOT NULL,
    draft jsonb DEFAULT '{}'::jsonb NOT NULL,
    snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    consent boolean DEFAULT false NOT NULL,
    consent_note text,
    eligibility_reason text,
    eligibility_source_version integer,
    published_source_version integer,
    featured_position integer,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT website_featured_limit CHECK (((featured_position IS NULL) OR ((featured_position >= 1) AND (featured_position <= 3))))
);


--
-- Name: website_publications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.website_publications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: website_publications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.website_publications_id_seq OWNED BY public.website_publications.id;


--
-- Name: action_text_rich_texts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_text_rich_texts ALTER COLUMN id SET DEFAULT nextval('public.action_text_rich_texts_id_seq'::regclass);


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: agenda_item_catalog_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agenda_item_catalog_entries ALTER COLUMN id SET DEFAULT nextval('public.agenda_item_catalog_entries_id_seq'::regclass);


--
-- Name: agent_access_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_access_tokens ALTER COLUMN id SET DEFAULT nextval('public.agent_access_tokens_id_seq'::regclass);


--
-- Name: agent_api_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_api_executions ALTER COLUMN id SET DEFAULT nextval('public.agent_api_executions_id_seq'::regclass);


--
-- Name: calendar_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_events ALTER COLUMN id SET DEFAULT nextval('public.calendar_events_id_seq'::regclass);


--
-- Name: dated_agenda_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agenda_items ALTER COLUMN id SET DEFAULT nextval('public.dated_agenda_items_id_seq'::regclass);


--
-- Name: dated_agenda_roll_call_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agenda_roll_call_entries ALTER COLUMN id SET DEFAULT nextval('public.dated_agenda_roll_call_entries_id_seq'::regclass);


--
-- Name: dated_agenda_sections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agenda_sections ALTER COLUMN id SET DEFAULT nextval('public.dated_agenda_sections_id_seq'::regclass);


--
-- Name: dated_agendas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agendas ALTER COLUMN id SET DEFAULT nextval('public.dated_agendas_id_seq'::regclass);


--
-- Name: endeavor_history_editions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_editions ALTER COLUMN id SET DEFAULT nextval('public.endeavor_history_editions_id_seq'::regclass);


--
-- Name: endeavor_history_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_events ALTER COLUMN id SET DEFAULT nextval('public.endeavor_history_events_id_seq'::regclass);


--
-- Name: endeavor_history_guidances id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_guidances ALTER COLUMN id SET DEFAULT nextval('public.endeavor_history_guidances_id_seq'::regclass);


--
-- Name: endeavor_history_results id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_results ALTER COLUMN id SET DEFAULT nextval('public.endeavor_history_results_id_seq'::regclass);


--
-- Name: endeavor_history_runs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_runs ALTER COLUMN id SET DEFAULT nextval('public.endeavor_history_runs_id_seq'::regclass);


--
-- Name: endeavor_source_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_source_links ALTER COLUMN id SET DEFAULT nextval('public.endeavor_source_links_id_seq'::regclass);


--
-- Name: endeavor_tasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_tasks ALTER COLUMN id SET DEFAULT nextval('public.endeavor_tasks_id_seq'::regclass);


--
-- Name: endeavor_updates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_updates ALTER COLUMN id SET DEFAULT nextval('public.endeavor_updates_id_seq'::regclass);


--
-- Name: endeavors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavors ALTER COLUMN id SET DEFAULT nextval('public.endeavors_id_seq'::regclass);


--
-- Name: installations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.installations ALTER COLUMN id SET DEFAULT nextval('public.installations_id_seq'::regclass);


--
-- Name: loops_roster_syncs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loops_roster_syncs ALTER COLUMN id SET DEFAULT nextval('public.loops_roster_syncs_id_seq'::regclass);


--
-- Name: magic_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.magic_links ALTER COLUMN id SET DEFAULT nextval('public.magic_links_id_seq'::regclass);


--
-- Name: meeting_bodies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_bodies ALTER COLUMN id SET DEFAULT nextval('public.meeting_bodies_id_seq'::regclass);


--
-- Name: meeting_minutes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_minutes ALTER COLUMN id SET DEFAULT nextval('public.meeting_minutes_id_seq'::regclass);


--
-- Name: meeting_transcripts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_transcripts ALTER COLUMN id SET DEFAULT nextval('public.meeting_transcripts_id_seq'::regclass);


--
-- Name: meeting_type_agenda_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_type_agenda_items ALTER COLUMN id SET DEFAULT nextval('public.meeting_type_agenda_items_id_seq'::regclass);


--
-- Name: meeting_type_agenda_sections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_type_agenda_sections ALTER COLUMN id SET DEFAULT nextval('public.meeting_type_agenda_sections_id_seq'::regclass);


--
-- Name: meeting_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_types ALTER COLUMN id SET DEFAULT nextval('public.meeting_types_id_seq'::regclass);


--
-- Name: meetings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings ALTER COLUMN id SET DEFAULT nextval('public.meetings_id_seq'::regclass);


--
-- Name: minutes_attendance_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_attendance_entries ALTER COLUMN id SET DEFAULT nextval('public.minutes_attendance_entries_id_seq'::regclass);


--
-- Name: minutes_attestations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_attestations ALTER COLUMN id SET DEFAULT nextval('public.minutes_attestations_id_seq'::regclass);


--
-- Name: minutes_draft_runs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_draft_runs ALTER COLUMN id SET DEFAULT nextval('public.minutes_draft_runs_id_seq'::regclass);


--
-- Name: minutes_draft_suggestions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_draft_suggestions ALTER COLUMN id SET DEFAULT nextval('public.minutes_draft_suggestions_id_seq'::regclass);


--
-- Name: minutes_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_items ALTER COLUMN id SET DEFAULT nextval('public.minutes_items_id_seq'::regclass);


--
-- Name: minutes_lifecycle_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_lifecycle_events ALTER COLUMN id SET DEFAULT nextval('public.minutes_lifecycle_events_id_seq'::regclass);


--
-- Name: minutes_membership_approvals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_membership_approvals ALTER COLUMN id SET DEFAULT nextval('public.minutes_membership_approvals_id_seq'::regclass);


--
-- Name: minutes_outcomes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_outcomes ALTER COLUMN id SET DEFAULT nextval('public.minutes_outcomes_id_seq'::regclass);


--
-- Name: minutes_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_revisions ALTER COLUMN id SET DEFAULT nextval('public.minutes_revisions_id_seq'::regclass);


--
-- Name: minutes_sections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_sections ALTER COLUMN id SET DEFAULT nextval('public.minutes_sections_id_seq'::regclass);


--
-- Name: official_action_confirmations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.official_action_confirmations ALTER COLUMN id SET DEFAULT nextval('public.official_action_confirmations_id_seq'::regclass);


--
-- Name: organizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations ALTER COLUMN id SET DEFAULT nextval('public.organizations_id_seq'::regclass);


--
-- Name: passkey_credentials id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.passkey_credentials ALTER COLUMN id SET DEFAULT nextval('public.passkey_credentials_id_seq'::regclass);


--
-- Name: people id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people ALTER COLUMN id SET DEFAULT nextval('public.people_id_seq'::regclass);


--
-- Name: permission_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission_grants ALTER COLUMN id SET DEFAULT nextval('public.permission_grants_id_seq'::regclass);


--
-- Name: position_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.position_assignments ALTER COLUMN id SET DEFAULT nextval('public.position_assignments_id_seq'::regclass);


--
-- Name: position_capability_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.position_capability_grants ALTER COLUMN id SET DEFAULT nextval('public.position_capability_grants_id_seq'::regclass);


--
-- Name: position_titles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.position_titles ALTER COLUMN id SET DEFAULT nextval('public.position_titles_id_seq'::regclass);


--
-- Name: roster_imports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roster_imports ALTER COLUMN id SET DEFAULT nextval('public.roster_imports_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: website_access_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.website_access_tokens ALTER COLUMN id SET DEFAULT nextval('public.website_access_tokens_id_seq'::regclass);


--
-- Name: website_calendar_changes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.website_calendar_changes ALTER COLUMN id SET DEFAULT nextval('public.website_calendar_changes_id_seq'::regclass);


--
-- Name: website_portraits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.website_portraits ALTER COLUMN id SET DEFAULT nextval('public.website_portraits_id_seq'::regclass);


--
-- Name: website_publication_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.website_publication_events ALTER COLUMN id SET DEFAULT nextval('public.website_publication_events_id_seq'::regclass);


--
-- Name: website_publications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.website_publications ALTER COLUMN id SET DEFAULT nextval('public.website_publications_id_seq'::regclass);


--
-- Name: action_text_rich_texts action_text_rich_texts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_text_rich_texts
    ADD CONSTRAINT action_text_rich_texts_pkey PRIMARY KEY (id);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: agenda_item_catalog_entries agenda_item_catalog_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agenda_item_catalog_entries
    ADD CONSTRAINT agenda_item_catalog_entries_pkey PRIMARY KEY (id);


--
-- Name: agent_access_tokens agent_access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_access_tokens
    ADD CONSTRAINT agent_access_tokens_pkey PRIMARY KEY (id);


--
-- Name: agent_api_executions agent_api_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_api_executions
    ADD CONSTRAINT agent_api_executions_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: calendar_events calendar_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT calendar_events_pkey PRIMARY KEY (id);


--
-- Name: dated_agenda_items dated_agenda_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agenda_items
    ADD CONSTRAINT dated_agenda_items_pkey PRIMARY KEY (id);


--
-- Name: dated_agenda_roll_call_entries dated_agenda_roll_call_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agenda_roll_call_entries
    ADD CONSTRAINT dated_agenda_roll_call_entries_pkey PRIMARY KEY (id);


--
-- Name: dated_agenda_sections dated_agenda_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agenda_sections
    ADD CONSTRAINT dated_agenda_sections_pkey PRIMARY KEY (id);


--
-- Name: dated_agendas dated_agendas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agendas
    ADD CONSTRAINT dated_agendas_pkey PRIMARY KEY (id);


--
-- Name: endeavor_history_editions endeavor_history_editions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_editions
    ADD CONSTRAINT endeavor_history_editions_pkey PRIMARY KEY (id);


--
-- Name: endeavor_history_events endeavor_history_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_events
    ADD CONSTRAINT endeavor_history_events_pkey PRIMARY KEY (id);


--
-- Name: endeavor_history_guidances endeavor_history_guidances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_guidances
    ADD CONSTRAINT endeavor_history_guidances_pkey PRIMARY KEY (id);


--
-- Name: endeavor_history_results endeavor_history_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_results
    ADD CONSTRAINT endeavor_history_results_pkey PRIMARY KEY (id);


--
-- Name: endeavor_history_runs endeavor_history_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_runs
    ADD CONSTRAINT endeavor_history_runs_pkey PRIMARY KEY (id);


--
-- Name: endeavor_source_links endeavor_source_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_source_links
    ADD CONSTRAINT endeavor_source_links_pkey PRIMARY KEY (id);


--
-- Name: endeavor_tasks endeavor_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_tasks
    ADD CONSTRAINT endeavor_tasks_pkey PRIMARY KEY (id);


--
-- Name: endeavor_updates endeavor_updates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_updates
    ADD CONSTRAINT endeavor_updates_pkey PRIMARY KEY (id);


--
-- Name: endeavors endeavors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavors
    ADD CONSTRAINT endeavors_pkey PRIMARY KEY (id);


--
-- Name: installations installations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.installations
    ADD CONSTRAINT installations_pkey PRIMARY KEY (id);


--
-- Name: loops_roster_syncs loops_roster_syncs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loops_roster_syncs
    ADD CONSTRAINT loops_roster_syncs_pkey PRIMARY KEY (id);


--
-- Name: magic_links magic_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.magic_links
    ADD CONSTRAINT magic_links_pkey PRIMARY KEY (id);


--
-- Name: meeting_bodies meeting_bodies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_bodies
    ADD CONSTRAINT meeting_bodies_pkey PRIMARY KEY (id);


--
-- Name: meeting_minutes meeting_minutes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_minutes
    ADD CONSTRAINT meeting_minutes_pkey PRIMARY KEY (id);


--
-- Name: meeting_transcripts meeting_transcripts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_transcripts
    ADD CONSTRAINT meeting_transcripts_pkey PRIMARY KEY (id);


--
-- Name: meeting_type_agenda_items meeting_type_agenda_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_type_agenda_items
    ADD CONSTRAINT meeting_type_agenda_items_pkey PRIMARY KEY (id);


--
-- Name: meeting_type_agenda_sections meeting_type_agenda_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_type_agenda_sections
    ADD CONSTRAINT meeting_type_agenda_sections_pkey PRIMARY KEY (id);


--
-- Name: meeting_types meeting_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_types
    ADD CONSTRAINT meeting_types_pkey PRIMARY KEY (id);


--
-- Name: meetings meetings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_pkey PRIMARY KEY (id);


--
-- Name: minutes_attendance_entries minutes_attendance_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_attendance_entries
    ADD CONSTRAINT minutes_attendance_entries_pkey PRIMARY KEY (id);


--
-- Name: minutes_attestations minutes_attestations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_attestations
    ADD CONSTRAINT minutes_attestations_pkey PRIMARY KEY (id);


--
-- Name: minutes_draft_runs minutes_draft_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_draft_runs
    ADD CONSTRAINT minutes_draft_runs_pkey PRIMARY KEY (id);


--
-- Name: minutes_draft_suggestions minutes_draft_suggestions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_draft_suggestions
    ADD CONSTRAINT minutes_draft_suggestions_pkey PRIMARY KEY (id);


--
-- Name: minutes_items minutes_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_items
    ADD CONSTRAINT minutes_items_pkey PRIMARY KEY (id);


--
-- Name: minutes_lifecycle_events minutes_lifecycle_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_lifecycle_events
    ADD CONSTRAINT minutes_lifecycle_events_pkey PRIMARY KEY (id);


--
-- Name: minutes_membership_approvals minutes_membership_approvals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_membership_approvals
    ADD CONSTRAINT minutes_membership_approvals_pkey PRIMARY KEY (id);


--
-- Name: minutes_outcomes minutes_outcomes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_outcomes
    ADD CONSTRAINT minutes_outcomes_pkey PRIMARY KEY (id);


--
-- Name: minutes_revisions minutes_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_revisions
    ADD CONSTRAINT minutes_revisions_pkey PRIMARY KEY (id);


--
-- Name: minutes_sections minutes_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_sections
    ADD CONSTRAINT minutes_sections_pkey PRIMARY KEY (id);


--
-- Name: official_action_confirmations official_action_confirmations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.official_action_confirmations
    ADD CONSTRAINT official_action_confirmations_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: passkey_credentials passkey_credentials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.passkey_credentials
    ADD CONSTRAINT passkey_credentials_pkey PRIMARY KEY (id);


--
-- Name: people people_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT people_pkey PRIMARY KEY (id);


--
-- Name: permission_grants permission_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission_grants
    ADD CONSTRAINT permission_grants_pkey PRIMARY KEY (id);


--
-- Name: position_assignments position_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.position_assignments
    ADD CONSTRAINT position_assignments_pkey PRIMARY KEY (id);


--
-- Name: position_capability_grants position_capability_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.position_capability_grants
    ADD CONSTRAINT position_capability_grants_pkey PRIMARY KEY (id);


--
-- Name: position_titles position_titles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.position_titles
    ADD CONSTRAINT position_titles_pkey PRIMARY KEY (id);


--
-- Name: roster_imports roster_imports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roster_imports
    ADD CONSTRAINT roster_imports_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: website_access_tokens website_access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.website_access_tokens
    ADD CONSTRAINT website_access_tokens_pkey PRIMARY KEY (id);


--
-- Name: website_calendar_changes website_calendar_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.website_calendar_changes
    ADD CONSTRAINT website_calendar_changes_pkey PRIMARY KEY (id);


--
-- Name: website_portraits website_portraits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.website_portraits
    ADD CONSTRAINT website_portraits_pkey PRIMARY KEY (id);


--
-- Name: website_publication_events website_publication_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.website_publication_events
    ADD CONSTRAINT website_publication_events_pkey PRIMARY KEY (id);


--
-- Name: website_publications website_publications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.website_publications
    ADD CONSTRAINT website_publications_pkey PRIMARY KEY (id);


--
-- Name: endeavor_history_result_reuse; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX endeavor_history_result_reuse ON public.endeavor_history_results USING btree (endeavor_id, stage, fingerprint);


--
-- Name: idx_agenda_catalog_on_org_category_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agenda_catalog_on_org_category_position ON public.agenda_item_catalog_entries USING btree (organization_id, category, "position");


--
-- Name: idx_agenda_catalog_on_org_removal; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agenda_catalog_on_org_removal ON public.agenda_item_catalog_entries USING btree (organization_id, removed_from_catalog_at);


--
-- Name: idx_agenda_roll_call_item_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_agenda_roll_call_item_position ON public.dated_agenda_roll_call_entries USING btree (dated_agenda_item_id, "position");


--
-- Name: idx_agent_api_executions_token_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_agent_api_executions_token_key ON public.agent_api_executions USING btree (agent_access_token_id, idempotency_key);


--
-- Name: idx_dated_agenda_items_agenda_endeavor; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_dated_agenda_items_agenda_endeavor ON public.dated_agenda_items USING btree (dated_agenda_id, endeavor_id) WHERE (endeavor_id IS NOT NULL);


--
-- Name: idx_dated_agenda_items_section_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_dated_agenda_items_section_position ON public.dated_agenda_items USING btree (dated_agenda_section_id, "position");


--
-- Name: idx_dated_agenda_sections_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_dated_agenda_sections_position ON public.dated_agenda_sections USING btree (dated_agenda_id, "position");


--
-- Name: idx_dated_agenda_sections_title; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_dated_agenda_sections_title ON public.dated_agenda_sections USING btree (dated_agenda_id, title);


--
-- Name: idx_dated_sections_source; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_dated_sections_source ON public.dated_agenda_sections USING btree (dated_agenda_id, meeting_type_agenda_section_id) WHERE (meeting_type_agenda_section_id IS NOT NULL);


--
-- Name: idx_mt_agenda_items_section_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_mt_agenda_items_section_position ON public.meeting_type_agenda_items USING btree (meeting_type_agenda_section_id, "position");


--
-- Name: idx_mt_agenda_sections_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_mt_agenda_sections_position ON public.meeting_type_agenda_sections USING btree (meeting_type_id, "position");


--
-- Name: idx_mt_agenda_sections_title; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_mt_agenda_sections_title ON public.meeting_type_agenda_sections USING btree (meeting_type_id, title);


--
-- Name: idx_on_agenda_item_catalog_entry_id_af09cfc728; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_agenda_item_catalog_entry_id_af09cfc728 ON public.meeting_type_agenda_items USING btree (agenda_item_catalog_entry_id);


--
-- Name: idx_on_official_action_confirmation_id_40172e0bce; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_official_action_confirmation_id_40172e0bce ON public.minutes_membership_approvals USING btree (official_action_confirmation_id);


--
-- Name: idx_on_official_action_confirmation_id_7ceb2b7c93; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_official_action_confirmation_id_7ceb2b7c93 ON public.minutes_lifecycle_events USING btree (official_action_confirmation_id);


--
-- Name: idx_on_organization_id_source_key_ecf47169eb; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_organization_id_source_key_ecf47169eb ON public.agenda_item_catalog_entries USING btree (organization_id, source_key) WHERE (source_key IS NOT NULL);


--
-- Name: idx_one_active_loops_roster_sync; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_one_active_loops_roster_sync ON public.loops_roster_syncs USING btree (status) WHERE ((status)::text = ANY ((ARRAY['queued'::character varying, 'running'::character varying])::text[]));


--
-- Name: idx_one_active_minutes_draft_retry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_one_active_minutes_draft_retry ON public.minutes_draft_runs USING btree (retry_of_id) WHERE ((retry_of_id IS NOT NULL) AND ((status)::text = ANY ((ARRAY['pending'::character varying, 'running'::character varying])::text[])));


--
-- Name: idx_position_assignments_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_position_assignments_identity ON public.position_assignments USING btree (person_id, position_title_id, starts_on);


--
-- Name: index_action_text_rich_texts_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_action_text_rich_texts_uniqueness ON public.action_text_rich_texts USING btree (record_type, record_id, name);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_agenda_item_catalog_entries_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agenda_item_catalog_entries_on_organization_id ON public.agenda_item_catalog_entries USING btree (organization_id);


--
-- Name: index_agenda_item_catalog_entries_on_organization_id_and_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agenda_item_catalog_entries_on_organization_id_and_slug ON public.agenda_item_catalog_entries USING btree (organization_id, slug);


--
-- Name: index_agent_access_tokens_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_access_tokens_on_expires_at ON public.agent_access_tokens USING btree (expires_at);


--
-- Name: index_agent_access_tokens_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agent_access_tokens_on_public_id ON public.agent_access_tokens USING btree (public_id);


--
-- Name: index_agent_access_tokens_on_revoked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_access_tokens_on_revoked_at ON public.agent_access_tokens USING btree (revoked_at);


--
-- Name: index_agent_access_tokens_on_revoked_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_access_tokens_on_revoked_by_id ON public.agent_access_tokens USING btree (revoked_by_id);


--
-- Name: index_agent_access_tokens_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_access_tokens_on_user_id ON public.agent_access_tokens USING btree (user_id);


--
-- Name: index_agent_api_executions_on_agent_access_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_api_executions_on_agent_access_token_id ON public.agent_api_executions USING btree (agent_access_token_id);


--
-- Name: index_agent_api_executions_on_state_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_api_executions_on_state_and_created_at ON public.agent_api_executions USING btree (state, created_at);


--
-- Name: index_agent_api_executions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_api_executions_on_user_id ON public.agent_api_executions USING btree (user_id);


--
-- Name: index_calendar_events_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_calendar_events_on_created_by_id ON public.calendar_events USING btree (created_by_id);


--
-- Name: index_calendar_events_on_endeavor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_calendar_events_on_endeavor_id ON public.calendar_events USING btree (endeavor_id);


--
-- Name: index_calendar_events_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_calendar_events_on_organization_id ON public.calendar_events USING btree (organization_id);


--
-- Name: index_calendar_events_on_organization_id_and_starts_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_calendar_events_on_organization_id_and_starts_at ON public.calendar_events USING btree (organization_id, starts_at);


--
-- Name: index_calendar_events_on_updated_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_calendar_events_on_updated_by_id ON public.calendar_events USING btree (updated_by_id);


--
-- Name: index_calendar_events_on_website_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_calendar_events_on_website_public_id ON public.calendar_events USING btree (website_public_id);


--
-- Name: index_dated_agenda_items_on_agenda_and_catalog_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_dated_agenda_items_on_agenda_and_catalog_entry ON public.dated_agenda_items USING btree (dated_agenda_id, agenda_item_catalog_entry_id);


--
-- Name: index_dated_agenda_items_on_agenda_and_mt_item; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_dated_agenda_items_on_agenda_and_mt_item ON public.dated_agenda_items USING btree (dated_agenda_id, meeting_type_agenda_item_id) WHERE (meeting_type_agenda_item_id IS NOT NULL);


--
-- Name: index_dated_agenda_items_on_agenda_and_source_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_dated_agenda_items_on_agenda_and_source_key ON public.dated_agenda_items USING btree (dated_agenda_id, source_key) WHERE (source_key IS NOT NULL);


--
-- Name: index_dated_agenda_items_on_agenda_item_catalog_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dated_agenda_items_on_agenda_item_catalog_entry_id ON public.dated_agenda_items USING btree (agenda_item_catalog_entry_id);


--
-- Name: index_dated_agenda_items_on_dated_agenda_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dated_agenda_items_on_dated_agenda_id ON public.dated_agenda_items USING btree (dated_agenda_id);


--
-- Name: index_dated_agenda_items_on_endeavor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dated_agenda_items_on_endeavor_id ON public.dated_agenda_items USING btree (endeavor_id);


--
-- Name: index_dated_agenda_items_on_meeting_type_agenda_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dated_agenda_items_on_meeting_type_agenda_item_id ON public.dated_agenda_items USING btree (meeting_type_agenda_item_id);


--
-- Name: index_dated_agenda_roll_call_entries_on_dated_agenda_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dated_agenda_roll_call_entries_on_dated_agenda_item_id ON public.dated_agenda_roll_call_entries USING btree (dated_agenda_item_id);


--
-- Name: index_dated_agenda_roll_call_entries_on_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dated_agenda_roll_call_entries_on_person_id ON public.dated_agenda_roll_call_entries USING btree (person_id);


--
-- Name: index_dated_agenda_roll_call_entries_on_position_title_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dated_agenda_roll_call_entries_on_position_title_id ON public.dated_agenda_roll_call_entries USING btree (position_title_id);


--
-- Name: index_dated_agenda_sections_on_dated_agenda_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dated_agenda_sections_on_dated_agenda_id ON public.dated_agenda_sections USING btree (dated_agenda_id);


--
-- Name: index_dated_agenda_sections_on_meeting_type_agenda_section_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dated_agenda_sections_on_meeting_type_agenda_section_id ON public.dated_agenda_sections USING btree (meeting_type_agenda_section_id);


--
-- Name: index_dated_agendas_on_approved_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dated_agendas_on_approved_by_id ON public.dated_agendas USING btree (approved_by_id);


--
-- Name: index_dated_agendas_on_meeting_body_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dated_agendas_on_meeting_body_id ON public.dated_agendas USING btree (meeting_body_id);


--
-- Name: index_dated_agendas_on_meeting_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_dated_agendas_on_meeting_id ON public.dated_agendas USING btree (meeting_id);


--
-- Name: index_dated_agendas_on_meeting_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dated_agendas_on_meeting_type_id ON public.dated_agendas USING btree (meeting_type_id);


--
-- Name: index_dated_agendas_on_org_body_type_and_starts_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dated_agendas_on_org_body_type_and_starts_at ON public.dated_agendas USING btree (organization_id, meeting_body_id, meeting_type_id, starts_at);


--
-- Name: index_dated_agendas_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dated_agendas_on_organization_id ON public.dated_agendas USING btree (organization_id);


--
-- Name: index_dated_agendas_on_organization_id_and_starts_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dated_agendas_on_organization_id_and_starts_at ON public.dated_agendas USING btree (organization_id, starts_at);


--
-- Name: index_dated_agendas_on_organization_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dated_agendas_on_organization_id_and_status ON public.dated_agendas USING btree (organization_id, status);


--
-- Name: index_dated_agendas_on_published_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dated_agendas_on_published_by_id ON public.dated_agendas USING btree (published_by_id);


--
-- Name: index_dated_agendas_on_reopened_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dated_agendas_on_reopened_by_id ON public.dated_agendas USING btree (reopened_by_id);


--
-- Name: index_endeavor_history_editions_on_endeavor_history_run_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_endeavor_history_editions_on_endeavor_history_run_id ON public.endeavor_history_editions USING btree (endeavor_history_run_id);


--
-- Name: index_endeavor_history_editions_on_endeavor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_history_editions_on_endeavor_id ON public.endeavor_history_editions USING btree (endeavor_id);


--
-- Name: index_endeavor_history_events_on_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_history_events_on_actor_id ON public.endeavor_history_events USING btree (actor_id);


--
-- Name: index_endeavor_history_events_on_endeavor_history_run_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_history_events_on_endeavor_history_run_id ON public.endeavor_history_events USING btree (endeavor_history_run_id);


--
-- Name: index_endeavor_history_events_on_endeavor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_history_events_on_endeavor_id ON public.endeavor_history_events USING btree (endeavor_id);


--
-- Name: index_endeavor_history_guidances_on_author_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_history_guidances_on_author_id ON public.endeavor_history_guidances USING btree (author_id);


--
-- Name: index_endeavor_history_guidances_on_endeavor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_history_guidances_on_endeavor_id ON public.endeavor_history_guidances USING btree (endeavor_id);


--
-- Name: index_endeavor_history_results_on_endeavor_history_run_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_history_results_on_endeavor_history_run_id ON public.endeavor_history_results USING btree (endeavor_history_run_id);


--
-- Name: index_endeavor_history_results_on_endeavor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_history_results_on_endeavor_id ON public.endeavor_history_results USING btree (endeavor_id);


--
-- Name: index_endeavor_history_runs_on_endeavor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_history_runs_on_endeavor_id ON public.endeavor_history_runs USING btree (endeavor_id);


--
-- Name: index_endeavor_history_runs_on_endeavor_id_and_fingerprint; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_history_runs_on_endeavor_id_and_fingerprint ON public.endeavor_history_runs USING btree (endeavor_id, fingerprint);


--
-- Name: index_endeavor_history_runs_on_requested_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_history_runs_on_requested_by_id ON public.endeavor_history_runs USING btree (requested_by_id);


--
-- Name: index_endeavor_source_links_on_endeavor_history_edition_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_source_links_on_endeavor_history_edition_id ON public.endeavor_source_links USING btree (endeavor_history_edition_id);


--
-- Name: index_endeavor_source_links_on_endeavor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_source_links_on_endeavor_id ON public.endeavor_source_links USING btree (endeavor_id);


--
-- Name: index_endeavor_source_links_on_minutes_revision_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_source_links_on_minutes_revision_id ON public.endeavor_source_links USING btree (minutes_revision_id);


--
-- Name: index_endeavor_tasks_on_completed_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_tasks_on_completed_by_id ON public.endeavor_tasks USING btree (completed_by_id);


--
-- Name: index_endeavor_tasks_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_tasks_on_created_by_id ON public.endeavor_tasks USING btree (created_by_id);


--
-- Name: index_endeavor_tasks_on_endeavor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_tasks_on_endeavor_id ON public.endeavor_tasks USING btree (endeavor_id);


--
-- Name: index_endeavor_tasks_on_endeavor_id_and_due_on; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_tasks_on_endeavor_id_and_due_on ON public.endeavor_tasks USING btree (endeavor_id, due_on);


--
-- Name: index_endeavor_tasks_on_updated_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_tasks_on_updated_by_id ON public.endeavor_tasks USING btree (updated_by_id);


--
-- Name: index_endeavor_updates_on_author_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_updates_on_author_id ON public.endeavor_updates USING btree (author_id);


--
-- Name: index_endeavor_updates_on_endeavor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavor_updates_on_endeavor_id ON public.endeavor_updates USING btree (endeavor_id);


--
-- Name: index_endeavors_on_completed_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavors_on_completed_by_id ON public.endeavors USING btree (completed_by_id);


--
-- Name: index_endeavors_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavors_on_created_by_id ON public.endeavors USING btree (created_by_id);


--
-- Name: index_endeavors_on_meeting_body_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavors_on_meeting_body_id ON public.endeavors USING btree (meeting_body_id);


--
-- Name: index_endeavors_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavors_on_organization_id ON public.endeavors USING btree (organization_id);


--
-- Name: index_endeavors_on_organization_id_and_raise_by_on; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavors_on_organization_id_and_raise_by_on ON public.endeavors USING btree (organization_id, raise_by_on);


--
-- Name: index_endeavors_on_organization_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endeavors_on_organization_id_and_status ON public.endeavors USING btree (organization_id, status);


--
-- Name: index_installations_on_singleton_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_installations_on_singleton_key ON public.installations USING btree (singleton_key);


--
-- Name: index_loops_roster_syncs_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_loops_roster_syncs_on_created_at ON public.loops_roster_syncs USING btree (created_at);


--
-- Name: index_loops_roster_syncs_on_requested_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_loops_roster_syncs_on_requested_by_id ON public.loops_roster_syncs USING btree (requested_by_id);


--
-- Name: index_loops_roster_syncs_on_roster_import_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_loops_roster_syncs_on_roster_import_id ON public.loops_roster_syncs USING btree (roster_import_id);


--
-- Name: index_magic_links_on_browser_challenge_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_magic_links_on_browser_challenge_digest ON public.magic_links USING btree (browser_challenge_digest);


--
-- Name: index_magic_links_on_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_magic_links_on_session_id ON public.magic_links USING btree (session_id);


--
-- Name: index_magic_links_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_magic_links_on_token_digest ON public.magic_links USING btree (token_digest);


--
-- Name: index_magic_links_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_magic_links_on_user_id ON public.magic_links USING btree (user_id);


--
-- Name: index_meeting_bodies_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meeting_bodies_on_organization_id ON public.meeting_bodies USING btree (organization_id);


--
-- Name: index_meeting_bodies_on_organization_id_and_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_meeting_bodies_on_organization_id_and_slug ON public.meeting_bodies USING btree (organization_id, slug);


--
-- Name: index_meeting_minutes_on_current_revision_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meeting_minutes_on_current_revision_id ON public.meeting_minutes USING btree (current_revision_id);


--
-- Name: index_meeting_minutes_on_meeting_body_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meeting_minutes_on_meeting_body_id ON public.meeting_minutes USING btree (meeting_body_id);


--
-- Name: index_meeting_minutes_on_meeting_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_meeting_minutes_on_meeting_id ON public.meeting_minutes USING btree (meeting_id);


--
-- Name: index_meeting_minutes_on_meeting_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meeting_minutes_on_meeting_type_id ON public.meeting_minutes USING btree (meeting_type_id);


--
-- Name: index_meeting_minutes_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meeting_minutes_on_organization_id ON public.meeting_minutes USING btree (organization_id);


--
-- Name: index_meeting_minutes_on_organization_id_and_starts_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meeting_minutes_on_organization_id_and_starts_at ON public.meeting_minutes USING btree (organization_id, starts_at);


--
-- Name: index_meeting_transcripts_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meeting_transcripts_on_created_by_id ON public.meeting_transcripts USING btree (created_by_id);


--
-- Name: index_meeting_transcripts_on_meeting_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_meeting_transcripts_on_meeting_id ON public.meeting_transcripts USING btree (meeting_id);


--
-- Name: index_meeting_transcripts_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meeting_transcripts_on_organization_id ON public.meeting_transcripts USING btree (organization_id);


--
-- Name: index_meeting_transcripts_on_purged_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meeting_transcripts_on_purged_by_id ON public.meeting_transcripts USING btree (purged_by_id);


--
-- Name: index_meeting_transcripts_on_sha256_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meeting_transcripts_on_sha256_digest ON public.meeting_transcripts USING btree (sha256_digest);


--
-- Name: index_meeting_type_agenda_items_on_meeting_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meeting_type_agenda_items_on_meeting_type_id ON public.meeting_type_agenda_items USING btree (meeting_type_id);


--
-- Name: index_meeting_type_agenda_sections_on_meeting_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meeting_type_agenda_sections_on_meeting_type_id ON public.meeting_type_agenda_sections USING btree (meeting_type_id);


--
-- Name: index_meeting_types_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meeting_types_on_organization_id ON public.meeting_types USING btree (organization_id);


--
-- Name: index_meeting_types_on_organization_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_meeting_types_on_organization_id_and_name ON public.meeting_types USING btree (organization_id, name);


--
-- Name: index_meeting_types_on_organization_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_meeting_types_on_organization_id_and_position ON public.meeting_types USING btree (organization_id, "position");


--
-- Name: index_meeting_types_on_organization_id_and_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_meeting_types_on_organization_id_and_slug ON public.meeting_types USING btree (organization_id, slug);


--
-- Name: index_meeting_types_on_organization_id_and_source_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_meeting_types_on_organization_id_and_source_key ON public.meeting_types USING btree (organization_id, source_key) WHERE (source_key IS NOT NULL);


--
-- Name: index_meetings_on_meeting_body_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meetings_on_meeting_body_id ON public.meetings USING btree (meeting_body_id);


--
-- Name: index_meetings_on_meeting_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meetings_on_meeting_type_id ON public.meetings USING btree (meeting_type_id);


--
-- Name: index_meetings_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meetings_on_organization_id ON public.meetings USING btree (organization_id);


--
-- Name: index_meetings_on_organization_id_and_starts_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meetings_on_organization_id_and_starts_at ON public.meetings USING btree (organization_id, starts_at);


--
-- Name: index_meetings_on_website_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_meetings_on_website_public_id ON public.meetings USING btree (website_public_id);


--
-- Name: index_minutes_attendance_entries_on_meeting_minutes_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_attendance_entries_on_meeting_minutes_id ON public.minutes_attendance_entries USING btree (meeting_minutes_id);


--
-- Name: index_minutes_attendance_entries_on_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_attendance_entries_on_person_id ON public.minutes_attendance_entries USING btree (person_id);


--
-- Name: index_minutes_attendance_entries_on_position_title_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_attendance_entries_on_position_title_id ON public.minutes_attendance_entries USING btree (position_title_id);


--
-- Name: index_minutes_attendance_on_agenda_roll_call; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_attendance_on_agenda_roll_call ON public.minutes_attendance_entries USING btree (dated_agenda_roll_call_entry_id);


--
-- Name: index_minutes_attendance_on_minutes_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_minutes_attendance_on_minutes_and_position ON public.minutes_attendance_entries USING btree (meeting_minutes_id, "position");


--
-- Name: index_minutes_attestations_on_attested_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_attestations_on_attested_by_id ON public.minutes_attestations USING btree (attested_by_id);


--
-- Name: index_minutes_attestations_on_minutes_revision_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_minutes_attestations_on_minutes_revision_id ON public.minutes_attestations USING btree (minutes_revision_id);


--
-- Name: index_minutes_attestations_on_official_action_confirmation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_minutes_attestations_on_official_action_confirmation_id ON public.minutes_attestations USING btree (official_action_confirmation_id);


--
-- Name: index_minutes_attestations_on_recorded_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_attestations_on_recorded_by_id ON public.minutes_attestations USING btree (recorded_by_id);


--
-- Name: index_minutes_draft_runs_on_discarded_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_draft_runs_on_discarded_by_id ON public.minutes_draft_runs USING btree (discarded_by_id);


--
-- Name: index_minutes_draft_runs_on_meeting_minutes_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_draft_runs_on_meeting_minutes_id ON public.minutes_draft_runs USING btree (meeting_minutes_id);


--
-- Name: index_minutes_draft_runs_on_meeting_minutes_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_draft_runs_on_meeting_minutes_id_and_created_at ON public.minutes_draft_runs USING btree (meeting_minutes_id, created_at);


--
-- Name: index_minutes_draft_runs_on_meeting_transcript_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_draft_runs_on_meeting_transcript_id ON public.minutes_draft_runs USING btree (meeting_transcript_id);


--
-- Name: index_minutes_draft_runs_on_requested_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_draft_runs_on_requested_by_id ON public.minutes_draft_runs USING btree (requested_by_id);


--
-- Name: index_minutes_draft_runs_on_retry_of_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_draft_runs_on_retry_of_id ON public.minutes_draft_runs USING btree (retry_of_id);


--
-- Name: index_minutes_draft_runs_on_status_and_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_draft_runs_on_status_and_discarded_at ON public.minutes_draft_runs USING btree (status, discarded_at);


--
-- Name: index_minutes_draft_suggestions_on_applied_record; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_draft_suggestions_on_applied_record ON public.minutes_draft_suggestions USING btree (applied_record_type, applied_record_id);


--
-- Name: index_minutes_draft_suggestions_on_minutes_attendance_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_draft_suggestions_on_minutes_attendance_entry_id ON public.minutes_draft_suggestions USING btree (minutes_attendance_entry_id);


--
-- Name: index_minutes_draft_suggestions_on_minutes_draft_run_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_draft_suggestions_on_minutes_draft_run_id ON public.minutes_draft_suggestions USING btree (minutes_draft_run_id);


--
-- Name: index_minutes_draft_suggestions_on_minutes_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_draft_suggestions_on_minutes_item_id ON public.minutes_draft_suggestions USING btree (minutes_item_id);


--
-- Name: index_minutes_draft_suggestions_on_minutes_section_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_draft_suggestions_on_minutes_section_id ON public.minutes_draft_suggestions USING btree (minutes_section_id);


--
-- Name: index_minutes_draft_suggestions_on_reviewed_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_draft_suggestions_on_reviewed_by_id ON public.minutes_draft_suggestions USING btree (reviewed_by_id);


--
-- Name: index_minutes_draft_suggestions_on_run_and_review_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_draft_suggestions_on_run_and_review_state ON public.minutes_draft_suggestions USING btree (minutes_draft_run_id, review_state);


--
-- Name: index_minutes_draft_suggestions_on_source_dated_agenda_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_draft_suggestions_on_source_dated_agenda_item_id ON public.minutes_draft_suggestions USING btree (source_dated_agenda_item_id);


--
-- Name: index_minutes_items_on_endeavor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_items_on_endeavor_id ON public.minutes_items USING btree (endeavor_id);


--
-- Name: index_minutes_items_on_minutes_section_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_items_on_minutes_section_id ON public.minutes_items USING btree (minutes_section_id);


--
-- Name: index_minutes_items_on_record_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_minutes_items_on_record_key ON public.minutes_items USING btree (record_key);


--
-- Name: index_minutes_items_on_section_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_minutes_items_on_section_and_position ON public.minutes_items USING btree (minutes_section_id, "position");


--
-- Name: index_minutes_items_on_source_dated_agenda_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_items_on_source_dated_agenda_item_id ON public.minutes_items USING btree (source_dated_agenda_item_id);


--
-- Name: index_minutes_lifecycle_events_on_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_lifecycle_events_on_actor_id ON public.minutes_lifecycle_events USING btree (actor_id);


--
-- Name: index_minutes_lifecycle_events_on_meeting_minutes_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_lifecycle_events_on_meeting_minutes_id ON public.minutes_lifecycle_events USING btree (meeting_minutes_id);


--
-- Name: index_minutes_lifecycle_events_on_minutes_revision_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_lifecycle_events_on_minutes_revision_id ON public.minutes_lifecycle_events USING btree (minutes_revision_id);


--
-- Name: index_minutes_lifecycle_events_on_recorded_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_lifecycle_events_on_recorded_by_id ON public.minutes_lifecycle_events USING btree (recorded_by_id);


--
-- Name: index_minutes_membership_approvals_on_approving_meeting_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_membership_approvals_on_approving_meeting_id ON public.minutes_membership_approvals USING btree (approving_meeting_id);


--
-- Name: index_minutes_membership_approvals_on_meeting_minutes_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_minutes_membership_approvals_on_meeting_minutes_id ON public.minutes_membership_approvals USING btree (meeting_minutes_id);


--
-- Name: index_minutes_membership_approvals_on_minutes_revision_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_minutes_membership_approvals_on_minutes_revision_id ON public.minutes_membership_approvals USING btree (minutes_revision_id);


--
-- Name: index_minutes_membership_approvals_on_recorded_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_membership_approvals_on_recorded_by_id ON public.minutes_membership_approvals USING btree (recorded_by_id);


--
-- Name: index_minutes_outcomes_on_item_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_minutes_outcomes_on_item_and_position ON public.minutes_outcomes USING btree (minutes_item_id, "position");


--
-- Name: index_minutes_outcomes_on_minutes_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_outcomes_on_minutes_item_id ON public.minutes_outcomes USING btree (minutes_item_id);


--
-- Name: index_minutes_outcomes_on_mover_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_outcomes_on_mover_person_id ON public.minutes_outcomes USING btree (mover_person_id);


--
-- Name: index_minutes_outcomes_on_seconder_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_outcomes_on_seconder_person_id ON public.minutes_outcomes USING btree (seconder_person_id);


--
-- Name: index_minutes_revisions_on_approved_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_revisions_on_approved_by_id ON public.minutes_revisions USING btree (approved_by_id);


--
-- Name: index_minutes_revisions_on_meeting_minutes_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_revisions_on_meeting_minutes_id ON public.minutes_revisions USING btree (meeting_minutes_id);


--
-- Name: index_minutes_revisions_on_meeting_minutes_id_and_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_minutes_revisions_on_meeting_minutes_id_and_number ON public.minutes_revisions USING btree (meeting_minutes_id, number);


--
-- Name: index_minutes_revisions_on_meeting_minutes_id_and_sha256; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_revisions_on_meeting_minutes_id_and_sha256 ON public.minutes_revisions USING btree (meeting_minutes_id, sha256);


--
-- Name: index_minutes_sections_on_meeting_minutes_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_sections_on_meeting_minutes_id ON public.minutes_sections USING btree (meeting_minutes_id);


--
-- Name: index_minutes_sections_on_minutes_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_minutes_sections_on_minutes_and_position ON public.minutes_sections USING btree (meeting_minutes_id, "position");


--
-- Name: index_minutes_sections_on_source_dated_agenda_section_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_minutes_sections_on_source_dated_agenda_section_id ON public.minutes_sections USING btree (source_dated_agenda_section_id);


--
-- Name: index_mt_agenda_items_on_type_and_catalog_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_mt_agenda_items_on_type_and_catalog_entry ON public.meeting_type_agenda_items USING btree (meeting_type_id, agenda_item_catalog_entry_id);


--
-- Name: index_mt_agenda_items_on_type_and_source_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_mt_agenda_items_on_type_and_source_key ON public.meeting_type_agenda_items USING btree (meeting_type_id, source_key) WHERE (source_key IS NOT NULL);


--
-- Name: index_official_action_confirmations_on_agent_access_token_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_official_action_confirmations_on_agent_access_token_id ON public.official_action_confirmations USING btree (agent_access_token_id);


--
-- Name: index_official_action_confirmations_on_meeting_minutes_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_official_action_confirmations_on_meeting_minutes_id ON public.official_action_confirmations USING btree (meeting_minutes_id);


--
-- Name: index_official_action_confirmations_on_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_official_action_confirmations_on_session_id ON public.official_action_confirmations USING btree (session_id);


--
-- Name: index_official_action_confirmations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_official_action_confirmations_on_user_id ON public.official_action_confirmations USING btree (user_id);


--
-- Name: index_passkey_credentials_on_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_passkey_credentials_on_external_id ON public.passkey_credentials USING btree (external_id);


--
-- Name: index_passkey_credentials_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_passkey_credentials_on_user_id ON public.passkey_credentials USING btree (user_id);


--
-- Name: index_people_on_email_address; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_people_on_email_address ON public.people USING btree (email_address);


--
-- Name: index_people_on_member_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_people_on_member_number ON public.people USING btree (member_number) WHERE (member_number IS NOT NULL);


--
-- Name: index_people_on_roster_email_address; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_people_on_roster_email_address ON public.people USING btree (roster_email_address);


--
-- Name: index_people_on_roster_member_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_people_on_roster_member_status ON public.people USING btree (roster_member_status);


--
-- Name: index_people_on_roster_paid_through_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_people_on_roster_paid_through_year ON public.people USING btree (roster_paid_through_year);


--
-- Name: index_people_on_roster_removed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_people_on_roster_removed_at ON public.people USING btree (roster_removed_at);


--
-- Name: index_permission_grants_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_permission_grants_on_user_id ON public.permission_grants USING btree (user_id);


--
-- Name: index_permission_grants_on_user_id_and_capability; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_permission_grants_on_user_id_and_capability ON public.permission_grants USING btree (user_id, capability);


--
-- Name: index_position_assignments_on_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_position_assignments_on_person_id ON public.position_assignments USING btree (person_id);


--
-- Name: index_position_assignments_on_position_title_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_position_assignments_on_position_title_id ON public.position_assignments USING btree (position_title_id);


--
-- Name: index_position_capabilities_on_title_and_capability; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_position_capabilities_on_title_and_capability ON public.position_capability_grants USING btree (position_title_id, capability);


--
-- Name: index_position_capability_grants_on_position_title_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_position_capability_grants_on_position_title_id ON public.position_capability_grants USING btree (position_title_id);


--
-- Name: index_position_titles_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_position_titles_on_organization_id ON public.position_titles USING btree (organization_id);


--
-- Name: index_position_titles_on_organization_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_position_titles_on_organization_id_and_name ON public.position_titles USING btree (organization_id, name);


--
-- Name: index_roster_imports_on_status_and_imported_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_roster_imports_on_status_and_imported_at ON public.roster_imports USING btree (status, imported_at);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_users_on_disabled_reason; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_disabled_reason ON public.users USING btree (disabled_reason);


--
-- Name: index_users_on_email_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email_address ON public.users USING btree (email_address);


--
-- Name: index_users_on_login_access_override; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_login_access_override ON public.users USING btree (login_access_override);


--
-- Name: index_users_on_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_person_id ON public.users USING btree (person_id);


--
-- Name: index_users_on_webauthn_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_webauthn_id ON public.users USING btree (webauthn_id);


--
-- Name: index_website_access_tokens_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_website_access_tokens_on_created_by_id ON public.website_access_tokens USING btree (created_by_id);


--
-- Name: index_website_access_tokens_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_website_access_tokens_on_organization_id ON public.website_access_tokens USING btree (organization_id);


--
-- Name: index_website_access_tokens_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_website_access_tokens_on_public_id ON public.website_access_tokens USING btree (public_id);


--
-- Name: index_website_access_tokens_on_revoked_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_website_access_tokens_on_revoked_by_id ON public.website_access_tokens USING btree (revoked_by_id);


--
-- Name: index_website_calendar_changes_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_website_calendar_changes_on_organization_id ON public.website_calendar_changes USING btree (organization_id);


--
-- Name: index_website_portraits_on_revision; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_website_portraits_on_revision ON public.website_portraits USING btree (revision);


--
-- Name: index_website_portraits_on_website_publication_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_website_portraits_on_website_publication_id ON public.website_portraits USING btree (website_publication_id);


--
-- Name: index_website_publication_events_on_website_publication_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_website_publication_events_on_website_publication_id ON public.website_publication_events USING btree (website_publication_id);


--
-- Name: index_website_publications_on_calendar_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_website_publications_on_calendar_event_id ON public.website_publications USING btree (calendar_event_id);


--
-- Name: index_website_publications_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_website_publications_on_organization_id ON public.website_publications USING btree (organization_id);


--
-- Name: index_website_publications_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_website_publications_on_public_id ON public.website_publications USING btree (public_id);


--
-- Name: one_active_endeavor_history_run; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX one_active_endeavor_history_run ON public.endeavor_history_runs USING btree (endeavor_id) WHERE ((status)::text = ANY ((ARRAY['pending'::character varying, 'running'::character varying])::text[]));


--
-- Name: unique_endeavor_edition_source; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_endeavor_edition_source ON public.endeavor_source_links USING btree (endeavor_history_edition_id, minutes_revision_id, record_key);


--
-- Name: website_featured_positions; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX website_featured_positions ON public.website_publications USING btree (organization_id, featured_position) WHERE (featured_position IS NOT NULL);


--
-- Name: endeavor_history_editions endeavor_history_editions_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER endeavor_history_editions_immutable BEFORE DELETE OR UPDATE ON public.endeavor_history_editions FOR EACH ROW EXECUTE FUNCTION public.protect_endeavor_history();


--
-- Name: endeavor_history_events endeavor_history_events_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER endeavor_history_events_immutable BEFORE DELETE OR UPDATE ON public.endeavor_history_events FOR EACH ROW EXECUTE FUNCTION public.protect_endeavor_history();


--
-- Name: endeavor_history_guidances endeavor_history_guidances_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER endeavor_history_guidances_immutable BEFORE DELETE OR UPDATE ON public.endeavor_history_guidances FOR EACH ROW EXECUTE FUNCTION public.protect_endeavor_history();


--
-- Name: endeavor_history_results endeavor_history_results_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER endeavor_history_results_immutable BEFORE DELETE OR UPDATE ON public.endeavor_history_results FOR EACH ROW EXECUTE FUNCTION public.protect_endeavor_history_result();


--
-- Name: endeavor_history_runs endeavor_history_run_protected; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER endeavor_history_run_protected BEFORE DELETE OR UPDATE ON public.endeavor_history_runs FOR EACH ROW EXECUTE FUNCTION public.protect_completed_endeavor_history_run();


--
-- Name: endeavor_source_links endeavor_source_links_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER endeavor_source_links_immutable BEFORE DELETE OR UPDATE ON public.endeavor_source_links FOR EACH ROW EXECUTE FUNCTION public.protect_endeavor_history();


--
-- Name: meeting_minutes meeting_minutes_membership_approved_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER meeting_minutes_membership_approved_immutable BEFORE DELETE OR UPDATE ON public.meeting_minutes FOR EACH ROW EXECUTE FUNCTION public.prevent_membership_approved_minutes_mutation();


--
-- Name: minutes_attestations minutes_attestations_append_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER minutes_attestations_append_only BEFORE DELETE OR UPDATE ON public.minutes_attestations FOR EACH ROW EXECUTE FUNCTION public.prevent_minutes_official_record_mutation();


--
-- Name: minutes_lifecycle_events minutes_lifecycle_events_append_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER minutes_lifecycle_events_append_only BEFORE DELETE OR UPDATE ON public.minutes_lifecycle_events FOR EACH ROW EXECUTE FUNCTION public.prevent_minutes_official_record_mutation();


--
-- Name: minutes_membership_approvals minutes_membership_approvals_append_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER minutes_membership_approvals_append_only BEFORE DELETE OR UPDATE ON public.minutes_membership_approvals FOR EACH ROW EXECUTE FUNCTION public.prevent_minutes_official_record_mutation();


--
-- Name: minutes_revisions minutes_revisions_append_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER minutes_revisions_append_only BEFORE DELETE OR UPDATE ON public.minutes_revisions FOR EACH ROW EXECUTE FUNCTION public.prevent_minutes_official_record_mutation();


--
-- Name: meeting_type_agenda_sections fk_rails_006a9028b4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_type_agenda_sections
    ADD CONSTRAINT fk_rails_006a9028b4 FOREIGN KEY (meeting_type_id) REFERENCES public.meeting_types(id);


--
-- Name: dated_agendas fk_rails_03be9462a4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agendas
    ADD CONSTRAINT fk_rails_03be9462a4 FOREIGN KEY (meeting_type_id) REFERENCES public.meeting_types(id);


--
-- Name: endeavor_history_runs fk_rails_04674188df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_runs
    ADD CONSTRAINT fk_rails_04674188df FOREIGN KEY (requested_by_id) REFERENCES public.users(id);


--
-- Name: website_publications fk_rails_04ac4d2afc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.website_publications
    ADD CONSTRAINT fk_rails_04ac4d2afc FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: website_portraits fk_rails_04adf5e325; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.website_portraits
    ADD CONSTRAINT fk_rails_04adf5e325 FOREIGN KEY (website_publication_id) REFERENCES public.website_publications(id);


--
-- Name: minutes_draft_runs fk_rails_04cb9972eb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_draft_runs
    ADD CONSTRAINT fk_rails_04cb9972eb FOREIGN KEY (meeting_minutes_id) REFERENCES public.meeting_minutes(id);


--
-- Name: endeavor_tasks fk_rails_051d33126e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_tasks
    ADD CONSTRAINT fk_rails_051d33126e FOREIGN KEY (updated_by_id) REFERENCES public.users(id);


--
-- Name: dated_agendas fk_rails_07b5b12e09; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agendas
    ADD CONSTRAINT fk_rails_07b5b12e09 FOREIGN KEY (meeting_id) REFERENCES public.meetings(id);


--
-- Name: meetings fk_rails_0842ae6524; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT fk_rails_0842ae6524 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: endeavor_history_events fk_rails_0cf82669d9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_events
    ADD CONSTRAINT fk_rails_0cf82669d9 FOREIGN KEY (actor_id) REFERENCES public.users(id);


--
-- Name: endeavor_history_events fk_rails_101cccec62; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_events
    ADD CONSTRAINT fk_rails_101cccec62 FOREIGN KEY (endeavor_id) REFERENCES public.endeavors(id);


--
-- Name: calendar_events fk_rails_13815d888f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT fk_rails_13815d888f FOREIGN KEY (endeavor_id) REFERENCES public.endeavors(id);


--
-- Name: minutes_membership_approvals fk_rails_1847f2c0de; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_membership_approvals
    ADD CONSTRAINT fk_rails_1847f2c0de FOREIGN KEY (recorded_by_id) REFERENCES public.users(id);


--
-- Name: minutes_items fk_rails_18a0a4df99; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_items
    ADD CONSTRAINT fk_rails_18a0a4df99 FOREIGN KEY (endeavor_id) REFERENCES public.endeavors(id);


--
-- Name: official_action_confirmations fk_rails_1a0205fec4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.official_action_confirmations
    ADD CONSTRAINT fk_rails_1a0205fec4 FOREIGN KEY (agent_access_token_id) REFERENCES public.agent_access_tokens(id);


--
-- Name: minutes_outcomes fk_rails_1c2f86c356; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_outcomes
    ADD CONSTRAINT fk_rails_1c2f86c356 FOREIGN KEY (minutes_item_id) REFERENCES public.minutes_items(id);


--
-- Name: passkey_credentials fk_rails_225250860c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.passkey_credentials
    ADD CONSTRAINT fk_rails_225250860c FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: calendar_events fk_rails_22b0dbcb90; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT fk_rails_22b0dbcb90 FOREIGN KEY (updated_by_id) REFERENCES public.users(id);


--
-- Name: minutes_draft_suggestions fk_rails_25066101ff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_draft_suggestions
    ADD CONSTRAINT fk_rails_25066101ff FOREIGN KEY (minutes_attendance_entry_id) REFERENCES public.minutes_attendance_entries(id);


--
-- Name: minutes_lifecycle_events fk_rails_2741176eb1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_lifecycle_events
    ADD CONSTRAINT fk_rails_2741176eb1 FOREIGN KEY (actor_id) REFERENCES public.users(id);


--
-- Name: meeting_transcripts fk_rails_2791212307; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_transcripts
    ADD CONSTRAINT fk_rails_2791212307 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: endeavor_history_runs fk_rails_28043369ae; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_runs
    ADD CONSTRAINT fk_rails_28043369ae FOREIGN KEY (endeavor_id) REFERENCES public.endeavors(id);


--
-- Name: meeting_type_agenda_items fk_rails_2832353389; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_type_agenda_items
    ADD CONSTRAINT fk_rails_2832353389 FOREIGN KEY (meeting_type_agenda_section_id) REFERENCES public.meeting_type_agenda_sections(id);


--
-- Name: dated_agendas fk_rails_297f64fb9f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agendas
    ADD CONSTRAINT fk_rails_297f64fb9f FOREIGN KEY (published_by_id) REFERENCES public.users(id);


--
-- Name: dated_agenda_roll_call_entries fk_rails_2dbf881a45; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agenda_roll_call_entries
    ADD CONSTRAINT fk_rails_2dbf881a45 FOREIGN KEY (position_title_id) REFERENCES public.position_titles(id) ON DELETE SET NULL;


--
-- Name: dated_agenda_items fk_rails_327c812377; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agenda_items
    ADD CONSTRAINT fk_rails_327c812377 FOREIGN KEY (endeavor_id) REFERENCES public.endeavors(id);


--
-- Name: endeavor_history_results fk_rails_328d046ff8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_results
    ADD CONSTRAINT fk_rails_328d046ff8 FOREIGN KEY (endeavor_history_run_id) REFERENCES public.endeavor_history_runs(id);


--
-- Name: dated_agenda_items fk_rails_336847096d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agenda_items
    ADD CONSTRAINT fk_rails_336847096d FOREIGN KEY (dated_agenda_id) REFERENCES public.dated_agendas(id);


--
-- Name: endeavor_tasks fk_rails_33d9b69a80; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_tasks
    ADD CONSTRAINT fk_rails_33d9b69a80 FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: endeavor_source_links fk_rails_35f78e1da4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_source_links
    ADD CONSTRAINT fk_rails_35f78e1da4 FOREIGN KEY (minutes_revision_id) REFERENCES public.minutes_revisions(id);


--
-- Name: endeavors fk_rails_36078b09cd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavors
    ADD CONSTRAINT fk_rails_36078b09cd FOREIGN KEY (meeting_body_id) REFERENCES public.meeting_bodies(id);


--
-- Name: position_assignments fk_rails_37704d324e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.position_assignments
    ADD CONSTRAINT fk_rails_37704d324e FOREIGN KEY (person_id) REFERENCES public.people(id);


--
-- Name: endeavor_history_editions fk_rails_38488e2325; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_editions
    ADD CONSTRAINT fk_rails_38488e2325 FOREIGN KEY (endeavor_history_run_id) REFERENCES public.endeavor_history_runs(id);


--
-- Name: permission_grants fk_rails_3bca93d0dd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission_grants
    ADD CONSTRAINT fk_rails_3bca93d0dd FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: meeting_transcripts fk_rails_3cb3abcbc3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_transcripts
    ADD CONSTRAINT fk_rails_3cb3abcbc3 FOREIGN KEY (purged_by_id) REFERENCES public.users(id);


--
-- Name: endeavor_history_events fk_rails_3eb571fd7d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_events
    ADD CONSTRAINT fk_rails_3eb571fd7d FOREIGN KEY (endeavor_history_run_id) REFERENCES public.endeavor_history_runs(id);


--
-- Name: dated_agenda_roll_call_entries fk_rails_3fc673a2a8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agenda_roll_call_entries
    ADD CONSTRAINT fk_rails_3fc673a2a8 FOREIGN KEY (dated_agenda_item_id) REFERENCES public.dated_agenda_items(id);


--
-- Name: agent_api_executions fk_rails_421734d1e5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_api_executions
    ADD CONSTRAINT fk_rails_421734d1e5 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: minutes_lifecycle_events fk_rails_45a3b00bf0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_lifecycle_events
    ADD CONSTRAINT fk_rails_45a3b00bf0 FOREIGN KEY (recorded_by_id) REFERENCES public.users(id);


--
-- Name: dated_agenda_items fk_rails_461edab289; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agenda_items
    ADD CONSTRAINT fk_rails_461edab289 FOREIGN KEY (agenda_item_catalog_entry_id) REFERENCES public.agenda_item_catalog_entries(id);


--
-- Name: endeavor_history_guidances fk_rails_492f4de4eb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_guidances
    ADD CONSTRAINT fk_rails_492f4de4eb FOREIGN KEY (endeavor_id) REFERENCES public.endeavors(id);


--
-- Name: minutes_attendance_entries fk_rails_4da5b8b696; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_attendance_entries
    ADD CONSTRAINT fk_rails_4da5b8b696 FOREIGN KEY (dated_agenda_roll_call_entry_id) REFERENCES public.dated_agenda_roll_call_entries(id);


--
-- Name: minutes_draft_runs fk_rails_507f09b832; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_draft_runs
    ADD CONSTRAINT fk_rails_507f09b832 FOREIGN KEY (retry_of_id) REFERENCES public.minutes_draft_runs(id);


--
-- Name: minutes_attendance_entries fk_rails_509464c232; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_attendance_entries
    ADD CONSTRAINT fk_rails_509464c232 FOREIGN KEY (meeting_minutes_id) REFERENCES public.meeting_minutes(id);


--
-- Name: minutes_membership_approvals fk_rails_52f42fd3e0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_membership_approvals
    ADD CONSTRAINT fk_rails_52f42fd3e0 FOREIGN KEY (official_action_confirmation_id) REFERENCES public.official_action_confirmations(id);


--
-- Name: minutes_draft_runs fk_rails_5adeca557e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_draft_runs
    ADD CONSTRAINT fk_rails_5adeca557e FOREIGN KEY (discarded_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: dated_agenda_roll_call_entries fk_rails_5f41172ffc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agenda_roll_call_entries
    ADD CONSTRAINT fk_rails_5f41172ffc FOREIGN KEY (person_id) REFERENCES public.people(id) ON DELETE SET NULL;


--
-- Name: endeavors fk_rails_60e6eacb75; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavors
    ADD CONSTRAINT fk_rails_60e6eacb75 FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: website_publications fk_rails_62fa4e0c38; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.website_publications
    ADD CONSTRAINT fk_rails_62fa4e0c38 FOREIGN KEY (calendar_event_id) REFERENCES public.calendar_events(id);


--
-- Name: minutes_items fk_rails_63d18cccaf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_items
    ADD CONSTRAINT fk_rails_63d18cccaf FOREIGN KEY (minutes_section_id) REFERENCES public.minutes_sections(id);


--
-- Name: endeavor_history_guidances fk_rails_66de8fa2a2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_guidances
    ADD CONSTRAINT fk_rails_66de8fa2a2 FOREIGN KEY (author_id) REFERENCES public.users(id);


--
-- Name: minutes_draft_suggestions fk_rails_69579d1cf7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_draft_suggestions
    ADD CONSTRAINT fk_rails_69579d1cf7 FOREIGN KEY (reviewed_by_id) REFERENCES public.users(id);


--
-- Name: meeting_transcripts fk_rails_69b2df064c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_transcripts
    ADD CONSTRAINT fk_rails_69b2df064c FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: minutes_membership_approvals fk_rails_69dbb1e8a4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_membership_approvals
    ADD CONSTRAINT fk_rails_69dbb1e8a4 FOREIGN KEY (minutes_revision_id) REFERENCES public.minutes_revisions(id);


--
-- Name: dated_agendas fk_rails_6ad10da2fc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agendas
    ADD CONSTRAINT fk_rails_6ad10da2fc FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: meeting_types fk_rails_6ccee74691; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_types
    ADD CONSTRAINT fk_rails_6ccee74691 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: calendar_events fk_rails_6cdcb76531; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT fk_rails_6cdcb76531 FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: minutes_attestations fk_rails_75aa095ac0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_attestations
    ADD CONSTRAINT fk_rails_75aa095ac0 FOREIGN KEY (minutes_revision_id) REFERENCES public.minutes_revisions(id);


--
-- Name: endeavor_history_results fk_rails_7685ece73d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_results
    ADD CONSTRAINT fk_rails_7685ece73d FOREIGN KEY (endeavor_id) REFERENCES public.endeavors(id);


--
-- Name: position_titles fk_rails_790b37bf69; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.position_titles
    ADD CONSTRAINT fk_rails_790b37bf69 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: dated_agenda_items fk_rails_7b3e1aa1e1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agenda_items
    ADD CONSTRAINT fk_rails_7b3e1aa1e1 FOREIGN KEY (meeting_type_agenda_item_id) REFERENCES public.meeting_type_agenda_items(id);


--
-- Name: dated_agenda_items fk_rails_82c208cf20; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agenda_items
    ADD CONSTRAINT fk_rails_82c208cf20 FOREIGN KEY (dated_agenda_section_id) REFERENCES public.dated_agenda_sections(id);


--
-- Name: minutes_revisions fk_rails_831609703e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_revisions
    ADD CONSTRAINT fk_rails_831609703e FOREIGN KEY (approved_by_id) REFERENCES public.users(id);


--
-- Name: dated_agenda_sections fk_rails_846b265f4d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agenda_sections
    ADD CONSTRAINT fk_rails_846b265f4d FOREIGN KEY (dated_agenda_id) REFERENCES public.dated_agendas(id);


--
-- Name: agent_access_tokens fk_rails_87e7fccb72; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_access_tokens
    ADD CONSTRAINT fk_rails_87e7fccb72 FOREIGN KEY (revoked_by_id) REFERENCES public.users(id);


--
-- Name: magic_links fk_rails_88e5affde0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.magic_links
    ADD CONSTRAINT fk_rails_88e5affde0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: minutes_items fk_rails_88e96753d9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_items
    ADD CONSTRAINT fk_rails_88e96753d9 FOREIGN KEY (source_dated_agenda_item_id) REFERENCES public.dated_agenda_items(id);


--
-- Name: website_access_tokens fk_rails_8cda34eefb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.website_access_tokens
    ADD CONSTRAINT fk_rails_8cda34eefb FOREIGN KEY (revoked_by_id) REFERENCES public.users(id);


--
-- Name: minutes_membership_approvals fk_rails_8e0e21ab55; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_membership_approvals
    ADD CONSTRAINT fk_rails_8e0e21ab55 FOREIGN KEY (meeting_minutes_id) REFERENCES public.meeting_minutes(id);


--
-- Name: endeavor_updates fk_rails_8ea80fc3d4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_updates
    ADD CONSTRAINT fk_rails_8ea80fc3d4 FOREIGN KEY (endeavor_id) REFERENCES public.endeavors(id);


--
-- Name: calendar_events fk_rails_90c7e652b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT fk_rails_90c7e652b9 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: minutes_sections fk_rails_92b681d0cf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_sections
    ADD CONSTRAINT fk_rails_92b681d0cf FOREIGN KEY (source_dated_agenda_section_id) REFERENCES public.dated_agenda_sections(id);


--
-- Name: position_capability_grants fk_rails_98e291697e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.position_capability_grants
    ADD CONSTRAINT fk_rails_98e291697e FOREIGN KEY (position_title_id) REFERENCES public.position_titles(id) ON DELETE CASCADE;


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: minutes_outcomes fk_rails_997cfcf281; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_outcomes
    ADD CONSTRAINT fk_rails_997cfcf281 FOREIGN KEY (seconder_person_id) REFERENCES public.people(id) ON DELETE SET NULL;


--
-- Name: minutes_attestations fk_rails_99c63161b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_attestations
    ADD CONSTRAINT fk_rails_99c63161b9 FOREIGN KEY (attested_by_id) REFERENCES public.users(id);


--
-- Name: meeting_transcripts fk_rails_9bf2568960; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_transcripts
    ADD CONSTRAINT fk_rails_9bf2568960 FOREIGN KEY (meeting_id) REFERENCES public.meetings(id);


--
-- Name: meeting_minutes fk_rails_9c00cfa91f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_minutes
    ADD CONSTRAINT fk_rails_9c00cfa91f FOREIGN KEY (meeting_type_id) REFERENCES public.meeting_types(id);


--
-- Name: minutes_attestations fk_rails_9c3907e2ea; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_attestations
    ADD CONSTRAINT fk_rails_9c3907e2ea FOREIGN KEY (official_action_confirmation_id) REFERENCES public.official_action_confirmations(id);


--
-- Name: magic_links fk_rails_9d373c9815; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.magic_links
    ADD CONSTRAINT fk_rails_9d373c9815 FOREIGN KEY (session_id) REFERENCES public.sessions(id);


--
-- Name: minutes_sections fk_rails_9d6fde16b5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_sections
    ADD CONSTRAINT fk_rails_9d6fde16b5 FOREIGN KEY (meeting_minutes_id) REFERENCES public.meeting_minutes(id);


--
-- Name: official_action_confirmations fk_rails_9d7d4f7327; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.official_action_confirmations
    ADD CONSTRAINT fk_rails_9d7d4f7327 FOREIGN KEY (session_id) REFERENCES public.sessions(id);


--
-- Name: minutes_draft_suggestions fk_rails_9db0750ccc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_draft_suggestions
    ADD CONSTRAINT fk_rails_9db0750ccc FOREIGN KEY (minutes_section_id) REFERENCES public.minutes_sections(id);


--
-- Name: website_calendar_changes fk_rails_9e5ad00af8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.website_calendar_changes
    ADD CONSTRAINT fk_rails_9e5ad00af8 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: minutes_attendance_entries fk_rails_9ef83467d6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_attendance_entries
    ADD CONSTRAINT fk_rails_9ef83467d6 FOREIGN KEY (person_id) REFERENCES public.people(id) ON DELETE SET NULL;


--
-- Name: meeting_type_agenda_items fk_rails_a05cfea0fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_type_agenda_items
    ADD CONSTRAINT fk_rails_a05cfea0fd FOREIGN KEY (agenda_item_catalog_entry_id) REFERENCES public.agenda_item_catalog_entries(id);


--
-- Name: endeavor_tasks fk_rails_a114d9ed60; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_tasks
    ADD CONSTRAINT fk_rails_a114d9ed60 FOREIGN KEY (endeavor_id) REFERENCES public.endeavors(id);


--
-- Name: meeting_minutes fk_rails_a15d2607fb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_minutes
    ADD CONSTRAINT fk_rails_a15d2607fb FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: endeavor_source_links fk_rails_a1d4b30b56; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_source_links
    ADD CONSTRAINT fk_rails_a1d4b30b56 FOREIGN KEY (endeavor_id) REFERENCES public.endeavors(id);


--
-- Name: endeavor_source_links fk_rails_a2853acb0a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_source_links
    ADD CONSTRAINT fk_rails_a2853acb0a FOREIGN KEY (endeavor_history_edition_id) REFERENCES public.endeavor_history_editions(id);


--
-- Name: dated_agendas fk_rails_a3eed774af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agendas
    ADD CONSTRAINT fk_rails_a3eed774af FOREIGN KEY (approved_by_id) REFERENCES public.users(id);


--
-- Name: position_assignments fk_rails_a67b47cb8e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.position_assignments
    ADD CONSTRAINT fk_rails_a67b47cb8e FOREIGN KEY (position_title_id) REFERENCES public.position_titles(id);


--
-- Name: agent_api_executions fk_rails_a7f8df2144; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_api_executions
    ADD CONSTRAINT fk_rails_a7f8df2144 FOREIGN KEY (agent_access_token_id) REFERENCES public.agent_access_tokens(id);


--
-- Name: minutes_draft_runs fk_rails_a9761f93a9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_draft_runs
    ADD CONSTRAINT fk_rails_a9761f93a9 FOREIGN KEY (meeting_transcript_id) REFERENCES public.meeting_transcripts(id);


--
-- Name: minutes_lifecycle_events fk_rails_aa011690e6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_lifecycle_events
    ADD CONSTRAINT fk_rails_aa011690e6 FOREIGN KEY (official_action_confirmation_id) REFERENCES public.official_action_confirmations(id);


--
-- Name: meeting_minutes fk_rails_ac0729233e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_minutes
    ADD CONSTRAINT fk_rails_ac0729233e FOREIGN KEY (current_revision_id) REFERENCES public.minutes_revisions(id);


--
-- Name: minutes_attestations fk_rails_aef373cb29; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_attestations
    ADD CONSTRAINT fk_rails_aef373cb29 FOREIGN KEY (recorded_by_id) REFERENCES public.users(id);


--
-- Name: loops_roster_syncs fk_rails_b08807c82a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loops_roster_syncs
    ADD CONSTRAINT fk_rails_b08807c82a FOREIGN KEY (requested_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: meeting_bodies fk_rails_b28ebf3690; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_bodies
    ADD CONSTRAINT fk_rails_b28ebf3690 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: meeting_minutes fk_rails_bba1117957; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_minutes
    ADD CONSTRAINT fk_rails_bba1117957 FOREIGN KEY (meeting_id) REFERENCES public.meetings(id);


--
-- Name: minutes_draft_suggestions fk_rails_be8d87e367; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_draft_suggestions
    ADD CONSTRAINT fk_rails_be8d87e367 FOREIGN KEY (minutes_item_id) REFERENCES public.minutes_items(id);


--
-- Name: minutes_draft_suggestions fk_rails_c32150ea65; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_draft_suggestions
    ADD CONSTRAINT fk_rails_c32150ea65 FOREIGN KEY (minutes_draft_run_id) REFERENCES public.minutes_draft_runs(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: endeavor_updates fk_rails_c7487de493; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_updates
    ADD CONSTRAINT fk_rails_c7487de493 FOREIGN KEY (author_id) REFERENCES public.users(id);


--
-- Name: agenda_item_catalog_entries fk_rails_c836793fe2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agenda_item_catalog_entries
    ADD CONSTRAINT fk_rails_c836793fe2 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: official_action_confirmations fk_rails_c9ce942b8c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.official_action_confirmations
    ADD CONSTRAINT fk_rails_c9ce942b8c FOREIGN KEY (meeting_minutes_id) REFERENCES public.meeting_minutes(id);


--
-- Name: meeting_minutes fk_rails_ca911c1b9d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_minutes
    ADD CONSTRAINT fk_rails_ca911c1b9d FOREIGN KEY (meeting_body_id) REFERENCES public.meeting_bodies(id);


--
-- Name: minutes_lifecycle_events fk_rails_cae04c4df6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_lifecycle_events
    ADD CONSTRAINT fk_rails_cae04c4df6 FOREIGN KEY (meeting_minutes_id) REFERENCES public.meeting_minutes(id);


--
-- Name: minutes_draft_runs fk_rails_cb62d01a54; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_draft_runs
    ADD CONSTRAINT fk_rails_cb62d01a54 FOREIGN KEY (requested_by_id) REFERENCES public.users(id);


--
-- Name: meeting_type_agenda_items fk_rails_cbe3266479; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_type_agenda_items
    ADD CONSTRAINT fk_rails_cbe3266479 FOREIGN KEY (meeting_type_id) REFERENCES public.meeting_types(id);


--
-- Name: meetings fk_rails_cc68a84ab4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT fk_rails_cc68a84ab4 FOREIGN KEY (meeting_body_id) REFERENCES public.meeting_bodies(id);


--
-- Name: endeavors fk_rails_cf32cd46bc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavors
    ADD CONSTRAINT fk_rails_cf32cd46bc FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: loops_roster_syncs fk_rails_d280fb9179; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loops_roster_syncs
    ADD CONSTRAINT fk_rails_d280fb9179 FOREIGN KEY (roster_import_id) REFERENCES public.roster_imports(id);


--
-- Name: website_publication_events fk_rails_d2c73446aa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.website_publication_events
    ADD CONSTRAINT fk_rails_d2c73446aa FOREIGN KEY (website_publication_id) REFERENCES public.website_publications(id);


--
-- Name: minutes_revisions fk_rails_d4c292c6b3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_revisions
    ADD CONSTRAINT fk_rails_d4c292c6b3 FOREIGN KEY (meeting_minutes_id) REFERENCES public.meeting_minutes(id);


--
-- Name: website_access_tokens fk_rails_d68c2688b8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.website_access_tokens
    ADD CONSTRAINT fk_rails_d68c2688b8 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: minutes_outcomes fk_rails_d9c6f1aace; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_outcomes
    ADD CONSTRAINT fk_rails_d9c6f1aace FOREIGN KEY (mover_person_id) REFERENCES public.people(id) ON DELETE SET NULL;


--
-- Name: endeavor_tasks fk_rails_dbabbfd2da; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_tasks
    ADD CONSTRAINT fk_rails_dbabbfd2da FOREIGN KEY (completed_by_id) REFERENCES public.users(id);


--
-- Name: meetings fk_rails_def283e7ca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT fk_rails_def283e7ca FOREIGN KEY (meeting_type_id) REFERENCES public.meeting_types(id);


--
-- Name: minutes_draft_suggestions fk_rails_e1554cd2dd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_draft_suggestions
    ADD CONSTRAINT fk_rails_e1554cd2dd FOREIGN KEY (source_dated_agenda_item_id) REFERENCES public.dated_agenda_items(id);


--
-- Name: dated_agenda_sections fk_rails_e70ffa8b9f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agenda_sections
    ADD CONSTRAINT fk_rails_e70ffa8b9f FOREIGN KEY (meeting_type_agenda_section_id) REFERENCES public.meeting_type_agenda_sections(id);


--
-- Name: minutes_lifecycle_events fk_rails_e92f8872e1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_lifecycle_events
    ADD CONSTRAINT fk_rails_e92f8872e1 FOREIGN KEY (minutes_revision_id) REFERENCES public.minutes_revisions(id);


--
-- Name: minutes_membership_approvals fk_rails_f2e5a11f98; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_membership_approvals
    ADD CONSTRAINT fk_rails_f2e5a11f98 FOREIGN KEY (approving_meeting_id) REFERENCES public.meetings(id);


--
-- Name: website_access_tokens fk_rails_f4d74abc1b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.website_access_tokens
    ADD CONSTRAINT fk_rails_f4d74abc1b FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: official_action_confirmations fk_rails_f6dcefa967; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.official_action_confirmations
    ADD CONSTRAINT fk_rails_f6dcefa967 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: endeavors fk_rails_f81671cb51; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavors
    ADD CONSTRAINT fk_rails_f81671cb51 FOREIGN KEY (completed_by_id) REFERENCES public.users(id);


--
-- Name: minutes_attendance_entries fk_rails_f8c1f95d0a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.minutes_attendance_entries
    ADD CONSTRAINT fk_rails_f8c1f95d0a FOREIGN KEY (position_title_id) REFERENCES public.position_titles(id) ON DELETE SET NULL;


--
-- Name: dated_agendas fk_rails_fa15b0adab; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agendas
    ADD CONSTRAINT fk_rails_fa15b0adab FOREIGN KEY (meeting_body_id) REFERENCES public.meeting_bodies(id);


--
-- Name: users fk_rails_fa67535741; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_fa67535741 FOREIGN KEY (person_id) REFERENCES public.people(id);


--
-- Name: dated_agendas fk_rails_fc92f76b63; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dated_agendas
    ADD CONSTRAINT fk_rails_fc92f76b63 FOREIGN KEY (reopened_by_id) REFERENCES public.users(id);


--
-- Name: endeavor_history_editions fk_rails_ff1b37a7af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endeavor_history_editions
    ADD CONSTRAINT fk_rails_ff1b37a7af FOREIGN KEY (endeavor_id) REFERENCES public.endeavors(id);


--
-- Name: agent_access_tokens fk_rails_ff33aac049; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_access_tokens
    ADD CONSTRAINT fk_rails_ff33aac049 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261004010000'),
('20261002010000'),
('20260930000000'),
('20260928000000'),
('20260927010000'),
('20260927000000'),
('20260915233000'),
('20260906050000'),
('20260906030000'),
('20260906020000'),
('20260906010000'),
('20260902010200'),
('20260902010100'),
('20260902010000'),
('20260901010000'),
('20260831030100'),
('20260831030000'),
('20260831020000'),
('20260831010000'),
('20260830080000'),
('20260830070000'),
('20260830060000'),
('20260830050000'),
('20260830040000'),
('20260830030000'),
('20260830020000'),
('20260830010000'),
('20260829060000'),
('20260829050000'),
('20260829040000'),
('20260829030000'),
('20260829020000'),
('20260829010000'),
('20260824010000'),
('20260822050000'),
('20260822040000'),
('20260822030000'),
('20260822020000'),
('20260822010000'),
('20260822000000'),
('20260718001000'),
('20260718000000'),
('20260713020100'),
('20260713020000'),
('20260713010000'),
('20260712141403'),
('20260712000000'),
('20260711190002'),
('20260711190001'),
('20260711190000'),
('20260711171917'),
('20260711080000'),
('20260711070000'),
('20260711060000'),
('20260711050000'),
('20260711040000'),
('20260711030200'),
('20260711030159');
