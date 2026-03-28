package main

import (
	"context"
	"log"
	"net/http"
	"os/signal"
	"syscall"
	"time"

	"trusttunnel-suite/apps/webui/internal/app"
	"trusttunnel-suite/apps/webui/internal/storage"
	"trusttunnel-suite/apps/webui/internal/web"
)

func main() {
	cfg := app.LoadConfig()

	store, err := storage.Open(cfg.DBPath)
	if err != nil {
		log.Fatalf("open storage: %v", err)
	}
	defer store.Close()

	created, password, err := store.EnsureBootstrapAdmin(cfg.AdminUsername, cfg.AdminPassword)
	if err != nil {
		log.Fatalf("bootstrap admin: %v", err)
	}
	if created {
		log.Printf("bootstrap admin created: username=%s password=%s", cfg.AdminUsername, password)
	}

	server := &http.Server{
		Addr:              cfg.Addr,
		Handler:           web.NewServer(cfg, store).Routes(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("TrustTunnel WebUI listening on http://%s", cfg.Addr)

	go func() {
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	<-ctx.Done()

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Printf("shutdown error: %v", err)
	}
}
