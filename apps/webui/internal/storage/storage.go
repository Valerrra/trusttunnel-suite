package storage

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"golang.org/x/crypto/bcrypt"
	_ "modernc.org/sqlite"
)

type Storage struct {
	db *sql.DB
}

type User struct {
	ID        int64
	Username  string
	CreatedAt time.Time
}

type Session struct {
	Token     string
	UserID    int64
	ExpiresAt time.Time
	CreatedAt time.Time
}

type Client struct {
	ID                 int64
	DisplayName        string
	Hostname           string
	Addresses          []string
	Username           string
	Password           string
	CustomSNI          string
	HasIPv6            bool
	SkipVerification   bool
	CertificatePEM     string
	UpstreamProtocol   string
	AntiDPI            bool
	ClientRandomPrefix string
	CreatedAt          time.Time
	UpdatedAt          time.Time
	TrafficRXBytes     uint64
	TrafficTXBytes     uint64
	ActiveConnections  int
	StatsAvailable     bool
	StatsUpdatedAt     time.Time
}

type Cascade struct {
	ID                 int64
	DisplayName        string
	Hostname           string
	Addresses          []string
	Username           string
	Password           string
	CustomSNI          string
	SkipVerification   bool
	CertificatePEM     string
	UpstreamProtocol   string
	AntiDPI            bool
	ClientRandomPrefix string
	Enabled            bool
	Notes              string
	CreatedAt          time.Time
	UpdatedAt          time.Time
}

type ZapretProfile struct {
	ID           int64
	DisplayName  string
	StrategyName string
	ScriptPath   string
	Args         string
	Enabled      bool
	Notes        string
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

type RoutingRule struct {
	ID              int64
	DisplayName     string
	MatchType       string
	MatchValue      string
	Action          string
	CascadeID       int64
	ZapretProfileID int64
	Enabled         bool
	Priority        int
	Notes           string
	CreatedAt       time.Time
	UpdatedAt       time.Time
}

type RoutingDataset struct {
	Kind        string
	DisplayName string
	SourceURL   string
	LocalPath   string
	LastError   string
	UpdatedAt   time.Time
	Available   bool
}

type DashboardStats struct {
	ClientCount  int
	ActiveTokens int
	UserCount    int
}

type AuditEntry struct {
	ID        int64
	Actor     string
	Action    string
	Target    string
	Details   string
	CreatedAt time.Time
}

func Open(path string) (*Storage, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, fmt.Errorf("create db dir: %w", err)
	}

	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, fmt.Errorf("open sqlite: %w", err)
	}

	store := &Storage{db: db}
	if err := store.initSchema(); err != nil {
		_ = db.Close()
		return nil, err
	}

	return store, nil
}

func (s *Storage) Close() error {
	return s.db.Close()
}

