package ttlink

import (
	"strings"
	"testing"

	"trusttunnel-suite/apps/webui/internal/storage"
)

func TestEncodeClientMatchesOfficialHelper(t *testing.T) {
	client := storage.Client{
		DisplayName:        "FI Test",
		Hostname:           "vpn.example.com",
		Addresses:          []string{"198.51.100.10:8443"},
		Username:           "premium-user",
		Password:           "secret-pass",
		CustomSNI:          "edge.example.com",
		HasIPv6:            true,
		UpstreamProtocol:   "http3",
		AntiDPI:            true,
		ClientRandomPrefix: "abcd1234/ffff0000",
	}

	got, err := EncodeClient(client)
	if err != nil {
		t.Fatalf("EncodeClient() error = %v", err)
	}

	want := "tt://?AQ92cG4uZXhhbXBsZS5jb20FDHByZW1pdW0tdXNlcgYLc2VjcmV0LXBhc3MCEjE5OC41MS4xMDAuMTA6ODQ0MwsRYWJjZDEyMzQvZmZmZjAwMDADEGVkZ2UuZXhhbXBsZS5jb20KAQEJAQI"
	if got != want {
		t.Fatalf("EncodeClient() mismatch\nwant: %s\ngot:  %s", want, got)
	}
}

func TestEncodeClientRequiresFields(t *testing.T) {
	_, err := EncodeClient(storage.Client{})
	if err == nil {
		t.Fatal("EncodeClient() expected error, got nil")
	}
	if !strings.Contains(err.Error(), "hostname") {
		t.Fatalf("EncodeClient() error = %v, want hostname validation", err)
	}
}
