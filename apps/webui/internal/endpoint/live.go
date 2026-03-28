package endpoint

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"trusttunnel-suite/apps/webui/internal/app"
	"trusttunnel-suite/apps/webui/internal/storage"
)

type Live struct {
	cfg app.Config
}

type HostMetrics struct {
	Available            bool
	CPUPercent           float64
	MemoryUsedBytes      uint64
	MemoryTotalBytes     uint64
	SwapUsedBytes        uint64
	SwapTotalBytes       uint64
	DiskUsedBytes        uint64
	DiskTotalBytes       uint64
	TrafficRXBytes       uint64
	TrafficTXBytes       uint64
	LiveConnections      int
	LiveUDPAssociations  int
	LoadAverage          string
	StatsUpdatedAt       time.Time
	ClientStatsAvailable bool
}

type ClientStats struct {
	Username          string    `json:"username"`
	RXBytes           uint64    `json:"rx_bytes"`
	TXBytes           uint64    `json:"tx_bytes"`
	ActiveConnections int       `json:"active_connections"`
	UpdatedAt         time.Time `json:"updated_at"`
}

type CascadeRuntimeStatus struct {
	Available     bool
	Applied       bool
	CascadeID     int64     `json:"cascade_id"`
	DisplayName   string    `json:"display_name"`
	Hostname      string    `json:"hostname"`
	SocksAddress  string    `json:"socks_address"`
	ServiceName   string    `json:"service_name"`
	UpdatedAt     time.Time `json:"updated_at"`
	EndpointMode  string    `json:"endpoint_mode"`
	ClientBinPath string    `json:"client_bin_path"`
}