func (s *Storage) initSchema() error {
	schema := []string{
		`PRAGMA journal_mode = WAL;`,
		`CREATE TABLE IF NOT EXISTS users (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			username TEXT NOT NULL UNIQUE,
			password_hash TEXT NOT NULL,
			created_at TEXT NOT NULL
		);`,
		`CREATE TABLE IF NOT EXISTS sessions (
			token TEXT PRIMARY KEY,
			user_id INTEGER NOT NULL,
			expires_at TEXT NOT NULL,
			created_at TEXT NOT NULL,
			FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
		);`,
		`CREATE TABLE IF NOT EXISTS clients (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			display_name TEXT NOT NULL,
			hostname TEXT NOT NULL,
			addresses_json TEXT NOT NULL,
			username TEXT NOT NULL,
			password TEXT NOT NULL,
			custom_sni TEXT NOT NULL DEFAULT '',
			has_ipv6 INTEGER NOT NULL DEFAULT 1,
			skip_verification INTEGER NOT NULL DEFAULT 0,
			certificate_pem TEXT NOT NULL DEFAULT '',
			upstream_protocol TEXT NOT NULL DEFAULT 'http2',
			anti_dpi INTEGER NOT NULL DEFAULT 0,
			client_random_prefix TEXT NOT NULL DEFAULT '',
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		);`,
		`CREATE TABLE IF NOT EXISTS cascades (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			display_name TEXT NOT NULL,
			hostname TEXT NOT NULL,
			addresses_json TEXT NOT NULL,
			username TEXT NOT NULL,
			password TEXT NOT NULL,
			custom_sni TEXT NOT NULL DEFAULT '',
			skip_verification INTEGER NOT NULL DEFAULT 0,
			certificate_pem TEXT NOT NULL DEFAULT '',
			upstream_protocol TEXT NOT NULL DEFAULT 'http2',
			anti_dpi INTEGER NOT NULL DEFAULT 0,
			client_random_prefix TEXT NOT NULL DEFAULT '',
			enabled INTEGER NOT NULL DEFAULT 1,
			notes TEXT NOT NULL DEFAULT '',
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		);`,
		`CREATE TABLE IF NOT EXISTS zapret_profiles (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			display_name TEXT NOT NULL,
			strategy_name TEXT NOT NULL DEFAULT '',
			script_path TEXT NOT NULL DEFAULT '',
			args TEXT NOT NULL DEFAULT '',
			enabled INTEGER NOT NULL DEFAULT 1,
			notes TEXT NOT NULL DEFAULT '',
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		);`,
		`CREATE TABLE IF NOT EXISTS routing_rules (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			display_name TEXT NOT NULL,
			match_type TEXT NOT NULL,
			match_value TEXT NOT NULL,
			action TEXT NOT NULL,
			cascade_id INTEGER NOT NULL DEFAULT 0,
			zapret_profile_id INTEGER NOT NULL DEFAULT 0,
			enabled INTEGER NOT NULL DEFAULT 1,
			priority INTEGER NOT NULL DEFAULT 100,
			notes TEXT NOT NULL DEFAULT '',
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		);`,
		`CREATE TABLE IF NOT EXISTS routing_datasets (
			kind TEXT PRIMARY KEY,
			display_name TEXT NOT NULL,
			source_url TEXT NOT NULL,
			local_path TEXT NOT NULL,
			last_error TEXT NOT NULL DEFAULT '',
			updated_at TEXT NOT NULL DEFAULT '',
			available INTEGER NOT NULL DEFAULT 0
		);`,
		`CREATE TABLE IF NOT EXISTS audit_log (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			actor TEXT NOT NULL,
			action TEXT NOT NULL,
			target TEXT NOT NULL,
			details TEXT NOT NULL DEFAULT '',
			created_at TEXT NOT NULL
		);`,
		`CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions(expires_at);`,
		`CREATE INDEX IF NOT EXISTS idx_clients_updated_at ON clients(updated_at DESC);`,
		`CREATE INDEX IF NOT EXISTS idx_cascades_updated_at ON cascades(updated_at DESC);`,
		`CREATE INDEX IF NOT EXISTS idx_zapret_profiles_updated_at ON zapret_profiles(updated_at DESC);`,
		`CREATE INDEX IF NOT EXISTS idx_routing_rules_priority ON routing_rules(priority ASC, updated_at DESC);`,
		`CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON audit_log(created_at DESC);`,
	}

	for _, stmt := range schema {
		if _, err := s.db.Exec(stmt); err != nil {
			return fmt.Errorf("init schema: %w", err)
		}
	}

	return nil
}

func (s *Storage) EnsureBootstrapAdmin(username, configuredPassword string) (bool, string, error) {
	var count int
	if err := s.db.QueryRow(`SELECT COUNT(*) FROM users`).Scan(&count); err != nil {
		return false, "", err
	}
	if count > 0 {
		return false, "", nil
	}

	password := configuredPassword
	if password == "" {
		generated, err := generatePassword()
		if err != nil {
			return false, "", err
		}
		password = generated
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return false, "", err
	}

	now := time.Now().UTC().Format(time.RFC3339)
	if _, err := s.db.Exec(
		`INSERT INTO users (username, password_hash, created_at) VALUES (?, ?, ?)`,
		username,
		string(hash),
		now,
	); err != nil {
		return false, "", err
	}

	if err := s.AppendAudit("system", "bootstrap-admin", username, "initial admin account created"); err != nil {
		return false, "", err
	}

	return true, password, nil
}

