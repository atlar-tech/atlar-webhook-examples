package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

var (
	defaultMaxAge = time.Duration(300) * time.Second
)

func main() {
	http.HandleFunc("/", webhook)
	port := os.Getenv("PORT")
	if err := http.ListenAndServe(net.JoinHostPort("", port), nil); err != nil {
		log.Fatal(err)
	}
}

func webhook(w http.ResponseWriter, req *http.Request) {
	signature := req.Header.Get("webhook-signature")
	timestamp := req.Header.Get("webhook-request-timestamp")
	if signature == "" || timestamp == "" {
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	maxAge := defaultMaxAge
	maxAgeSeconds, err := strconv.ParseInt(os.Getenv("MAX_REQUEST_AGE_SECONDS"), 10, 64)
	if err == nil {
		maxAge = time.Duration(maxAgeSeconds) * time.Second
	}

	body, err := io.ReadAll(req.Body)
	defer req.Body.Close()
	if err != nil {
		log.Println(err)
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	if ok, err := signatureIsValid(
		req.Header.Get("webhook-signature"),
		req.Header.Get("webhook-request-timestamp"),
		body,
		os.Getenv("WEBHOOK_B64KEY"),
		maxAge,
	); !ok || err != nil {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}
	w.WriteHeader(http.StatusOK)
}

func signatureIsValid(sigHeader, tsHeader string, payload []byte, base64Key string, maxAge time.Duration) (bool, error) {
	t, err := time.Parse(time.RFC3339Nano, tsHeader)
	if err != nil {
		return false, err
	}
	if time.Since(t) > maxAge {
		return false, nil
	}
	key, err := base64.StdEncoding.DecodeString(base64Key)
	if err != nil {
		return false, fmt.Errorf("failed to decode key, %w", err)
	}
	mac := hmac.New(sha256.New, key)
	_, err = mac.Write(append(payload, []byte("."+tsHeader)...))
	if err != nil {
		return false, fmt.Errorf("failed to hash payload, %w", err)
	}
	calculatedSignature := mac.Sum(nil)

	for _, hexSignature := range strings.Split(sigHeader, ",") {
		sig, err := hex.DecodeString(hexSignature)
		if err == nil && hmac.Equal(calculatedSignature, sig) {
			return true, nil
		}
	}
	return false, nil
}