type Socks5RuntimeStatus struct {
	Available   bool      `json:"available"`
	Enabled     bool      `json:"enabled"`
	ListenHost  string    `json:"listen_host"`
	Port        int       `json:"port"`
	Username    string    `json:"username"`
	Password    string    `json:"password"`
	ShareURL    string    `json:"share_url"`
	ServiceName string    `json:"service_name"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type MTProtoRuntimeStatus struct {
	Available      bool      `json:"available"`
	Enabled        bool      `json:"enabled"`
	ListenHost     string    `json:"listen_host"`
	Port           int       `json:"port"`
	Secret         string    `json:"secret"`
	SecretHex      string    `json:"secret_hex"`
	FrontingDomain string    `json:"fronting_domain"`
	ServiceName    string    `json:"service_name"`
	TGURL          string    `json:"tg_url"`
	TMeURL         string    `json:"tme_url"`
	UpdatedAt      time.Time `json:"updated_at"`
}

type clientStatsSnapshot struct {
	GeneratedAt time.Time     `json:"generated_at"`
	Clients     []ClientStats `json:"clients"`
}

type mtgAccessPayload struct {
	IPv4 struct {
		TGURL  string `json:"tg_url"`
		TMeURL string `json:"tme_url"`
	} `json:"ipv4"`
	Secret struct {
		Hex    string `json:"hex"`
		Base64 string `json:"base64"`
	} `json:"secret"`
}

func NewLive(cfg app.Config) *Live {
	if !cfg.EndpointLiveMode {
		return nil
	}
	return &Live{cfg: cfg}
}

func (l *Live) SyncCredentials(ctx context.Context, clients []storage.Client) error {
	if l == nil {
		return nil
	}

	var b strings.Builder
	for _, client := range clients {
		if strings.TrimSpace(client.Username) == "" {
			continue
		}
		b.WriteString("[[client]]\n")
		b.WriteString(fmt.Sprintf("username = %q\n", client.Username))
		b.WriteString(fmt.Sprintf("password = %q\n\n", client.Password))
	}

	if err := os.MkdirAll(filepath.Dir(l.cfg.EndpointCredentialsFilePath), 0o755); err != nil {
		return fmt.Errorf("create credentials dir: %w", err)
	}
	if err := os.WriteFile(l.cfg.EndpointCredentialsFilePath, []byte(b.String()), 0o600); err != nil {
		return fmt.Errorf("write credentials file: %w", err)
	}

	return nil
}

func (l *Live) ExportDeepLink(ctx context.Context, client storage.Client) (string, error) {
	if l == nil {
		return "", fmt.Errorf("live endpoint mode is disabled")
	}
	if strings.TrimSpace(l.cfg.EndpointPublicAddress) == "" {
		return "", fmt.Errorf("TT_WEBUI_ENDPOINT_PUBLIC_ADDRESS is required in live mode")
	}

	cmd := exec.CommandContext(
		ctx,
		l.cfg.EndpointBinary,
		l.cfg.EndpointVPNConfigPath,
		l.cfg.EndpointHostsConfigPath,
		"-c", client.Username,
		"-a", l.cfg.EndpointPublicAddress,
		"--format", "deeplink",
	)

	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("trusttunnel export failed: %w: %s", err, strings.TrimSpace(stderr.String()))
	}

	return strings.TrimSpace(string(out)), nil
}

func (l *Live) CollectHostMetrics(ctx context.Context) (HostMetrics, error) {
	if l == nil {
		return HostMetrics{}, nil
	}

	metrics := HostMetrics{
		Available:      true,
		StatsUpdatedAt: time.Now().UTC(),
	}

	cpuPercent, err := sampleCPUPercent()
	if err != nil {
		return HostMetrics{}, err
	}
	metrics.CPUPercent = cpuPercent

	memUsed, memTotal, swapUsed, swapTotal, err := readMemoryUsage()
	if err != nil {
		return HostMetrics{}, err
	}
	metrics.MemoryUsedBytes = memUsed
	metrics.MemoryTotalBytes = memTotal
	metrics.SwapUsedBytes = swapUsed
	metrics.SwapTotalBytes = swapTotal

	diskUsed, diskTotal, err := readDiskUsage(l.cfg.MetricsDiskPath)
	if err != nil {
		return HostMetrics{}, err
	}
	metrics.DiskUsedBytes = diskUsed
	metrics.DiskTotalBytes = diskTotal

	rxBytes, txBytes, err := readNetworkBytes()
	if err != nil {
		return HostMetrics{}, err
	}
	metrics.TrafficRXBytes = rxBytes
	metrics.TrafficTXBytes = txBytes

	loadAverage, err := readLoadAverage()
	if err == nil {
		metrics.LoadAverage = loadAverage
	}

	clientStats, err := l.ReadClientStats(ctx)
	if err == nil && len(clientStats) > 0 {
		metrics.ClientStatsAvailable = true
		for _, item := range clientStats {
			metrics.LiveConnections += item.ActiveConnections
		}
	} else {
		connCount, connErr := countTCPConnections(ctx, l.cfg.EndpointPort)
		if connErr == nil {
			metrics.LiveConnections = connCount
		}
	}

	udpCount, udpErr := countUDPAssociations(ctx, l.cfg.EndpointPort)
	if udpErr == nil {
		metrics.LiveUDPAssociations = udpCount
	}

	return metrics, nil
}

func (l *Live) ApplyClientStats(ctx context.Context, clients []storage.Client) []storage.Client {
	if l == nil || len(clients) == 0 {
		return clients
	}

	items, err := l.ReadClientStats(ctx)
	if err != nil || len(items) == 0 {
		return clients
	}

	index := make(map[string]ClientStats, len(items))
	for _, item := range items {
		index[item.Username] = item
	}

	for i := range clients {
		stats, ok := index[clients[i].Username]
		if !ok {
			continue
		}
		clients[i].TrafficRXBytes = stats.RXBytes
		clients[i].TrafficTXBytes = stats.TXBytes
		clients[i].ActiveConnections = stats.ActiveConnections
		clients[i].StatsUpdatedAt = stats.UpdatedAt
		clients[i].StatsAvailable = true
	}

	return clients
}

func (l *Live) ReadClientStats(ctx context.Context) ([]ClientStats, error) {
	if l == nil || strings.TrimSpace(l.cfg.ClientStatsFilePath) == "" {
		return nil, nil
	}

	raw, err := os.ReadFile(l.cfg.ClientStatsFilePath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}

	var snapshot clientStatsSnapshot
	if err := json.Unmarshal(raw, &snapshot); err != nil {
		return nil, err
	}

	return snapshot.Clients, nil
}

func (l *Live) ReadCascadeRuntimeStatus(ctx context.Context) (CascadeRuntimeStatus, error) {
	if l == nil {
		return CascadeRuntimeStatus{}, nil
	}

	status := CascadeRuntimeStatus{
		Available:     true,
		ServiceName:   "trusttunnel-cascade",
		SocksAddress:  l.cfg.CascadeSocksAddress,
		ClientBinPath: l.cfg.EndpointClientBinary,
	}

	raw, err := os.ReadFile(l.cfg.CascadeStateFile)
	if err != nil {
		if os.IsNotExist(err) {
			return status, nil
		}
		return status, err
	}

	if err := json.Unmarshal(raw, &status); err != nil {
		return status, err
	}
	status.Available = true
	return status, nil
}

func (l *Live) ReadSocks5RuntimeStatus(ctx context.Context) (Socks5RuntimeStatus, error) {
	if l == nil {
		return Socks5RuntimeStatus{}, nil
	}

	status := Socks5RuntimeStatus{
		Available:   true,
		ListenHost:  "0.0.0.0",
		ServiceName: "trusttunnel-socks5",
	}

	raw, err := os.ReadFile(l.cfg.Socks5StateFile)
	if err != nil {
		if os.IsNotExist(err) {
			return status, nil
		}
		return status, err
	}

	if err := json.Unmarshal(raw, &status); err != nil {
		return status, err
	}
	if status.ShareURL == "" {
		status.ShareURL = buildTelegramSocksURL(l.cfg.EndpointPublicAddress, status.Port, status.Username, status.Password)
	}
	status.Available = true
	return status, nil
}

func (l *Live) ReadMTProtoRuntimeStatus(ctx context.Context) (MTProtoRuntimeStatus, error) {
	if l == nil {
		return MTProtoRuntimeStatus{}, nil
	}

	status := MTProtoRuntimeStatus{
		Available:   true,
		ListenHost:  "0.0.0.0",
		ServiceName: "trusttunnel-mtproto",
	}

	raw, err := os.ReadFile(l.cfg.MTProtoStateFile)
	if err != nil {
		if os.IsNotExist(err) {
			return status, nil
		}
		return status, err
	}

	if err := json.Unmarshal(raw, &status); err != nil {
		return status, err
	}
	status.Available = true
	return status, nil
}

func (l *Live) ApplyCascade(ctx context.Context, cascade storage.Cascade) error {
	if l == nil {
		return fmt.Errorf("live endpoint mode is disabled")
	}
	if strings.TrimSpace(l.cfg.EndpointClientBinary) == "" {
		return fmt.Errorf("TT_WEBUI_ENDPOINT_CLIENT_BIN is not configured")
	}

	if err := os.MkdirAll(l.cfg.CascadeWorkDir, 0o755); err != nil {
		return fmt.Errorf("create cascade work dir: %w", err)
	}

	if err := l.ensureClientBinary(); err != nil {
		return err
	}

	clientConfigPath := filepath.Join(l.cfg.CascadeWorkDir, "client.toml")
	clientConfig, err := l.renderCascadeClientConfig(cascade)
	if err != nil {
		return err
	}
	if err := os.WriteFile(clientConfigPath, []byte(clientConfig), 0o600); err != nil {
		return fmt.Errorf("write cascade client config: %w", err)
	}

	servicePath := "/etc/systemd/system/trusttunnel-cascade.service"
	serviceBody := l.renderCascadeService(clientConfigPath)
	if err := os.WriteFile(servicePath, []byte(serviceBody), 0o644); err != nil {
		return fmt.Errorf("write cascade systemd unit: %w", err)
	}

	if err := l.replaceForwardProtocolSection(fmt.Sprintf("[forward_protocol.socks5]\naddress = %q\nextended_auth = false\n", l.cfg.CascadeSocksAddress)); err != nil {
		return err
	}

	if err := l.runSystemctl(ctx, "daemon-reload"); err != nil {
		return err
	}
	if err := l.runSystemctl(ctx, "enable", "trusttunnel-cascade"); err != nil {
		return err
	}
	if err := l.runSystemctl(ctx, "restart", "trusttunnel-cascade"); err != nil {
		return err
	}
	if err := l.runSystemctl(ctx, "restart", "trusttunnel"); err != nil {
		return err
	}

	status := CascadeRuntimeStatus{
		Available:     true,
		Applied:       true,
		CascadeID:     cascade.ID,
		DisplayName:   cascade.DisplayName,
		Hostname:      cascade.Hostname,
		SocksAddress:  l.cfg.CascadeSocksAddress,
		ServiceName:   "trusttunnel-cascade",
		UpdatedAt:     time.Now().UTC(),
		EndpointMode:  "socks5",
		ClientBinPath: l.cfg.EndpointClientBinary,
	}
	raw, _ := json.MarshalIndent(status, "", "  ")
	_ = os.WriteFile(l.cfg.CascadeStateFile, raw, 0o600)

	return nil
}

func (l *Live) DisableCascade(ctx context.Context) error {
	if l == nil {
		return fmt.Errorf("live endpoint mode is disabled")
	}

	if err := l.replaceForwardProtocolSection("[forward_protocol]\ndirect = {}\n"); err != nil {
		return err
	}

	if err := l.runSystemctl(ctx, "restart", "trusttunnel"); err != nil {
		return err
	}
	_ = l.runSystemctl(ctx, "stop", "trusttunnel-cascade")
	_ = os.Remove(l.cfg.CascadeStateFile)

	return nil
}

func (l *Live) ApplySocks5(ctx context.Context, port int, username, password string) error {
	if l == nil {
		return fmt.Errorf("live endpoint mode is disabled")
	}
	if port < 1 || port > 65535 {
		return fmt.Errorf("invalid SOCKS5 port")
	}
	if err := os.MkdirAll(l.cfg.AccessWorkDir, 0o755); err != nil {
		return fmt.Errorf("create access work dir: %w", err)
	}
	if err := l.ensureBinary(l.cfg.Socks5Binary, "microsocks"); err != nil {
		return err
	}

	existing, _ := l.ReadSocks5RuntimeStatus(ctx)
	username = strings.TrimSpace(username)
	password = strings.TrimSpace(password)
	if username == "" {
		username = existing.Username
	}
	if password == "" {
		password = existing.Password
	}
	if strings.TrimSpace(username) == "" {
		username = "tt" + randomAlphaNum(10)
	}
	if strings.TrimSpace(password) == "" {
		password = randomAlphaNum(20)
	}

	servicePath := "/etc/systemd/system/trusttunnel-socks5.service"
	serviceBody := fmt.Sprintf(`[Unit]
Description=TrustTunnel WebUI SOCKS5 Access
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=%s -i 0.0.0.0 -p %d -u %s -P %s
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
`, l.cfg.Socks5Binary, port, username, password)

	if err := os.WriteFile(servicePath, []byte(serviceBody), 0o644); err != nil {
		return fmt.Errorf("write socks5 systemd unit: %w", err)
	}
	if err := l.runSystemctl(ctx, "daemon-reload"); err != nil {
		return err
	}
	if err := l.runSystemctl(ctx, "enable", "trusttunnel-socks5"); err != nil {
		return err
	}
	if err := l.runSystemctl(ctx, "restart", "trusttunnel-socks5"); err != nil {
		return err
	}

	status := Socks5RuntimeStatus{
		Available:   true,
		Enabled:     true,
		ListenHost:  "0.0.0.0",
		Port:        port,
		Username:    username,
		Password:    password,
		ShareURL:    buildTelegramSocksURL(l.cfg.EndpointPublicAddress, port, username, password),
		ServiceName: "trusttunnel-socks5",
		UpdatedAt:   time.Now().UTC(),
	}
	raw, _ := json.MarshalIndent(status, "", "  ")
	_ = os.WriteFile(l.cfg.Socks5StateFile, raw, 0o600)
	return nil
}

func (l *Live) DisableSocks5(ctx context.Context) error {
	if l == nil {
		return fmt.Errorf("live endpoint mode is disabled")
	}
	_ = l.runSystemctl(ctx, "stop", "trusttunnel-socks5")
	_ = l.runSystemctl(ctx, "disable", "trusttunnel-socks5")
	_ = os.Remove(l.cfg.Socks5StateFile)
	return nil
}

func (l *Live) ApplyMTProto(ctx context.Context, port int, frontingDomain string) error {
	if l == nil {
		return fmt.Errorf("live endpoint mode is disabled")
	}
	if port < 1 || port > 65535 {
		return fmt.Errorf("invalid MTProto port")
	}
	frontingDomain = strings.TrimSpace(frontingDomain)
	if frontingDomain == "" {
		return fmt.Errorf("fronting domain is required")
	}
	if err := os.MkdirAll(l.cfg.AccessWorkDir, 0o755); err != nil {
		return fmt.Errorf("create access work dir: %w", err)
	}
	if err := l.ensureBinary(l.cfg.MTProtoBinary, "mtg"); err != nil {
		return err
	}

	existing, _ := l.ReadMTProtoRuntimeStatus(ctx)
	secret := existing.Secret
	if strings.TrimSpace(secret) == "" || !strings.EqualFold(existing.FrontingDomain, frontingDomain) {
		generated, err := l.generateMTProtoSecret(ctx, frontingDomain)
		if err != nil {
			return err
		}
		secret = generated
	}

	configPath := filepath.Join(l.cfg.AccessWorkDir, "mtproto.toml")
	configBody := fmt.Sprintf("secret = %q\nbind-to = %q\n\n[network]\ndns = %q\n", secret, fmt.Sprintf("0.0.0.0:%d", port), "https://1.1.1.1")
	if err := os.WriteFile(configPath, []byte(configBody), 0o600); err != nil {
		return fmt.Errorf("write mtproto config: %w", err)
	}

	servicePath := "/etc/systemd/system/trusttunnel-mtproto.service"
	serviceBody := fmt.Sprintf(`[Unit]
Description=TrustTunnel WebUI MTProto Access
Documentation=https://github.com/9seconds/mtg
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=%s run %s
Restart=always
RestartSec=3
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
`, l.cfg.MTProtoBinary, configPath)
	if err := os.WriteFile(servicePath, []byte(serviceBody), 0o644); err != nil {
		return fmt.Errorf("write mtproto systemd unit: %w", err)
	}

	if err := l.runSystemctl(ctx, "daemon-reload"); err != nil {
		return err
	}
	if err := l.runSystemctl(ctx, "enable", "trusttunnel-mtproto"); err != nil {
		return err
	}
	if err := l.runSystemctl(ctx, "restart", "trusttunnel-mtproto"); err != nil {
		return err
	}

	status := MTProtoRuntimeStatus{
		Available:      true,
		Enabled:        true,
		ListenHost:     "0.0.0.0",
		Port:           port,
		Secret:         secret,
		FrontingDomain: frontingDomain,
		ServiceName:    "trusttunnel-mtproto",
		UpdatedAt:      time.Now().UTC(),
	}
	if access, err := l.readMTProtoAccess(ctx, configPath); err == nil {
		if access.Secret.Base64 != "" {
			status.Secret = access.Secret.Base64
		}
		status.SecretHex = access.Secret.Hex
		status.TGURL = access.IPv4.TGURL
		status.TMeURL = access.IPv4.TMeURL
	}

	raw, _ := json.MarshalIndent(status, "", "  ")
	_ = os.WriteFile(l.cfg.MTProtoStateFile, raw, 0o600)
	return nil
}

func (l *Live) DisableMTProto(ctx context.Context) error {
	if l == nil {
		return fmt.Errorf("live endpoint mode is disabled")
	}
	_ = l.runSystemctl(ctx, "stop", "trusttunnel-mtproto")
	_ = l.runSystemctl(ctx, "disable", "trusttunnel-mtproto")
	_ = os.Remove(l.cfg.MTProtoStateFile)
	return nil
}

func (l *Live) ensureClientBinary() error {
	return l.ensureBinary(l.cfg.EndpointClientBinary, "trusttunnel_client")
}

func (l *Live) ensureBinary(path, label string) error {
	info, err := os.Stat(path)
	if err != nil {
		return fmt.Errorf("%s not found at %s", label, path)
	}
	if info.IsDir() {
		return fmt.Errorf("%s path points to a directory: %s", label, path)
	}
	return nil
}

func (l *Live) generateMTProtoSecret(ctx context.Context, frontingDomain string) (string, error) {
	cmd := exec.CommandContext(ctx, l.cfg.MTProtoBinary, "generate-secret", frontingDomain)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("mtg generate-secret failed: %w: %s", err, strings.TrimSpace(stderr.String()))
	}
	return strings.TrimSpace(string(out)), nil
}

func (l *Live) readMTProtoAccess(ctx context.Context, configPath string) (mtgAccessPayload, error) {
	cmd := exec.CommandContext(ctx, l.cfg.MTProtoBinary, "access", configPath)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		return mtgAccessPayload{}, fmt.Errorf("mtg access failed: %w: %s", err, strings.TrimSpace(stderr.String()))
	}
	var payload mtgAccessPayload
	if err := json.Unmarshal(out, &payload); err != nil {
		return mtgAccessPayload{}, err
	}
	return payload, nil
}

func randomAlphaNum(length int) string {
	const alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	if length <= 0 {
		return ""
	}

	buf := make([]byte, length)
	if _, err := rand.Read(buf); err != nil {
		return strconv.FormatInt(time.Now().UnixNano(), 36)
	}

	for i := range buf {
		buf[i] = alphabet[int(buf[i])%len(alphabet)]
	}
	return string(buf)
}

func (l *Live) renderCascadeClientConfig(cascade storage.Cascade) (string, error) {
	address := ""
	if len(cascade.Addresses) > 0 {
		address = cascade.Addresses[0]
	}
	if strings.TrimSpace(address) == "" {
		return "", fmt.Errorf("cascade address list is empty")
	}

	certificateValue := `""`
	if strings.TrimSpace(cascade.CertificatePEM) != "" {
		certificateValue = "\"\"\"\n" + strings.TrimSpace(cascade.CertificatePEM) + "\n\"\"\""
	}

	return fmt.Sprintf(`loglevel = "info"
vpn_mode = "general"
killswitch_enabled = false
killswitch_allow_ports = []
post_quantum_group_enabled = false
exclusions = []
dns_upstreams = []

[endpoint]
hostname = %q
addresses = [%q]
has_ipv6 = false
username = %q
password = %q
client_random = %q
skip_verification = %t
certificate = %s
upstream_protocol = %q
upstream_fallback_protocol = ""
anti_dpi = %t
custom_sni = %q

[listener]

[listener.socks]
address = %q
username = ""
password = ""
`, cascade.Hostname, address, cascade.Username, cascade.Password, cascade.ClientRandomPrefix, cascade.SkipVerification, certificateValue, cascade.UpstreamProtocol, cascade.AntiDPI, cascade.CustomSNI, l.cfg.CascadeSocksAddress), nil
}

func (l *Live) renderCascadeService(clientConfigPath string) string {
	return fmt.Sprintf(`[Unit]
Description=TrustTunnel Cascade Bridge
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=%s -c %s
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
`, l.cfg.EndpointClientBinary, clientConfigPath)
}

func (l *Live) replaceForwardProtocolSection(replacement string) error {
	raw, err := os.ReadFile(l.cfg.EndpointVPNConfigPath)
	if err != nil {
		return fmt.Errorf("read endpoint vpn config: %w", err)
	}

	text := string(raw)
	start := strings.Index(text, "[forward_protocol")
	if start >= 0 {
		sectionStart := strings.LastIndex(text[:start], "\n")
		if sectionStart >= 0 {
			start = sectionStart + 1
		}
		end := len(text)
		if next := strings.Index(text[start+1:], "\n["); next >= 0 {
			end = start + 1 + next
		}
		text = text[:start] + strings.TrimRight(replacement, "\n") + "\n" + strings.TrimLeft(text[end:], "\n")
	} else {
		text = strings.TrimRight(text, "\n") + "\n\n" + strings.TrimRight(replacement, "\n") + "\n"
	}

	if err := os.WriteFile(l.cfg.EndpointVPNConfigPath, []byte(text), 0o644); err != nil {
		return fmt.Errorf("write endpoint vpn config: %w", err)
	}
	return nil
}

func (l *Live) runSystemctl(ctx context.Context, args ...string) error {
	cmd := exec.CommandContext(ctx, "systemctl", args...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("systemctl %s failed: %w: %s", strings.Join(args, " "), err, strings.TrimSpace(stderr.String()))
	}
	return nil
}

type cpuSample struct {
	idle  uint64
	total uint64
}

func sampleCPUPercent() (float64, error) {
	first, err := readCPUSample()
	if err != nil {
		return 0, err
	}
	time.Sleep(120 * time.Millisecond)
	second, err := readCPUSample()
	if err != nil {
		return 0, err
	}

	totalDelta := second.total - first.total
	idleDelta := second.idle - first.idle
	if totalDelta == 0 {
		return 0, nil
	}

	used := float64(totalDelta-idleDelta) / float64(totalDelta) * 100
	if used < 0 {
		return 0, nil
	}
	return used, nil
}

func readCPUSample() (cpuSample, error) {
	raw, err := os.ReadFile("/proc/stat")
	if err != nil {
		return cpuSample{}, err
	}

	line := strings.SplitN(string(raw), "\n", 2)[0]
	fields := strings.Fields(line)
	if len(fields) < 8 || fields[0] != "cpu" {
		return cpuSample{}, fmt.Errorf("unexpected /proc/stat format")
	}

	var values []uint64
	for _, field := range fields[1:] {
		value, err := strconv.ParseUint(field, 10, 64)
		if err != nil {
			return cpuSample{}, err
		}
		values = append(values, value)
	}

	var total uint64
	for _, value := range values {
		total += value
	}

	idle := values[3]
	if len(values) > 4 {
		idle += values[4]
	}

	return cpuSample{idle: idle, total: total}, nil
}

func readMemoryUsage() (used uint64, total uint64, swapUsed uint64, swapTotal uint64, err error) {
	raw, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return 0, 0, 0, 0, err
	}

	var memTotal, memAvailable, swapTotalKB, swapFreeKB uint64
	for _, line := range strings.Split(string(raw), "\n") {
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		switch fields[0] {
		case "MemTotal:":
			memTotal, _ = strconv.ParseUint(fields[1], 10, 64)
		case "MemAvailable:":
			memAvailable, _ = strconv.ParseUint(fields[1], 10, 64)
		case "SwapTotal:":
			swapTotalKB, _ = strconv.ParseUint(fields[1], 10, 64)
		case "SwapFree:":
			swapFreeKB, _ = strconv.ParseUint(fields[1], 10, 64)
		}
	}

	total = memTotal * 1024
	used = (memTotal - memAvailable) * 1024
	swapTotal = swapTotalKB * 1024
	swapUsed = (swapTotalKB - swapFreeKB) * 1024
	return used, total, swapUsed, swapTotal, nil
}

func readDiskUsage(path string) (used uint64, total uint64, err error) {
	target := path
	if strings.TrimSpace(target) == "" {
		target = "/"
	}

	var stat syscall.Statfs_t
	if err := syscall.Statfs(target, &stat); err != nil {
		return 0, 0, err
	}

	total = stat.Blocks * uint64(stat.Bsize)
	free := stat.Bavail * uint64(stat.Bsize)
	used = total - free
	return used, total, nil
}

func readNetworkBytes() (rx uint64, tx uint64, err error) {
	raw, err := os.ReadFile("/proc/net/dev")
	if err != nil {
		return 0, 0, err
	}

	lines := strings.Split(string(raw), "\n")
	for _, line := range lines[2:] {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		parts := strings.SplitN(line, ":", 2)
		if len(parts) != 2 {
			continue
		}

		iface := strings.TrimSpace(parts[0])
		if iface == "lo" {
			continue
		}

		fields := strings.Fields(parts[1])
		if len(fields) < 16 {
			continue
		}

		rxValue, _ := strconv.ParseUint(fields[0], 10, 64)
		txValue, _ := strconv.ParseUint(fields[8], 10, 64)
		rx += rxValue
		tx += txValue
	}

	return rx, tx, nil
}

func readLoadAverage() (string, error) {
	raw, err := os.ReadFile("/proc/loadavg")
	if err != nil {
		return "", err
	}
	fields := strings.Fields(string(raw))
	if len(fields) < 3 {
		return "", fmt.Errorf("unexpected /proc/loadavg format")
	}
	return strings.Join(fields[:3], " | "), nil
}

func countTCPConnections(ctx context.Context, port int) (int, error) {
	if port <= 0 {
		return 0, nil
	}

	out, err := exec.CommandContext(ctx, "ss", "-Htan", "state", "established").Output()
	if err != nil {
		return 0, err
	}

	var count int
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		fields := strings.Fields(line)
		if len(fields) < 4 {
			continue
		}
		if hasPort(fields[3], port) {
			count++
		}
	}

	return count, nil
}

func countUDPAssociations(ctx context.Context, port int) (int, error) {
	if port <= 0 {
		return 0, nil
	}

	out, err := exec.CommandContext(ctx, "ss", "-Huan").Output()
	if err != nil {
		return 0, err
	}

	var count int
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		fields := strings.Fields(line)
		if len(fields) < 5 {
			continue
		}
		if hasPort(fields[4], port) {
			count++
		}
	}

	return count, nil
}

func buildTelegramSocksURL(server string, port int, username, password string) string {
	server = strings.TrimSpace(server)
	if server == "" || port <= 0 || username == "" || password == "" {
		return ""
	}
	return fmt.Sprintf(
		"https://t.me/socks?server=%s&port=%s&user=%s&pass=%s",
		url.QueryEscape(server),
		url.QueryEscape(strconv.Itoa(port)),
		url.QueryEscape(username),
		url.QueryEscape(password),
	)
}

func hasPort(value string, port int) bool {
	suffix := ":" + strconv.Itoa(port)
	return strings.HasSuffix(value, suffix) || strings.Contains(value, "]"+suffix)
}