func (s *Storage) AuthenticateUser(ctx context.Context, username, password string) (*User, error) {
	var (
		id           int64
		passwordHash string
		createdAtRaw string
	)

	err := s.db.QueryRowContext(
		ctx,
		`SELECT id, password_hash, created_at FROM users WHERE username = ?`,
		username,
	).Scan(&id, &passwordHash, &createdAtRaw)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}

	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(password)); err != nil {
		return nil, nil
	}

	createdAt, err := time.Parse(time.RFC3339, createdAtRaw)
	if err != nil {
		return nil, err
	}

	return &User{
		ID:        id,
		Username:  username,
		CreatedAt: createdAt,
	}, nil
}

func (s *Storage) CreateSession(ctx context.Context, userID int64, ttl time.Duration) (string, error) {
	token, err := generatePassword()
	if err != nil {
		return "", err
	}

	now := time.Now().UTC()
	expiresAt := now.Add(ttl)

	if _, err := s.db.ExecContext(
		ctx,
		`INSERT INTO sessions (token, user_id, expires_at, created_at) VALUES (?, ?, ?, ?)`,
		token,
		userID,
		expiresAt.Format(time.RFC3339),
		now.Format(time.RFC3339),
	); err != nil {
		return "", err
	}

	return token, nil
}

func (s *Storage) DeleteSession(ctx context.Context, token string) error {
	if token == "" {
		return nil
	}
	_, err := s.db.ExecContext(ctx, `DELETE FROM sessions WHERE token = ?`, token)
	return err
}

func (s *Storage) GetUserBySession(ctx context.Context, token string) (*User, error) {
	if token == "" {
		return nil, nil
	}

	now := time.Now().UTC().Format(time.RFC3339)
	var (
		id           int64
		username     string
		createdAtRaw string
	)

	err := s.db.QueryRowContext(
		ctx,
		`SELECT u.id, u.username, u.created_at
		 FROM sessions s
		 JOIN users u ON u.id = s.user_id
		 WHERE s.token = ? AND s.expires_at > ?`,
		token,
		now,
	).Scan(&id, &username, &createdAtRaw)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}

	createdAt, err := time.Parse(time.RFC3339, createdAtRaw)
	if err != nil {
		return nil, err
	}

	return &User{
		ID:        id,
		Username:  username,
		CreatedAt: createdAt,
	}, nil
}

func (s *Storage) DashboardStats(ctx context.Context) (DashboardStats, error) {
	stats := DashboardStats{}
	now := time.Now().UTC().Format(time.RFC3339)

	queries := []struct {
		query string
		dest  *int
	}{
		{`SELECT COUNT(*) FROM clients`, &stats.ClientCount},
		{`SELECT COUNT(*) FROM users`, &stats.UserCount},
		{`SELECT COUNT(*) FROM sessions WHERE expires_at > ?`, &stats.ActiveTokens},
	}

	for _, item := range queries {
		var err error
		if item.query == `SELECT COUNT(*) FROM sessions WHERE expires_at > ?` {
			err = s.db.QueryRowContext(ctx, item.query, now).Scan(item.dest)
		} else {
			err = s.db.QueryRowContext(ctx, item.query).Scan(item.dest)
		}
		if err != nil {
			return stats, err
		}
	}

	return stats, nil
}

func (s *Storage) ListClients(ctx context.Context) ([]Client, error) {
	rows, err := s.db.QueryContext(
		ctx,
		`SELECT id, display_name, hostname, addresses_json, username, password, custom_sni,
		        has_ipv6, skip_verification, certificate_pem, upstream_protocol,
		        anti_dpi, client_random_prefix, created_at, updated_at
		 FROM clients
		 ORDER BY updated_at DESC, id DESC`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var clients []Client
	for rows.Next() {
		client, err := scanClient(rows)
		if err != nil {
			return nil, err
		}
		clients = append(clients, client)
	}

	return clients, rows.Err()
}

func (s *Storage) GetClient(ctx context.Context, id int64) (*Client, error) {
	row := s.db.QueryRowContext(
		ctx,
		`SELECT id, display_name, hostname, addresses_json, username, password, custom_sni,
		        has_ipv6, skip_verification, certificate_pem, upstream_protocol,
		        anti_dpi, client_random_prefix, created_at, updated_at
		 FROM clients
		 WHERE id = ?`,
		id,
	)

	client, err := scanClient(row)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}

	return &client, nil
}

