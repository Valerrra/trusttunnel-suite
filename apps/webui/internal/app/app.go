package app

import (
	"os"
	"path/filepath"
	"strconv"
	"time"
)

type Config struct {
	AppName                     string
	Addr                        string
	DBPath                      string
	AdminUsername               string
	AdminPassword               string
	SecureCookie                bool
	SessionTTL                  time.Duration
	EndpointLiveMode            bool
	EndpointBinary              string
	EndpointVPNConfigPath       string
	EndpointHostsConfigPath     string
	EndpointCredentialsFilePath string
	EndpointPublicAddress       string
	EndpointPort                int
	ClientStatsFilePath         string
	MetricsDiskPath             string
	RoutingDataDir              string
	GeoIPSourceURL              string
	GeoSiteSourceURL            string
	ZapretPresetDir             string
}

func LoadConfig() Config {
	wd, err := os.Getwd()
	if err != nil {
		wd = "."
	}

	endpointDir := env("TT_WEBUI_ENDPOINT_DIR", "/opt/trusttunnel")

	return Config{
		AppName:                     "TrustTunnel WebUI",
		Addr:                        env("TT_WEBUI_ADDR", "127.0.0.1:8088"),
		DBPath:                      env("TT_WEBUI_DB_PATH", filepath.Join(wd, "data", "webui.db")),
		AdminUsername:               env("TT_WEBUI_ADMIN_USERNAME", "admin"),
		AdminPassword:               os.Getenv("TT_WEBUI_ADMIN_PASSWORD"),
		SecureCookie:                envBool("TT_WEBUI_SECURE_COOKIE", false),
		SessionTTL:                  24 * time.Hour,
		EndpointLiveMode:            envBool("TT_WEBUI_ENDPOINT_LIVE_MODE", false),
		EndpointBinary:              env("TT_WEBUI_ENDPOINT_BIN", filepath.Join(endpointDir, "trusttunnel_endpoint")),
		EndpointVPNConfigPath:       env("TT_WEBUI_ENDPOINT_VPN_CONFIG", filepath.Join(endpointDir, "vpn.toml")),
		EndpointHostsConfigPath:     env("TT_WEBUI_ENDPOINT_HOSTS_CONFIG", filepath.Join(endpointDir, "hosts.toml")),
		EndpointCredentialsFilePath: env("TT_WEBUI_ENDPOINT_CREDENTIALS_FILE", filepath.Join(endpointDir, "credentials.toml")),
		EndpointPublicAddress:       env("TT_WEBUI_ENDPOINT_PUBLIC_ADDRESS", ""),
		EndpointPort:                envInt("TT_WEBUI_ENDPOINT_PORT", 443),
		ClientStatsFilePath:         env("TT_WEBUI_CLIENT_STATS_FILE", filepath.Join(endpointDir, "webui-client-stats.json")),
		MetricsDiskPath:             env("TT_WEBUI_METRICS_DISK_PATH", endpointDir),
		RoutingDataDir:              env("TT_WEBUI_ROUTING_DATA_DIR", filepath.Join(wd, "data", "routing")),
		GeoIPSourceURL:              env("TT_WEBUI_GEOIP_SOURCE_URL", "https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geoip.dat"),
		GeoSiteSourceURL:            env("TT_WEBUI_GEOSITE_SOURCE_URL", "https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geosite.dat"),
		ZapretPresetDir:             env("TT_WEBUI_ZAPRET_PRESET_DIR", ""),
	}
}

func env(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func envBool(key string, fallback bool) bool {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}

	parsed, err := strconv.ParseBool(value)
	if err != nil {
		return fallback
	}
	return parsed
}

func envInt(key string, fallback int) int {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}

	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}
	return parsed
}
