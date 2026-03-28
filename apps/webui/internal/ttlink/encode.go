package ttlink

import (
	"encoding/base64"
	"encoding/pem"
	"fmt"
	"strings"

	"trusttunnel-suite/apps/webui/internal/storage"
)

const (
	tagHostname           = 0x01
	tagAddress            = 0x02
	tagCustomSNI          = 0x03
	tagHasIPv6            = 0x04
	tagUsername           = 0x05
	tagPassword           = 0x06
	tagSkipVerification   = 0x07
	tagCertificate        = 0x08
	tagUpstreamProtocol   = 0x09
	tagAntiDPI            = 0x0A
	tagClientRandomPrefix = 0x0B
)

var protocolMap = map[string]byte{
	"http2": 0x01,
	"http3": 0x02,
}

func EncodeClient(client storage.Client) (string, error) {
	payload, err := EncodePayload(client)
	if err != nil {
		return "", err
	}
	return "tt://?" + base64.RawURLEncoding.EncodeToString(payload), nil
}

func EncodePayload(client storage.Client) ([]byte, error) {
	if strings.TrimSpace(client.Hostname) == "" {
		return nil, fmt.Errorf("hostname is required")
	}
	if len(client.Addresses) == 0 {
		return nil, fmt.Errorf("at least one address is required")
	}
	if strings.TrimSpace(client.Username) == "" {
		return nil, fmt.Errorf("username is required")
	}
	if client.Password == "" {
		return nil, fmt.Errorf("password is required")
	}

	var buf []byte

	buf = append(buf, tlv(tagHostname, []byte(client.Hostname))...)
	buf = append(buf, tlv(tagUsername, []byte(client.Username))...)
	buf = append(buf, tlv(tagPassword, []byte(client.Password))...)

	for _, address := range client.Addresses {
		address = strings.TrimSpace(address)
		if address == "" {
			continue
		}
		buf = append(buf, tlv(tagAddress, []byte(address))...)
	}

	if client.ClientRandomPrefix != "" {
		buf = append(buf, tlv(tagClientRandomPrefix, []byte(client.ClientRandomPrefix))...)
	}
	if client.CustomSNI != "" {
		buf = append(buf, tlv(tagCustomSNI, []byte(client.CustomSNI))...)
	}
	if !client.HasIPv6 {
		buf = append(buf, tlv(tagHasIPv6, []byte{0x00})...)
	}
	if client.SkipVerification {
		buf = append(buf, tlv(tagSkipVerification, []byte{0x01})...)
	}
	if client.AntiDPI {
		buf = append(buf, tlv(tagAntiDPI, []byte{0x01})...)
	}

	protocol := client.UpstreamProtocol
	if protocol == "" {
		protocol = "http2"
	}
	if protocol != "http2" {
		value, ok := protocolMap[protocol]
		if !ok {
			return nil, fmt.Errorf("unknown upstream protocol: %s", protocol)
		}
		buf = append(buf, tlv(tagUpstreamProtocol, []byte{value})...)
	}

	if strings.TrimSpace(client.CertificatePEM) != "" {
		certBytes, err := pemToDER(client.CertificatePEM)
		if err != nil {
			return nil, err
		}
		buf = append(buf, tlv(tagCertificate, certBytes)...)
	}

	return buf, nil
}

func tlv(tag int, value []byte) []byte {
	out := append(encodeVarint(uint64(tag)), encodeVarint(uint64(len(value)))...)
	out = append(out, value...)
	return out
}

func encodeVarint(value uint64) []byte {
	switch {
	case value <= 0x3F:
		return []byte{byte(value)}
	case value <= 0x3FFF:
		value |= 0x4000
		return []byte{byte(value >> 8), byte(value)}
	case value <= 0x3FFFFFFF:
		value |= 0x80000000
		return []byte{
			byte(value >> 24),
			byte(value >> 16),
			byte(value >> 8),
			byte(value),
		}
	default:
		value |= 0xC000000000000000
		return []byte{
			byte(value >> 56),
			byte(value >> 48),
			byte(value >> 40),
			byte(value >> 32),
			byte(value >> 24),
			byte(value >> 16),
			byte(value >> 8),
			byte(value),
		}
	}
}

func pemToDER(pemText string) ([]byte, error) {
	data := []byte(strings.TrimSpace(pemText))
	if len(data) == 0 {
		return nil, nil
	}

	var out []byte
	found := false
	for len(data) > 0 {
		block, rest := pem.Decode(data)
		if block == nil {
			break
		}
		if strings.Contains(block.Type, "CERTIFICATE") {
			out = append(out, block.Bytes...)
			found = true
		}
		data = rest
	}

	if !found {
		return nil, fmt.Errorf("certificate field does not contain valid PEM certificate blocks")
	}

	return out, nil
}