func (s *Storage) CreateClient(ctx context.Context, client *Client) (int64, error) {
	addressesJSON, err := json.Marshal(client.Addresses)
	if err != nil {
		return 0, err
	}

	now := time.Now().UTC().Format(time.RFC3339)
	result, err := s.db.ExecContext(
		ctx,
		`INSERT INTO clients (
			display_name, hostname, addresses_json, username, password, custom_sni,
			has_ipv6, skip_verification, certificate_pem, upstream_protocol, anti_dpi,
			client_random_prefix, created_at, updated_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		client.DisplayName,
		client.Hostname,
		string(addressesJSON),
		client.Username,
		client.Password,
		client.CustomSNI,
		boolToInt(client.HasIPv6),
		boolToInt(client.SkipVerification),
		client.CertificatePEM,
		client.UpstreamProtocol,
		boolToInt(client.AntiDPI),
		client.ClientRandomPrefix,
		now,
		now,
	)
	if err != nil {
		return 0, err
	}

	return result.LastInsertId()
}

func (s *Storage) UpdateClient(ctx context.Context, client *Client) error {
	addressesJSON, err := json.Marshal(client.Addresses)
	if err != nil {
		return err
	}

	_, err = s.db.ExecContext(
		ctx,
		`UPDATE clients SET
			display_name = ?,
			hostname = ?,
			addresses_json = ?,
			username = ?,
			password = ?,
			custom_sni = ?,
			has_ipv6 = ?,
			skip_verification = ?,
			certificate_pem = ?,
			upstream_protocol = ?,
			anti_dpi = ?,
			client_random_prefix = ?,
			updated_at = ?
		WHERE id = ?`,
		client.DisplayName,
		client.Hostname,
		string(addressesJSON),
		client.Username,
		client.Password,
		client.CustomSNI,
		boolToInt(client.HasIPv6),
		boolToInt(client.SkipVerification),
		client.CertificatePEM,
		client.UpstreamProtocol,
		boolToInt(client.AntiDPI),
		client.ClientRandomPrefix,
		time.Now().UTC().Format(time.RFC3339),
		client.ID,
	)
	return err
}

func (s *Storage) DeleteClient(ctx context.Context, id int64) error {
	_, err := s.db.ExecContext(ctx, `DELETE FROM clients WHERE id = ?`, id)
	return err
}

func (s *Storage) AppendAudit(actor, action, target, details string) error {
	_, err := s.db.Exec(
		`INSERT INTO audit_log (actor, action, target, details, created_at) VALUES (?, ?, ?, ?, ?)`,
		actor,
		action,
		target,
		details,
		time.Now().UTC().Format(time.RFC3339),
	)
	return err
}

func (s *Storage) ListCascades(ctx context.Context) ([]Cascade, error) {
	rows, err := s.db.QueryContext(
		ctx,
		`SELECT id, display_name, hostname, addresses_json, username, password, custom_sni,
		        skip_verification, certificate_pem, upstream_protocol, anti_dpi,
		        client_random_prefix, enabled, notes, created_at, updated_at
		 FROM cascades
		 ORDER BY updated_at DESC, id DESC`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var cascades []Cascade
	for rows.Next() {
		cascade, err := scanCascade(rows)
		if err != nil {
			return nil, err
		}
		cascades = append(cascades, cascade)
	}

	return cascades, rows.Err()
}

func (s *Storage) GetCascade(ctx context.Context, id int64) (*Cascade, error) {
	row := s.db.QueryRowContext(
		ctx,
		`SELECT id, display_name, hostname, addresses_json, username, password, custom_sni,
		        skip_verification, certificate_pem, upstream_protocol, anti_dpi,
		        client_random_prefix, enabled, notes, created_at, updated_at
		 FROM cascades
		 WHERE id = ?`,
		id,
	)

	cascade, err := scanCascade(row)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}

	return &cascade, nil
}

func (s *Storage) CreateCascade(ctx context.Context, cascade *Cascade) (int64, error) {
	addressesJSON, err := json.Marshal(cascade.Addresses)
	if err != nil {
		return 0, err
	}

	now := time.Now().UTC().Format(time.RFC3339)
	result, err := s.db.ExecContext(
		ctx,
		`INSERT INTO cascades (
			display_name, hostname, addresses_json, username, password, custom_sni,
			skip_verification, certificate_pem, upstream_protocol, anti_dpi,
			client_random_prefix, enabled, notes, created_at, updated_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		cascade.DisplayName,
		cascade.Hostname,
		string(addressesJSON),
		cascade.Username,
		cascade.Password,
		cascade.CustomSNI,
		boolToInt(cascade.SkipVerification),
		cascade.CertificatePEM,
		cascade.UpstreamProtocol,
		boolToInt(cascade.AntiDPI),
		cascade.ClientRandomPrefix,
		boolToInt(cascade.Enabled),
		cascade.Notes,
		now,
		now,
	)
	if err != nil {
		return 0, err
	}

	return result.LastInsertId()
}

func (s *Storage) UpdateCascade(ctx context.Context, cascade *Cascade) error {
	addressesJSON, err := json.Marshal(cascade.Addresses)
	if err != nil {
		return err
	}

	_, err = s.db.ExecContext(
		ctx,
		`UPDATE cascades SET
			display_name = ?,
			hostname = ?,
			addresses_json = ?,
			username = ?,
			password = ?,
			custom_sni = ?,
			skip_verification = ?,
			certificate_pem = ?,
			upstream_protocol = ?,
			anti_dpi = ?,
			client_random_prefix = ?,
			enabled = ?,
			notes = ?,
			updated_at = ?
		WHERE id = ?`,
		cascade.DisplayName,
		cascade.Hostname,
		string(addressesJSON),
		cascade.Username,
		cascade.Password,
		cascade.CustomSNI,
		boolToInt(cascade.SkipVerification),
		cascade.CertificatePEM,
		cascade.UpstreamProtocol,
		boolToInt(cascade.AntiDPI),
		cascade.ClientRandomPrefix,
		boolToInt(cascade.Enabled),
		cascade.Notes,
		time.Now().UTC().Format(time.RFC3339),
		cascade.ID,
	)
	return err
}

func (s *Storage) DeleteCascade(ctx context.Context, id int64) error {
	_, err := s.db.ExecContext(ctx, `DELETE FROM cascades WHERE id = ?`, id)
	return err
}

func (s *Storage) EnsureRoutingDataset(ctx context.Context, item RoutingDataset) error {
	_, err := s.db.ExecContext(
		ctx,
		`INSERT INTO routing_datasets (kind, display_name, source_url, local_path, last_error, updated_at, available)
		 VALUES (?, ?, ?, ?, '', '', 0)
		 ON CONFLICT(kind) DO UPDATE SET
		   display_name = excluded.display_name,
		   source_url = CASE WHEN routing_datasets.source_url = '' THEN excluded.source_url ELSE routing_datasets.source_url END,
		   local_path = excluded.local_path`,
		item.Kind,
		item.DisplayName,
		item.SourceURL,
		item.LocalPath,
	)
	return err
}

func (s *Storage) ListRoutingDatasets(ctx context.Context) ([]RoutingDataset, error) {
	rows, err := s.db.QueryContext(
		ctx,
		`SELECT kind, display_name, source_url, local_path, last_error, updated_at, available
		 FROM routing_datasets
		 ORDER BY kind ASC`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []RoutingDataset
	for rows.Next() {
		var (
			item         RoutingDataset
			updatedAtRaw string
			availableInt int
		)
		if err := rows.Scan(
			&item.Kind,
			&item.DisplayName,
			&item.SourceURL,
			&item.LocalPath,
			&item.LastError,
			&updatedAtRaw,
			&availableInt,
		); err != nil {
			return nil, err
		}
		item.Available = availableInt == 1
		if updatedAtRaw != "" {
			item.UpdatedAt, err = time.Parse(time.RFC3339, updatedAtRaw)
			if err != nil {
				return nil, err
			}
		}
		items = append(items, item)
	}

	return items, rows.Err()
}

func (s *Storage) GetRoutingDataset(ctx context.Context, kind string) (*RoutingDataset, error) {
	row := s.db.QueryRowContext(
		ctx,
		`SELECT kind, display_name, source_url, local_path, last_error, updated_at, available
		 FROM routing_datasets
		 WHERE kind = ?`,
		kind,
	)

	var (
		item         RoutingDataset
		updatedAtRaw string
		availableInt int
	)
	if err := row.Scan(
		&item.Kind,
		&item.DisplayName,
		&item.SourceURL,
		&item.LocalPath,
		&item.LastError,
		&updatedAtRaw,
		&availableInt,
	); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	item.Available = availableInt == 1
	if updatedAtRaw != "" {
		parsed, err := time.Parse(time.RFC3339, updatedAtRaw)
		if err != nil {
			return nil, err
		}
		item.UpdatedAt = parsed
	}
	return &item, nil
}

func (s *Storage) MarkRoutingDatasetResult(ctx context.Context, kind string, updatedAt time.Time, available bool, lastError string) error {
	_, err := s.db.ExecContext(
		ctx,
		`UPDATE routing_datasets
		 SET updated_at = ?, available = ?, last_error = ?
		 WHERE kind = ?`,
		updatedAt.UTC().Format(time.RFC3339),
		boolToInt(available),
		lastError,
		kind,
	)
	return err
}

func (s *Storage) ListZapretProfiles(ctx context.Context) ([]ZapretProfile, error) {
	rows, err := s.db.QueryContext(
		ctx,
		`SELECT id, display_name, strategy_name, script_path, args, enabled, notes, created_at, updated_at
		 FROM zapret_profiles
		 ORDER BY updated_at DESC, id DESC`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []ZapretProfile
	for rows.Next() {
		item, err := scanZapretProfile(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, item)
	}

	return items, rows.Err()
}

func (s *Storage) GetZapretProfile(ctx context.Context, id int64) (*ZapretProfile, error) {
	row := s.db.QueryRowContext(
		ctx,
		`SELECT id, display_name, strategy_name, script_path, args, enabled, notes, created_at, updated_at
		 FROM zapret_profiles
		 WHERE id = ?`,
		id,
	)

	item, err := scanZapretProfile(row)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &item, nil
}

func (s *Storage) CreateZapretProfile(ctx context.Context, item *ZapretProfile) (int64, error) {
	now := time.Now().UTC().Format(time.RFC3339)
	result, err := s.db.ExecContext(
		ctx,
		`INSERT INTO zapret_profiles (display_name, strategy_name, script_path, args, enabled, notes, created_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		item.DisplayName,
		item.StrategyName,
		item.ScriptPath,
		item.Args,
		boolToInt(item.Enabled),
		item.Notes,
		now,
		now,
	)
	if err != nil {
		return 0, err
	}

	return result.LastInsertId()
}

func (s *Storage) UpdateZapretProfile(ctx context.Context, item *ZapretProfile) error {
	_, err := s.db.ExecContext(
		ctx,
		`UPDATE zapret_profiles SET
			display_name = ?,
			strategy_name = ?,
			script_path = ?,
			args = ?,
			enabled = ?,
			notes = ?,
			updated_at = ?
		WHERE id = ?`,
		item.DisplayName,
		item.StrategyName,
		item.ScriptPath,
		item.Args,
		boolToInt(item.Enabled),
		item.Notes,
		time.Now().UTC().Format(time.RFC3339),
		item.ID,
	)
	return err
}

func (s *Storage) DeleteZapretProfile(ctx context.Context, id int64) error {
	_, err := s.db.ExecContext(ctx, `DELETE FROM zapret_profiles WHERE id = ?`, id)
	return err
}

func (s *Storage) ListRoutingRules(ctx context.Context) ([]RoutingRule, error) {
	rows, err := s.db.QueryContext(
		ctx,
		`SELECT id, display_name, match_type, match_value, action, cascade_id, zapret_profile_id,
		        enabled, priority, notes, created_at, updated_at
		 FROM routing_rules
		 ORDER BY priority ASC, updated_at DESC, id DESC`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []RoutingRule
	for rows.Next() {
		item, err := scanRoutingRule(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, item)
	}

	return items, rows.Err()
}

func (s *Storage) GetRoutingRule(ctx context.Context, id int64) (*RoutingRule, error) {
	row := s.db.QueryRowContext(
		ctx,
		`SELECT id, display_name, match_type, match_value, action, cascade_id, zapret_profile_id,
		        enabled, priority, notes, created_at, updated_at
		 FROM routing_rules
		 WHERE id = ?`,
		id,
	)

	item, err := scanRoutingRule(row)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &item, nil
}

func (s *Storage) CreateRoutingRule(ctx context.Context, item *RoutingRule) (int64, error) {
	now := time.Now().UTC().Format(time.RFC3339)
	result, err := s.db.ExecContext(
		ctx,
		`INSERT INTO routing_rules (
			display_name, match_type, match_value, action, cascade_id, zapret_profile_id,
			enabled, priority, notes, created_at, updated_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		item.DisplayName,
		item.MatchType,
		item.MatchValue,
		item.Action,
		item.CascadeID,
		item.ZapretProfileID,
		boolToInt(item.Enabled),
		item.Priority,
		item.Notes,
		now,
		now,
	)
	if err != nil {
		return 0, err
	}

	return result.LastInsertId()
}

func (s *Storage) UpdateRoutingRule(ctx context.Context, item *RoutingRule) error {
	_, err := s.db.ExecContext(
		ctx,
		`UPDATE routing_rules SET
			display_name = ?,
			match_type = ?,
			match_value = ?,
			action = ?,
			cascade_id = ?,
			zapret_profile_id = ?,
			enabled = ?,
			priority = ?,
			notes = ?,
			updated_at = ?
		WHERE id = ?`,
		item.DisplayName,
		item.MatchType,
		item.MatchValue,
		item.Action,
		item.CascadeID,
		item.ZapretProfileID,
		boolToInt(item.Enabled),
		item.Priority,
		item.Notes,
		time.Now().UTC().Format(time.RFC3339),
		item.ID,
	)
	return err
}

func (s *Storage) DeleteRoutingRule(ctx context.Context, id int64) error {
	_, err := s.db.ExecContext(ctx, `DELETE FROM routing_rules WHERE id = ?`, id)
	return err
}

func (s *Storage) ListAudit(ctx context.Context, limit int) ([]AuditEntry, error) {
	rows, err := s.db.QueryContext(
		ctx,
		`SELECT id, actor, action, target, details, created_at
		 FROM audit_log
		 ORDER BY created_at DESC, id DESC
		 LIMIT ?`,
		limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []AuditEntry
	for rows.Next() {
		var (
			item         AuditEntry
			createdAtRaw string
		)
		if err := rows.Scan(&item.ID, &item.Actor, &item.Action, &item.Target, &item.Details, &createdAtRaw); err != nil {
			return nil, err
		}
		item.CreatedAt, err = time.Parse(time.RFC3339, createdAtRaw)
		if err != nil {
			return nil, err
		}
		items = append(items, item)
	}

	return items, rows.Err()
}

type scanner interface {
	Scan(dest ...any) error
}

func scanClient(row scanner) (Client, error) {
	var (
		client        Client
		addressesJSON string
		hasIPv6Int    int
		skipVerifyInt int
		antiDPIInt    int
		createdAtRaw  string
		updatedAtRaw  string
	)

	err := row.Scan(
		&client.ID,
		&client.DisplayName,
		&client.Hostname,
		&addressesJSON,
		&client.Username,
		&client.Password,
		&client.CustomSNI,
		&hasIPv6Int,
		&skipVerifyInt,
		&client.CertificatePEM,
		&client.UpstreamProtocol,
		&antiDPIInt,
		&client.ClientRandomPrefix,
		&createdAtRaw,
		&updatedAtRaw,
	)
	if err != nil {
		return Client{}, err
	}

	if err := json.Unmarshal([]byte(addressesJSON), &client.Addresses); err != nil {
		return Client{}, err
	}

	client.HasIPv6 = hasIPv6Int == 1
	client.SkipVerification = skipVerifyInt == 1
	client.AntiDPI = antiDPIInt == 1

	client.CreatedAt, err = time.Parse(time.RFC3339, createdAtRaw)
	if err != nil {
		return Client{}, err
	}
	client.UpdatedAt, err = time.Parse(time.RFC3339, updatedAtRaw)
	if err != nil {
		return Client{}, err
	}

	return client, nil
}

func scanCascade(row scanner) (Cascade, error) {
	var (
		cascade       Cascade
		addressesJSON string
		skipVerifyInt int
		antiDPIInt    int
		enabledInt    int
		createdAtRaw  string
		updatedAtRaw  string
	)

	err := row.Scan(
		&cascade.ID,
		&cascade.DisplayName,
		&cascade.Hostname,
		&addressesJSON,
		&cascade.Username,
		&cascade.Password,
		&cascade.CustomSNI,
		&skipVerifyInt,
		&cascade.CertificatePEM,
		&cascade.UpstreamProtocol,
		&antiDPIInt,
		&cascade.ClientRandomPrefix,
		&enabledInt,
		&cascade.Notes,
		&createdAtRaw,
		&updatedAtRaw,
	)
	if err != nil {
		return Cascade{}, err
	}

	if err := json.Unmarshal([]byte(addressesJSON), &cascade.Addresses); err != nil {
		return Cascade{}, err
	}

	cascade.SkipVerification = skipVerifyInt == 1
	cascade.AntiDPI = antiDPIInt == 1
	cascade.Enabled = enabledInt == 1

	cascade.CreatedAt, err = time.Parse(time.RFC3339, createdAtRaw)
	if err != nil {
		return Cascade{}, err
	}
	cascade.UpdatedAt, err = time.Parse(time.RFC3339, updatedAtRaw)
	if err != nil {
		return Cascade{}, err
	}

	return cascade, nil
}

func scanZapretProfile(row scanner) (ZapretProfile, error) {
	var (
		item         ZapretProfile
		enabledInt   int
		createdAtRaw string
		updatedAtRaw string
	)

	err := row.Scan(
		&item.ID,
		&item.DisplayName,
		&item.StrategyName,
		&item.ScriptPath,
		&item.Args,
		&enabledInt,
		&item.Notes,
		&createdAtRaw,
		&updatedAtRaw,
	)
	if err != nil {
		return ZapretProfile{}, err
	}

	item.Enabled = enabledInt == 1
	item.CreatedAt, err = time.Parse(time.RFC3339, createdAtRaw)
	if err != nil {
		return ZapretProfile{}, err
	}
	item.UpdatedAt, err = time.Parse(time.RFC3339, updatedAtRaw)
	if err != nil {
		return ZapretProfile{}, err
	}
	return item, nil
}

func scanRoutingRule(row scanner) (RoutingRule, error) {
	var (
		item         RoutingRule
		enabledInt   int
		createdAtRaw string
		updatedAtRaw string
	)

	err := row.Scan(
		&item.ID,
		&item.DisplayName,
		&item.MatchType,
		&item.MatchValue,
		&item.Action,
		&item.CascadeID,
		&item.ZapretProfileID,
		&enabledInt,
		&item.Priority,
		&item.Notes,
		&createdAtRaw,
		&updatedAtRaw,
	)
	if err != nil {
		return RoutingRule{}, err
	}

	item.Enabled = enabledInt == 1
	item.CreatedAt, err = time.Parse(time.RFC3339, createdAtRaw)
	if err != nil {
		return RoutingRule{}, err
	}
	item.UpdatedAt, err = time.Parse(time.RFC3339, updatedAtRaw)
	if err != nil {
		return RoutingRule{}, err
	}
	return item, nil
}

func generatePassword() (string, error) {
	raw := make([]byte, 18)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(raw), nil
}

func boolToInt(value bool) int {
	if value {
		return 1
	}
	return 0
}
