package web

import (
	"context"
	"crypto/rand"
	"embed"
	"encoding/base64"
	"errors"
	"fmt"
	"html/template"
	"io"
	"io/fs"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/skip2/go-qrcode"

	"trusttunnel-suite/apps/webui/internal/app"
	"trusttunnel-suite/apps/webui/internal/endpoint"
	"trusttunnel-suite/apps/webui/internal/storage"
	"trusttunnel-suite/apps/webui/internal/ttlink"
)

//go:embed templates/*.html static/*
var assets embed.FS

const sessionCookieName = "tt_webui_session"

type Server struct {
	cfg      app.Config
	store    *storage.Storage
	endpoint *endpoint.Live
}

type ctxKey string

const userCtxKey ctxKey = "user"

type templateData struct {
	Title           string
	Active          string
	AppName         string
	CurrentUser     *storage.User
	Error           string
	Notice          string
	Stats           storage.DashboardStats
	Clients         []storage.Client
	Cascades        []storage.Cascade
	RoutingRules    []storage.RoutingRule
	ZapretProfiles  []storage.ZapretProfile
	RoutingDatasets []storage.RoutingDataset
	Audit           []storage.AuditEntry
	ServerAddr      string
	DBPath          string
	Form            clientFormData
	CascadeForm     cascadeFormData
	RuleForm        routingRuleFormData
	ZapretForm      zapretFormData
	DeepLink        string
	QRDataURI       string
	Client          *storage.Client
	HostMetrics     endpoint.HostMetrics
	CascadeRuntime  endpoint.CascadeRuntimeStatus
	Socks5Runtime   endpoint.Socks5RuntimeStatus
	MTProtoRuntime  endpoint.MTProtoRuntimeStatus
	ClientStatsPath string
	EndpointAddr    string
}

type clientFormData struct {
	ID                 int64
	DisplayName        string
	Hostname           string
	Addresses          string
	Username           string
	Password           string
	CustomSNI          string
	HasIPv6            bool
	SkipVerification   bool
	CertificatePEM     string
	UpstreamProtocol   string
	AntiDPI            bool
	ClientRandomPrefix string
	SubmitLabel        string
	CancelURL          string
}

type cascadeFormData struct {
	ID                 int64
	DisplayName        string
	Hostname           string
	Addresses          string
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
	SubmitLabel        string
	CancelURL          string
}

type routingRuleFormData struct {
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
	SubmitLabel     string
	CancelURL       string
}

type zapretFormData struct {
	ID           int64
	DisplayName  string
	StrategyName string
	ScriptPath   string
	Args         string
	Enabled      bool
	Notes        string
	SubmitLabel  string
	CancelURL    string
}

func NewServer(cfg app.Config, store *storage.Storage) *Server {
	srv := &Server{
		cfg:      cfg,
		store:    store,
		endpoint: endpoint.NewLive(cfg),
	}
	srv.ensureRoutingDatasets()
	return srv
}

func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()

	staticFS, err := fs.Sub(assets, "static")
	if err != nil {
		panic(err)
	}
	mux.Handle("GET /static/", http.StripPrefix("/static/", http.FileServer(http.FS(staticFS))))

	mux.HandleFunc("GET /login", s.handleLoginPage)
	mux.HandleFunc("POST /login", s.handleLogin)
	mux.Handle("POST /logout", s.authRequired(http.HandlerFunc(s.handleLogout)))

	mux.Handle("GET /", s.authRequired(http.HandlerFunc(s.handleRoot)))
	mux.Handle("GET /dashboard", s.authRequired(http.HandlerFunc(s.handleDashboard)))
	mux.Handle("GET /clients", s.authRequired(http.HandlerFunc(s.handleClients)))
	mux.Handle("GET /routing", s.authRequired(http.HandlerFunc(s.handleRouting)))
	mux.Handle("GET /routing/rules/new", s.authRequired(http.HandlerFunc(s.handleRoutingRuleNewPage)))
	mux.Handle("POST /routing/rules", s.authRequired(http.HandlerFunc(s.handleRoutingRuleCreate)))
	mux.Handle("GET /routing/rules/{id}/edit", s.authRequired(http.HandlerFunc(s.handleRoutingRuleEditPage)))
	mux.Handle("POST /routing/rules/{id}", s.authRequired(http.HandlerFunc(s.handleRoutingRuleUpdate)))
	mux.Handle("POST /routing/rules/{id}/delete", s.authRequired(http.HandlerFunc(s.handleRoutingRuleDelete)))
	mux.Handle("GET /routing/zapret/new", s.authRequired(http.HandlerFunc(s.handleZapretNewPage)))
	mux.Handle("POST /routing/zapret", s.authRequired(http.HandlerFunc(s.handleZapretCreate)))
	mux.Handle("GET /routing/zapret/{id}/edit", s.authRequired(http.HandlerFunc(s.handleZapretEditPage)))
	mux.Handle("POST /routing/zapret/{id}", s.authRequired(http.HandlerFunc(s.handleZapretUpdate)))
	mux.Handle("POST /routing/zapret/{id}/delete", s.authRequired(http.HandlerFunc(s.handleZapretDelete)))
	mux.Handle("POST /routing/datasets/{kind}/refresh", s.authRequired(http.HandlerFunc(s.handleRoutingDatasetRefresh)))
	mux.Handle("GET /cascades", s.authRequired(http.HandlerFunc(s.handleCascades)))
	mux.Handle("GET /cascades/new", s.authRequired(http.HandlerFunc(s.handleCascadeNewPage)))
	mux.Handle("POST /cascades", s.authRequired(http.HandlerFunc(s.handleCascadeCreate)))
	mux.Handle("GET /cascades/{id}/edit", s.authRequired(http.HandlerFunc(s.handleCascadeEditPage)))
	mux.Handle("POST /cascades/{id}", s.authRequired(http.HandlerFunc(s.handleCascadeUpdate)))
	mux.Handle("POST /cascades/{id}/apply", s.authRequired(http.HandlerFunc(s.handleCascadeApply)))
	mux.Handle("POST /cascades/disable", s.authRequired(http.HandlerFunc(s.handleCascadeDisable)))
	mux.Handle("POST /cascades/access/socks5/apply", s.authRequired(http.HandlerFunc(s.handleSocks5Apply)))
	mux.Handle("POST /cascades/access/socks5/disable", s.authRequired(http.HandlerFunc(s.handleSocks5Disable)))
	mux.Handle("POST /cascades/access/mtproto/apply", s.authRequired(http.HandlerFunc(s.handleMTProtoApply)))
	mux.Handle("POST /cascades/access/mtproto/disable", s.authRequired(http.HandlerFunc(s.handleMTProtoDisable)))
	mux.Handle("POST /cascades/{id}/delete", s.authRequired(http.HandlerFunc(s.handleCascadeDelete)))
	mux.Handle("GET /clients/new", s.authRequired(http.HandlerFunc(s.handleClientNewPage)))
	mux.Handle("POST /clients", s.authRequired(http.HandlerFunc(s.handleClientCreate)))
	mux.Handle("GET /clients/{id}/edit", s.authRequired(http.HandlerFunc(s.handleClientEditPage)))
	mux.Handle("POST /clients/{id}", s.authRequired(http.HandlerFunc(s.handleClientUpdate)))
	mux.Handle("POST /clients/{id}/delete", s.authRequired(http.HandlerFunc(s.handleClientDelete)))
	mux.Handle("GET /clients/{id}", s.authRequired(http.HandlerFunc(s.handleClientExportPage)))
	mux.Handle("GET /clients/{id}/tt", s.authRequired(http.HandlerFunc(s.handleClientDeepLink)))
	mux.Handle("GET /clients/{id}/qr.png", s.authRequired(http.HandlerFunc(s.handleClientQRPNG)))

	return s.logRequests(mux)
}

func (s *Server) handleRoot(w http.ResponseWriter, r *http.Request) {
	http.Redirect(w, r, "/clients", http.StatusSeeOther)
}

func (s *Server) handleLoginPage(w http.ResponseWriter, r *http.Request) {
	if user, _ := s.currentUser(r); user != nil {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}

	s.render(w, "login.html", templateData{
		Title:   "Вход",
		AppName: s.cfg.AppName,
		Error:   r.URL.Query().Get("error"),
	})
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		http.Redirect(w, r, "/login?error=Не удалось прочитать форму", http.StatusSeeOther)
		return
	}

	username := strings.TrimSpace(r.FormValue("username"))
	password := r.FormValue("password")

	user, err := s.store.AuthenticateUser(r.Context(), username, password)
	if err != nil {
		s.serverError(w, err)
		return
	}
	if user == nil {
		http.Redirect(w, r, "/login?error=Неверный логин или пароль", http.StatusSeeOther)
		return
	}

	token, err := s.store.CreateSession(r.Context(), user.ID, s.cfg.SessionTTL)
	if err != nil {
		s.serverError(w, err)
		return
	}

	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookieName,
		Value:    token,
		Path:     "/",
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		Secure:   s.cfg.SecureCookie,
		Expires:  time.Now().Add(s.cfg.SessionTTL),
	})

	_ = s.store.AppendAudit(user.Username, "login", "session", "user logged in")
	http.Redirect(w, r, "/", http.StatusSeeOther)
}

func (s *Server) handleLogout(w http.ResponseWriter, r *http.Request) {
	user, _ := s.currentUser(r)
	if cookie, err := r.Cookie(sessionCookieName); err == nil {
		_ = s.store.DeleteSession(r.Context(), cookie.Value)
	}

	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookieName,
		Value:    "",
		Path:     "/",
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		Secure:   s.cfg.SecureCookie,
		Expires:  time.Unix(0, 0),
		MaxAge:   -1,
	})

	if user != nil {
		_ = s.store.AppendAudit(user.Username, "logout", "session", "user logged out")
	}
	http.Redirect(w, r, "/login", http.StatusSeeOther)
}

func (s *Server) handleDashboard(w http.ResponseWriter, r *http.Request) {
	stats, err := s.store.DashboardStats(r.Context())
	if err != nil {
		s.serverError(w, err)
		return
	}

	audit, err := s.store.ListAudit(r.Context(), 10)
	if err != nil {
		s.serverError(w, err)
		return
	}

	hostMetrics, err := s.endpoint.CollectHostMetrics(r.Context())
	if err != nil {
		log.Printf("collect host metrics: %v", err)
	}

	user, _ := s.currentUser(r)
	s.render(w, "dashboard.html", templateData{
		Title:           "Dashboard",
		Active:          "dashboard",
		AppName:         s.cfg.AppName,
		CurrentUser:     user,
		Stats:           stats,
		Audit:           audit,
		ServerAddr:      s.cfg.Addr,
		DBPath:          s.cfg.DBPath,
		HostMetrics:     hostMetrics,
		ClientStatsPath: s.cfg.ClientStatsFilePath,
		EndpointAddr:    s.endpointAddressLabel(),
	})
}

func (s *Server) handleClients(w http.ResponseWriter, r *http.Request) {
	clients, err := s.store.ListClients(r.Context())
	if err != nil {
		s.serverError(w, err)
		return
	}
	clients = s.endpoint.ApplyClientStats(r.Context(), clients)
	clientStatsAvailable := false
	for _, client := range clients {
		if client.StatsAvailable {
			clientStatsAvailable = true
			break
		}
	}

	user, _ := s.currentUser(r)
	s.render(w, "clients.html", templateData{
		Title:           "Клиенты",
		Active:          "clients",
		AppName:         s.cfg.AppName,
		CurrentUser:     user,
		Clients:         clients,
		Notice:          r.URL.Query().Get("notice"),
		HostMetrics:     endpoint.HostMetrics{ClientStatsAvailable: clientStatsAvailable},
		ClientStatsPath: s.cfg.ClientStatsFilePath,
		EndpointAddr:    s.endpointAddressLabel(),
	})
}

func (s *Server) handleRouting(w http.ResponseWriter, r *http.Request) {
	rules, err := s.store.ListRoutingRules(r.Context())
	if err != nil {
		s.serverError(w, err)
		return
	}
	zapretProfiles, err := s.store.ListZapretProfiles(r.Context())
	if err != nil {
		s.serverError(w, err)
		return
	}
	datasets, err := s.store.ListRoutingDatasets(r.Context())
	if err != nil {
		s.serverError(w, err)
		return
	}
	cascades, err := s.store.ListCascades(r.Context())
	if err != nil {
		s.serverError(w, err)
		return
	}

	user, _ := s.currentUser(r)
	s.render(w, "routing.html", templateData{
		Title:           "Routing",
		Active:          "routing",
		AppName:         s.cfg.AppName,
		CurrentUser:     user,
		RoutingRules:    rules,
		ZapretProfiles:  zapretProfiles,
		RoutingDatasets: datasets,
		Cascades:        cascades,
		Notice:          r.URL.Query().Get("notice"),
		Error:           r.URL.Query().Get("error"),
	})
}

func (s *Server) handleRoutingRuleNewPage(w http.ResponseWriter, r *http.Request) {
	user, _ := s.currentUser(r)
	cascades, _ := s.store.ListCascades(r.Context())
	zapretProfiles, _ := s.store.ListZapretProfiles(r.Context())
	s.render(w, "routing_rule_form.html", templateData{
		Title:          "Новое split-правило",
		Active:         "routing",
		AppName:        s.cfg.AppName,
		CurrentUser:    user,
		Cascades:       cascades,
		ZapretProfiles: zapretProfiles,
		RuleForm: routingRuleFormData{
			MatchType:   "domain",
			Action:      "direct",
			Enabled:     true,
			Priority:    100,
			SubmitLabel: "Создать правило",
			CancelURL:   "/routing",
		},
	})
}

func (s *Server) handleRoutingRuleCreate(w http.ResponseWriter, r *http.Request) {
	form, rule, err := parseRoutingRuleForm(r)
	if err != nil {
		user, _ := s.currentUser(r)
		cascades, _ := s.store.ListCascades(r.Context())
		zapretProfiles, _ := s.store.ListZapretProfiles(r.Context())
		form.SubmitLabel = "Создать правило"
		form.CancelURL = "/routing"
		s.render(w, "routing_rule_form.html", templateData{
			Title:          "Новое split-правило",
			Active:         "routing",
			AppName:        s.cfg.AppName,
			CurrentUser:    user,
			Error:          err.Error(),
			Cascades:       cascades,
			ZapretProfiles: zapretProfiles,
			RuleForm:       form,
		})
		return
	}

	id, err := s.store.CreateRoutingRule(r.Context(), rule)
	if err != nil {
		s.serverError(w, err)
		return
	}
	user, _ := s.currentUser(r)
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "routing-rule-create", rule.DisplayName, fmt.Sprintf("rule_id=%d", id))
	}
	http.Redirect(w, r, "/routing?notice=Split-правило создано", http.StatusSeeOther)
}

func (s *Server) handleRoutingRuleEditPage(w http.ResponseWriter, r *http.Request) {
	rule, ok := s.mustRoutingRule(w, r)
	if !ok {
		return
	}
	user, _ := s.currentUser(r)
	cascades, _ := s.store.ListCascades(r.Context())
	zapretProfiles, _ := s.store.ListZapretProfiles(r.Context())
	s.render(w, "routing_rule_form.html", templateData{
		Title:          "Редактирование split-правила",
		Active:         "routing",
		AppName:        s.cfg.AppName,
		CurrentUser:    user,
		Cascades:       cascades,
		ZapretProfiles: zapretProfiles,
		RuleForm:       formFromRoutingRule(*rule, "Сохранить изменения"),
	})
}

func (s *Server) handleRoutingRuleUpdate(w http.ResponseWriter, r *http.Request) {
	existing, ok := s.mustRoutingRule(w, r)
	if !ok {
		return
	}
	form, rule, err := parseRoutingRuleForm(r)
	if err != nil {
		user, _ := s.currentUser(r)
		cascades, _ := s.store.ListCascades(r.Context())
		zapretProfiles, _ := s.store.ListZapretProfiles(r.Context())
		form.ID = existing.ID
		form.SubmitLabel = "Сохранить изменения"
		form.CancelURL = "/routing"
		s.render(w, "routing_rule_form.html", templateData{
			Title:          "Редактирование split-правила",
			Active:         "routing",
			AppName:        s.cfg.AppName,
			CurrentUser:    user,
			Error:          err.Error(),
			Cascades:       cascades,
			ZapretProfiles: zapretProfiles,
			RuleForm:       form,
		})
		return
	}

	rule.ID = existing.ID
	if err := s.store.UpdateRoutingRule(r.Context(), rule); err != nil {
		s.serverError(w, err)
		return
	}
	user, _ := s.currentUser(r)
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "routing-rule-update", rule.DisplayName, fmt.Sprintf("rule_id=%d", rule.ID))
	}
	http.Redirect(w, r, "/routing?notice=Split-правило обновлено", http.StatusSeeOther)
}

func (s *Server) handleRoutingRuleDelete(w http.ResponseWriter, r *http.Request) {
	rule, ok := s.mustRoutingRule(w, r)
	if !ok {
		return
	}
	if err := s.store.DeleteRoutingRule(r.Context(), rule.ID); err != nil {
		s.serverError(w, err)
		return
	}
	user, _ := s.currentUser(r)
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "routing-rule-delete", rule.DisplayName, fmt.Sprintf("rule_id=%d", rule.ID))
	}
	http.Redirect(w, r, "/routing?notice=Split-правило удалено", http.StatusSeeOther)
}

func (s *Server) handleZapretNewPage(w http.ResponseWriter, r *http.Request) {
	user, _ := s.currentUser(r)
	s.render(w, "zapret_form.html", templateData{
		Title:       "Новый Zapret profile",
		Active:      "routing",
		AppName:     s.cfg.AppName,
		CurrentUser: user,
		ZapretForm: zapretFormData{
			Enabled:     true,
			SubmitLabel: "Создать профиль",
			CancelURL:   "/routing",
		},
	})
}

func (s *Server) handleZapretCreate(w http.ResponseWriter, r *http.Request) {
	form, item, err := parseZapretForm(r)
	if err != nil {
		user, _ := s.currentUser(r)
		form.SubmitLabel = "Создать профиль"
		form.CancelURL = "/routing"
		s.render(w, "zapret_form.html", templateData{
			Title:       "Новый Zapret profile",
			Active:      "routing",
			AppName:     s.cfg.AppName,
			CurrentUser: user,
			Error:       err.Error(),
			ZapretForm:  form,
		})
		return
	}

	id, err := s.store.CreateZapretProfile(r.Context(), item)
	if err != nil {
		s.serverError(w, err)
		return
	}
	user, _ := s.currentUser(r)
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "zapret-profile-create", item.DisplayName, fmt.Sprintf("profile_id=%d", id))
	}
	http.Redirect(w, r, "/routing?notice=Zapret profile создан", http.StatusSeeOther)
}

func (s *Server) handleZapretEditPage(w http.ResponseWriter, r *http.Request) {
	item, ok := s.mustZapretProfile(w, r)
	if !ok {
		return
	}
	user, _ := s.currentUser(r)
	s.render(w, "zapret_form.html", templateData{
		Title:       "Редактирование Zapret profile",
		Active:      "routing",
		AppName:     s.cfg.AppName,
		CurrentUser: user,
		ZapretForm:  formFromZapretProfile(*item, "Сохранить изменения"),
	})
}

func (s *Server) handleZapretUpdate(w http.ResponseWriter, r *http.Request) {
	existing, ok := s.mustZapretProfile(w, r)
	if !ok {
		return
	}
	form, item, err := parseZapretForm(r)
	if err != nil {
		user, _ := s.currentUser(r)
		form.ID = existing.ID
		form.SubmitLabel = "Сохранить изменения"
		form.CancelURL = "/routing"
		s.render(w, "zapret_form.html", templateData{
			Title:       "Редактирование Zapret profile",
			Active:      "routing",
			AppName:     s.cfg.AppName,
			CurrentUser: user,
			Error:       err.Error(),
			ZapretForm:  form,
		})
		return
	}
	item.ID = existing.ID
	if err := s.store.UpdateZapretProfile(r.Context(), item); err != nil {
		s.serverError(w, err)
		return
	}
	user, _ := s.currentUser(r)
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "zapret-profile-update", item.DisplayName, fmt.Sprintf("profile_id=%d", item.ID))
	}
	http.Redirect(w, r, "/routing?notice=Zapret profile обновлён", http.StatusSeeOther)
}

func (s *Server) handleZapretDelete(w http.ResponseWriter, r *http.Request) {
	item, ok := s.mustZapretProfile(w, r)
	if !ok {
		return
	}
	if err := s.store.DeleteZapretProfile(r.Context(), item.ID); err != nil {
		s.serverError(w, err)
		return
	}
	user, _ := s.currentUser(r)
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "zapret-profile-delete", item.DisplayName, fmt.Sprintf("profile_id=%d", item.ID))
	}
	http.Redirect(w, r, "/routing?notice=Zapret profile удалён", http.StatusSeeOther)
}

func (s *Server) handleRoutingDatasetRefresh(w http.ResponseWriter, r *http.Request) {
	kind := strings.TrimSpace(r.PathValue("kind"))
	if kind == "" {
		http.NotFound(w, r)
		return
	}
	user, _ := s.currentUser(r)
	if err := s.refreshRoutingDataset(r.Context(), kind, user); err != nil {
		http.Redirect(w, r, "/routing?error="+urlQueryEscape(err.Error()), http.StatusSeeOther)
		return
	}
	http.Redirect(w, r, "/routing?notice=Датасет обновлён: "+urlQueryEscape(kind), http.StatusSeeOther)
}

func (s *Server) handleCascades(w http.ResponseWriter, r *http.Request) {
	cascades, err := s.store.ListCascades(r.Context())
	if err != nil {
		s.serverError(w, err)
		return
	}
	runtimeStatus, _ := s.endpoint.ReadCascadeRuntimeStatus(r.Context())
	socks5Status, _ := s.endpoint.ReadSocks5RuntimeStatus(r.Context())
	mtprotoStatus, _ := s.endpoint.ReadMTProtoRuntimeStatus(r.Context())

	user, _ := s.currentUser(r)
	s.render(w, "cascades.html", templateData{
		Title:          "Каскады",
		Active:         "cascades",
		AppName:        s.cfg.AppName,
		CurrentUser:    user,
		Cascades:       cascades,
		CascadeRuntime: runtimeStatus,
		Socks5Runtime:  socks5Status,
		MTProtoRuntime: mtprotoStatus,
		Notice:         r.URL.Query().Get("notice"),
		Error:          r.URL.Query().Get("error"),
	})
}

func (s *Server) handleCascadeNewPage(w http.ResponseWriter, r *http.Request) {
	user, _ := s.currentUser(r)
	s.render(w, "cascade_form.html", templateData{
		Title:       "Новый каскад",
		Active:      "cascades",
		AppName:     s.cfg.AppName,
		CurrentUser: user,
		CascadeForm: cascadeFormData{
			Enabled:          true,
			UpstreamProtocol: "http2",
			SubmitLabel:      "Создать каскад",
			CancelURL:        "/cascades",
		},
	})
}

func (s *Server) handleCascadeCreate(w http.ResponseWriter, r *http.Request) {
	form, cascade, err := parseCascadeForm(r)
	if err != nil {
		user, _ := s.currentUser(r)
		s.render(w, "cascade_form.html", templateData{
			Title:       "Новый каскад",
			Active:      "cascades",
			AppName:     s.cfg.AppName,
			CurrentUser: user,
			Error:       err.Error(),
			CascadeForm: func() cascadeFormData {
				form.SubmitLabel = "Создать каскад"
				form.CancelURL = "/cascades"
				return form
			}(),
		})
		return
	}

	id, err := s.store.CreateCascade(r.Context(), cascade)
	if err != nil {
		s.serverError(w, err)
		return
	}

	user, _ := s.currentUser(r)
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "cascade-create", cascade.DisplayName, fmt.Sprintf("cascade_id=%d", id))
	}

	http.Redirect(w, r, "/cascades?notice=Каскад создан", http.StatusSeeOther)
}

func (s *Server) handleCascadeEditPage(w http.ResponseWriter, r *http.Request) {
	cascade, ok := s.mustCascade(w, r)
	if !ok {
		return
	}

	user, _ := s.currentUser(r)
	s.render(w, "cascade_form.html", templateData{
		Title:       "Редактирование каскада",
		Active:      "cascades",
		AppName:     s.cfg.AppName,
		CurrentUser: user,
		CascadeForm: formFromCascade(*cascade, "Сохранить изменения"),
	})
}

func (s *Server) handleCascadeUpdate(w http.ResponseWriter, r *http.Request) {
	existing, ok := s.mustCascade(w, r)
	if !ok {
		return
	}

	form, cascade, err := parseCascadeForm(r)
	if err != nil {
		user, _ := s.currentUser(r)
		form.ID = existing.ID
		form.SubmitLabel = "Сохранить изменения"
		form.CancelURL = "/cascades"
		s.render(w, "cascade_form.html", templateData{
			Title:       "Редактирование каскада",
			Active:      "cascades",
			AppName:     s.cfg.AppName,
			CurrentUser: user,
			Error:       err.Error(),
			CascadeForm: form,
		})
		return
	}

	cascade.ID = existing.ID
	if err := s.store.UpdateCascade(r.Context(), cascade); err != nil {
		s.serverError(w, err)
		return
	}

	user, _ := s.currentUser(r)
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "cascade-update", cascade.DisplayName, fmt.Sprintf("cascade_id=%d", cascade.ID))
	}

	http.Redirect(w, r, "/cascades?notice=Каскад обновлён", http.StatusSeeOther)
}

func (s *Server) handleCascadeDelete(w http.ResponseWriter, r *http.Request) {
	cascade, ok := s.mustCascade(w, r)
	if !ok {
		return
	}

	if err := s.store.DeleteCascade(r.Context(), cascade.ID); err != nil {
		s.serverError(w, err)
		return
	}

	user, _ := s.currentUser(r)
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "cascade-delete", cascade.DisplayName, fmt.Sprintf("cascade_id=%d", cascade.ID))
	}

	http.Redirect(w, r, "/cascades?notice=Каскад удалён", http.StatusSeeOther)
}

func (s *Server) handleCascadeApply(w http.ResponseWriter, r *http.Request) {
	cascade, ok := s.mustCascade(w, r)
	if !ok {
		return
	}
	if s.endpoint == nil {
		http.Redirect(w, r, "/cascades?error="+urlQueryEscape("Live mode выключен"), http.StatusSeeOther)
		return
	}

	if err := s.endpoint.ApplyCascade(r.Context(), *cascade); err != nil {
		http.Redirect(w, r, "/cascades?error="+urlQueryEscape(err.Error()), http.StatusSeeOther)
		return
	}

	user, _ := s.currentUser(r)
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "cascade-apply", cascade.DisplayName, fmt.Sprintf("cascade_id=%d", cascade.ID))
	}

	http.Redirect(w, r, "/cascades?notice=Каскад применён к runtime", http.StatusSeeOther)
}

func (s *Server) handleCascadeDisable(w http.ResponseWriter, r *http.Request) {
	if s.endpoint == nil {
		http.Redirect(w, r, "/cascades?error="+urlQueryEscape("Live mode выключен"), http.StatusSeeOther)
		return
	}

	if err := s.endpoint.DisableCascade(r.Context()); err != nil {
		http.Redirect(w, r, "/cascades?error="+urlQueryEscape(err.Error()), http.StatusSeeOther)
		return
	}

	user, _ := s.currentUser(r)
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "cascade-disable", "runtime", "forward_protocol=direct")
	}

	http.Redirect(w, r, "/cascades?notice=Runtime возвращён в direct mode", http.StatusSeeOther)
}

func (s *Server) handleSocks5Apply(w http.ResponseWriter, r *http.Request) {
	if s.endpoint == nil {
		http.Redirect(w, r, "/cascades?error="+urlQueryEscape("Live mode выключен"), http.StatusSeeOther)
		return
	}
	if err := r.ParseForm(); err != nil {
		http.Redirect(w, r, "/cascades?error="+urlQueryEscape("Не удалось прочитать форму SOCKS5"), http.StatusSeeOther)
		return
	}
	port, err := strconv.Atoi(strings.TrimSpace(r.FormValue("port")))
	if err != nil {
		http.Redirect(w, r, "/cascades?error="+urlQueryEscape("Неверный порт SOCKS5"), http.StatusSeeOther)
		return
	}
	username := strings.TrimSpace(r.FormValue("username"))
	password := strings.TrimSpace(r.FormValue("password"))
	if err := s.endpoint.ApplySocks5(r.Context(), port, username, password); err != nil {
		http.Redirect(w, r, "/cascades?error="+urlQueryEscape(err.Error()), http.StatusSeeOther)
		return
	}
	user, _ := s.currentUser(r)
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "socks5-apply", "runtime", fmt.Sprintf("port=%d username=%s", port, username))
	}
	http.Redirect(w, r, "/cascades?notice=SOCKS5 включён", http.StatusSeeOther)
}

func (s *Server) handleSocks5Disable(w http.ResponseWriter, r *http.Request) {
	if s.endpoint == nil {
		http.Redirect(w, r, "/cascades?error="+urlQueryEscape("Live mode выключен"), http.StatusSeeOther)
		return
	}
	if err := s.endpoint.DisableSocks5(r.Context()); err != nil {
		http.Redirect(w, r, "/cascades?error="+urlQueryEscape(err.Error()), http.StatusSeeOther)
		return
	}
	user, _ := s.currentUser(r)
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "socks5-disable", "runtime", "stopped")
	}
	http.Redirect(w, r, "/cascades?notice=SOCKS5 выключен", http.StatusSeeOther)
}

func (s *Server) handleMTProtoApply(w http.ResponseWriter, r *http.Request) {
	if s.endpoint == nil {
		http.Redirect(w, r, "/cascades?error="+urlQueryEscape("Live mode выключен"), http.StatusSeeOther)
		return
	}
	if err := r.ParseForm(); err != nil {
		http.Redirect(w, r, "/cascades?error="+urlQueryEscape("Не удалось прочитать форму MTProto"), http.StatusSeeOther)
		return
	}
	port, err := strconv.Atoi(strings.TrimSpace(r.FormValue("port")))
	if err != nil {
		http.Redirect(w, r, "/cascades?error="+urlQueryEscape("Неверный порт MTProto"), http.StatusSeeOther)
		return
	}
	frontingDomain := strings.TrimSpace(r.FormValue("fronting_domain"))
	if err := s.endpoint.ApplyMTProto(r.Context(), port, frontingDomain); err != nil {
		http.Redirect(w, r, "/cascades?error="+urlQueryEscape(err.Error()), http.StatusSeeOther)
		return
	}
	user, _ := s.currentUser(r)
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "mtproto-apply", "runtime", fmt.Sprintf("port=%d fronting=%s", port, frontingDomain))
	}
	http.Redirect(w, r, "/cascades?notice=MTProto включён", http.StatusSeeOther)
}

func (s *Server) handleMTProtoDisable(w http.ResponseWriter, r *http.Request) {
	if s.endpoint == nil {
		http.Redirect(w, r, "/cascades?error="+urlQueryEscape("Live mode выключен"), http.StatusSeeOther)
		return
	}
	if err := s.endpoint.DisableMTProto(r.Context()); err != nil {
		http.Redirect(w, r, "/cascades?error="+urlQueryEscape(err.Error()), http.StatusSeeOther)
		return
	}
	user, _ := s.currentUser(r)
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "mtproto-disable", "runtime", "stopped")
	}
	http.Redirect(w, r, "/cascades?notice=MTProto выключен", http.StatusSeeOther)
}

func (s *Server) handleClientNewPage(w http.ResponseWriter, r *http.Request) {
	defaults, err := s.defaultClientForm(r.Context())
	if err != nil {
		s.serverError(w, err)
		return
	}
	user, _ := s.currentUser(r)
	s.render(w, "client_form.html", templateData{
		Title:        "Новый клиент",
		Active:       "clients",
		AppName:      s.cfg.AppName,
		CurrentUser:  user,
		EndpointAddr: s.endpointAddressLabel(),
		Form:         defaults,
	})
}

func (s *Server) handleClientCreate(w http.ResponseWriter, r *http.Request) {
	form, client, err := parseClientForm(r)
	if err != nil {
		user, _ := s.currentUser(r)
		s.render(w, "client_form.html", templateData{
			Title:        "Новый клиент",
			Active:       "clients",
			AppName:      s.cfg.AppName,
			CurrentUser:  user,
			Error:        err.Error(),
			EndpointAddr: s.endpointAddressLabel(),
			Form: func() clientFormData {
				form.SubmitLabel = "Создать клиента"
				form.CancelURL = "/clients"
				return form
			}(),
		})
		return
	}

	id, err := s.store.CreateClient(r.Context(), client)
	if err != nil {
		s.serverError(w, err)
		return
	}
	client.ID = id

	if err := s.syncEndpointCredentials(r.Context()); err != nil {
		_ = s.store.DeleteClient(r.Context(), id)
		s.serverError(w, err)
		return
	}

	user, _ := s.currentUser(r)
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "client-create", client.DisplayName, fmt.Sprintf("client_id=%d", id))
	}

	http.Redirect(w, r, "/clients?notice=Клиент создан", http.StatusSeeOther)
}

func (s *Server) handleClientEditPage(w http.ResponseWriter, r *http.Request) {
	client, ok := s.mustClient(w, r)
	if !ok {
		return
	}

	user, _ := s.currentUser(r)
	s.render(w, "client_form.html", templateData{
		Title:        "Редактирование клиента",
		Active:       "clients",
		AppName:      s.cfg.AppName,
		CurrentUser:  user,
		EndpointAddr: s.endpointAddressLabel(),
		Form:         formFromClient(*client, "Сохранить изменения"),
	})
}

func (s *Server) handleClientUpdate(w http.ResponseWriter, r *http.Request) {
	existing, ok := s.mustClient(w, r)
	if !ok {
		return
	}

	form, client, err := parseClientForm(r)
	if err != nil {
		user, _ := s.currentUser(r)
		form.ID = existing.ID
		form.SubmitLabel = "Сохранить изменения"
		form.CancelURL = "/clients"
		s.render(w, "client_form.html", templateData{
			Title:        "Редактирование клиента",
			Active:       "clients",
			AppName:      s.cfg.AppName,
			CurrentUser:  user,
			Error:        err.Error(),
			EndpointAddr: s.endpointAddressLabel(),
			Form:         form,
		})
		return
	}

	client.ID = existing.ID
	if err := s.store.UpdateClient(r.Context(), client); err != nil {
		s.serverError(w, err)
		return
	}

	if err := s.syncEndpointCredentials(r.Context()); err != nil {
		_ = s.store.UpdateClient(r.Context(), existing)
		s.serverError(w, err)
		return
	}

	user, _ := s.currentUser(r)
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "client-update", client.DisplayName, fmt.Sprintf("client_id=%d", client.ID))
	}

	http.Redirect(w, r, "/clients?notice=Клиент обновлён", http.StatusSeeOther)
}

func (s *Server) handleClientDelete(w http.ResponseWriter, r *http.Request) {
	client, ok := s.mustClient(w, r)
	if !ok {
		return
	}

	if err := s.store.DeleteClient(r.Context(), client.ID); err != nil {
		s.serverError(w, err)
		return
	}

	if err := s.syncEndpointCredentials(r.Context()); err != nil {
		_, _ = s.store.CreateClient(r.Context(), client)
		s.serverError(w, err)
		return
	}

	user, _ := s.currentUser(r)
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "client-delete", client.DisplayName, fmt.Sprintf("client_id=%d", client.ID))
	}

	http.Redirect(w, r, "/clients?notice=Клиент удалён", http.StatusSeeOther)
}

func (s *Server) handleClientExportPage(w http.ResponseWriter, r *http.Request) {
	client, ok := s.mustClient(w, r)
	if !ok {
		return
	}

	deepLink, qrDataURI, err := s.clientExportAssets(*client)
	if err != nil {
		s.serverError(w, err)
		return
	}

	user, _ := s.currentUser(r)
	s.render(w, "client_export.html", templateData{
		Title:        "Экспорт клиента",
		Active:       "clients",
		AppName:      s.cfg.AppName,
		CurrentUser:  user,
		Client:       client,
		DeepLink:     deepLink,
		QRDataURI:    qrDataURI,
		EndpointAddr: s.endpointAddressLabel(),
	})
}

func (s *Server) handleClientDeepLink(w http.ResponseWriter, r *http.Request) {
	client, ok := s.mustClient(w, r)
	if !ok {
		return
	}

	deepLink, err := s.exportDeepLink(r.Context(), *client)
	if err != nil {
		s.serverError(w, err)
		return
	}

	user, _ := s.currentUser(r)
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "client-export", client.DisplayName, "deeplink viewed")
	}

	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	_, _ = w.Write([]byte(deepLink))
}

func (s *Server) handleClientQRPNG(w http.ResponseWriter, r *http.Request) {
	client, ok := s.mustClient(w, r)
	if !ok {
		return
	}

	deepLink, err := s.exportDeepLink(r.Context(), *client)
	if err != nil {
		s.serverError(w, err)
		return
	}

	png, err := qrcode.Encode(deepLink, qrcode.Medium, 320)
	if err != nil {
		s.serverError(w, err)
		return
	}

	user, _ := s.currentUser(r)
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "client-export", client.DisplayName, "qr generated")
	}

	w.Header().Set("Content-Type", "image/png")
	_, _ = w.Write(png)
}

func (s *Server) mustClient(w http.ResponseWriter, r *http.Request) (*storage.Client, bool) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return nil, false
	}

	client, err := s.store.GetClient(r.Context(), id)
	if err != nil {
		s.serverError(w, err)
		return nil, false
	}
	if client == nil {
		http.NotFound(w, r)
		return nil, false
	}

	return client, true
}

func (s *Server) mustCascade(w http.ResponseWriter, r *http.Request) (*storage.Cascade, bool) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return nil, false
	}

	cascade, err := s.store.GetCascade(r.Context(), id)
	if err != nil {
		s.serverError(w, err)
		return nil, false
	}
	if cascade == nil {
		http.NotFound(w, r)
		return nil, false
	}

	return cascade, true
}

func (s *Server) mustRoutingRule(w http.ResponseWriter, r *http.Request) (*storage.RoutingRule, bool) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return nil, false
	}
	item, err := s.store.GetRoutingRule(r.Context(), id)
	if err != nil {
		s.serverError(w, err)
		return nil, false
	}
	if item == nil {
		http.NotFound(w, r)
		return nil, false
	}
	return item, true
}

func (s *Server) mustZapretProfile(w http.ResponseWriter, r *http.Request) (*storage.ZapretProfile, bool) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.NotFound(w, r)
		return nil, false
	}
	item, err := s.store.GetZapretProfile(r.Context(), id)
	if err != nil {
		s.serverError(w, err)
		return nil, false
	}
	if item == nil {
		http.NotFound(w, r)
		return nil, false
	}
	return item, true
}

func (s *Server) clientExportAssets(client storage.Client) (string, string, error) {
	deepLink, err := s.exportDeepLink(context.Background(), client)
	if err != nil {
		return "", "", err
	}

	png, err := qrcode.Encode(deepLink, qrcode.Medium, 320)
	if err != nil {
		return "", "", err
	}

	return deepLink, "data:image/png;base64," + base64.StdEncoding.EncodeToString(png), nil
}

func (s *Server) authRequired(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		user, err := s.currentUser(r)
		if err != nil {
			s.serverError(w, err)
			return
		}
		if user == nil {
			http.Redirect(w, r, "/login", http.StatusSeeOther)
			return
		}

		ctx := context.WithValue(r.Context(), userCtxKey, user)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func (s *Server) currentUser(r *http.Request) (*storage.User, error) {
	if user, ok := r.Context().Value(userCtxKey).(*storage.User); ok && user != nil {
		return user, nil
	}

	cookie, err := r.Cookie(sessionCookieName)
	if err != nil {
		if errors.Is(err, http.ErrNoCookie) {
			return nil, nil
		}
		return nil, err
	}

	return s.store.GetUserBySession(r.Context(), cookie.Value)
}

func (s *Server) render(w http.ResponseWriter, page string, data templateData) {
	tmpl, err := template.New("base").Funcs(template.FuncMap{
		"formatBytes":      formatBytes,
		"formatPercent":    formatPercent,
		"formatTime":       formatTime,
		"usagePercent":     usagePercent,
		"formatPercentRaw": formatPercentRaw,
	}).ParseFS(assets, "templates/base.html", "templates/"+page)
	if err != nil {
		s.serverError(w, err)
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := tmpl.ExecuteTemplate(w, "base", data); err != nil {
		log.Printf("render %s: %v", page, err)
	}
}

func formatBytes(value uint64) string {
	const unit = 1024
	if value < unit {
		return fmt.Sprintf("%d B", value)
	}

	div, exp := uint64(unit), 0
	for n := value / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}

	return fmt.Sprintf("%.1f %ciB", float64(value)/float64(div), "KMGTPE"[exp])
}

func formatPercent(value float64) string {
	return fmt.Sprintf("%.1f%%", value)
}

func formatPercentRaw(value float64) string {
	return fmt.Sprintf("%.2f", value)
}

func usagePercent(used, total uint64) float64 {
	if total == 0 {
		return 0
	}
	return float64(used) / float64(total) * 100
}

func formatTime(value time.Time) string {
	if value.IsZero() {
		return "—"
	}
	return value.Local().Format("2006-01-02 15:04:05")
}

func (s *Server) serverError(w http.ResponseWriter, err error) {
	log.Printf("webui error: %v", err)
	http.Error(w, "Внутренняя ошибка сервера", http.StatusInternalServerError)
}

func (s *Server) logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("%s %s %s", r.Method, r.URL.Path, time.Since(start).Round(time.Millisecond))
	})
}

func (s *Server) endpointAddressLabel() string {
	addr := strings.TrimSpace(s.cfg.EndpointPublicAddress)
	if addr == "" {
		return "—"
	}
	if strings.Contains(addr, ":") {
		return addr
	}
	if s.cfg.EndpointPort > 0 {
		return fmt.Sprintf("%s:%d", addr, s.cfg.EndpointPort)
	}
	return addr
}

func parseClientForm(r *http.Request) (clientFormData, *storage.Client, error) {
	if err := r.ParseForm(); err != nil {
		return clientFormData{}, nil, fmt.Errorf("не удалось прочитать форму")
	}

	form := clientFormData{
		DisplayName:        strings.TrimSpace(r.FormValue("display_name")),
		Hostname:           strings.TrimSpace(r.FormValue("hostname")),
		Addresses:          strings.TrimSpace(r.FormValue("addresses")),
		Username:           strings.TrimSpace(r.FormValue("username")),
		Password:           r.FormValue("password"),
		CustomSNI:          strings.TrimSpace(r.FormValue("custom_sni")),
		HasIPv6:            r.FormValue("has_ipv6") == "on",
		SkipVerification:   r.FormValue("skip_verification") == "on",
		CertificatePEM:     strings.TrimSpace(r.FormValue("certificate_pem")),
		UpstreamProtocol:   strings.TrimSpace(r.FormValue("upstream_protocol")),
		AntiDPI:            r.FormValue("anti_dpi") == "on",
		ClientRandomPrefix: strings.TrimSpace(r.FormValue("client_random_prefix")),
	}

	if form.UpstreamProtocol == "" {
		form.UpstreamProtocol = "http2"
	}

	switch form.UpstreamProtocol {
	case "http2", "http3":
	default:
		return form, nil, fmt.Errorf("поддерживаются только upstream protocol: http2 или http3")
	}

	addresses := splitAddresses(form.Addresses)
	if form.DisplayName == "" {
		return form, nil, fmt.Errorf("нужно указать имя клиента")
	}
	if form.Hostname == "" {
		return form, nil, fmt.Errorf("нужно указать hostname")
	}
	if len(addresses) == 0 {
		return form, nil, fmt.Errorf("нужно указать хотя бы один address:port")
	}
	if form.Username == "" {
		return form, nil, fmt.Errorf("нужно указать username")
	}
	if form.Password == "" {
		return form, nil, fmt.Errorf("нужно указать password")
	}

	return form, &storage.Client{
		DisplayName:        form.DisplayName,
		Hostname:           form.Hostname,
		Addresses:          addresses,
		Username:           form.Username,
		Password:           form.Password,
		CustomSNI:          form.CustomSNI,
		HasIPv6:            form.HasIPv6,
		SkipVerification:   form.SkipVerification,
		CertificatePEM:     form.CertificatePEM,
		UpstreamProtocol:   form.UpstreamProtocol,
		AntiDPI:            form.AntiDPI,
		ClientRandomPrefix: form.ClientRandomPrefix,
	}, nil
}

func formFromClient(client storage.Client, submitLabel string) clientFormData {
	return clientFormData{
		ID:                 client.ID,
		DisplayName:        client.DisplayName,
		Hostname:           client.Hostname,
		Addresses:          strings.Join(client.Addresses, ", "),
		Username:           client.Username,
		Password:           client.Password,
		CustomSNI:          client.CustomSNI,
		HasIPv6:            client.HasIPv6,
		SkipVerification:   client.SkipVerification,
		CertificatePEM:     client.CertificatePEM,
		UpstreamProtocol:   client.UpstreamProtocol,
		AntiDPI:            client.AntiDPI,
		ClientRandomPrefix: client.ClientRandomPrefix,
		SubmitLabel:        submitLabel,
		CancelURL:          "/clients",
	}
}

func (s *Server) defaultClientForm(ctx context.Context) (clientFormData, error) {
	form := clientFormData{
		HasIPv6:          true,
		UpstreamProtocol: "http2",
		SubmitLabel:      "Создать клиента",
		CancelURL:        "/clients",
		Username:         "user-" + randomString(6),
		Password:         randomString(18),
	}

	host := strings.TrimSpace(s.cfg.EndpointPublicAddress)
	if host != "" {
		form.Hostname = host
		if s.cfg.EndpointPort > 0 {
			form.Addresses = fmt.Sprintf("%s:%d", host, s.cfg.EndpointPort)
		}
	}

	clients, err := s.store.ListClients(ctx)
	if err != nil {
		return form, err
	}
	if len(clients) == 0 {
		return form, nil
	}

	seed := clients[0]
	if form.Hostname == "" {
		form.Hostname = seed.Hostname
	}
	if form.Addresses == "" {
		form.Addresses = strings.Join(seed.Addresses, ", ")
	}
	form.HasIPv6 = seed.HasIPv6
	form.SkipVerification = seed.SkipVerification
	form.CertificatePEM = seed.CertificatePEM
	form.UpstreamProtocol = seed.UpstreamProtocol
	form.AntiDPI = seed.AntiDPI
	form.CustomSNI = seed.CustomSNI
	form.ClientRandomPrefix = seed.ClientRandomPrefix
	return form, nil
}

func randomString(length int) string {
	if length <= 0 {
		return ""
	}
	raw := make([]byte, length)
	if _, err := rand.Read(raw); err != nil {
		return "fallback123"
	}
	token := base64.RawURLEncoding.EncodeToString(raw)
	if len(token) > length {
		token = token[:length]
	}
	return token
}

func parseCascadeForm(r *http.Request) (cascadeFormData, *storage.Cascade, error) {
	if err := r.ParseForm(); err != nil {
		return cascadeFormData{}, nil, fmt.Errorf("не удалось прочитать форму")
	}

	form := cascadeFormData{
		DisplayName:        strings.TrimSpace(r.FormValue("display_name")),
		Hostname:           strings.TrimSpace(r.FormValue("hostname")),
		Addresses:          strings.TrimSpace(r.FormValue("addresses")),
		Username:           strings.TrimSpace(r.FormValue("username")),
		Password:           r.FormValue("password"),
		CustomSNI:          strings.TrimSpace(r.FormValue("custom_sni")),
		SkipVerification:   r.FormValue("skip_verification") == "on",
		CertificatePEM:     strings.TrimSpace(r.FormValue("certificate_pem")),
		UpstreamProtocol:   strings.TrimSpace(r.FormValue("upstream_protocol")),
		AntiDPI:            r.FormValue("anti_dpi") == "on",
		ClientRandomPrefix: strings.TrimSpace(r.FormValue("client_random_prefix")),
		Enabled:            r.FormValue("enabled") == "on",
		Notes:              strings.TrimSpace(r.FormValue("notes")),
	}

	if form.UpstreamProtocol == "" {
		form.UpstreamProtocol = "http2"
	}

	switch form.UpstreamProtocol {
	case "http2", "http3":
	default:
		return form, nil, fmt.Errorf("поддерживаются только upstream protocol: http2 или http3")
	}

	addresses := splitAddresses(form.Addresses)
	if form.DisplayName == "" {
		return form, nil, fmt.Errorf("нужно указать имя каскада")
	}
	if form.Hostname == "" {
		return form, nil, fmt.Errorf("нужно указать hostname")
	}
	if len(addresses) == 0 {
		return form, nil, fmt.Errorf("нужно указать хотя бы один address:port")
	}
	if form.Username == "" {
		return form, nil, fmt.Errorf("нужно указать username")
	}
	if form.Password == "" {
		return form, nil, fmt.Errorf("нужно указать password")
	}

	return form, &storage.Cascade{
		DisplayName:        form.DisplayName,
		Hostname:           form.Hostname,
		Addresses:          addresses,
		Username:           form.Username,
		Password:           form.Password,
		CustomSNI:          form.CustomSNI,
		SkipVerification:   form.SkipVerification,
		CertificatePEM:     form.CertificatePEM,
		UpstreamProtocol:   form.UpstreamProtocol,
		AntiDPI:            form.AntiDPI,
		ClientRandomPrefix: form.ClientRandomPrefix,
		Enabled:            form.Enabled,
		Notes:              form.Notes,
	}, nil
}

func formFromCascade(cascade storage.Cascade, submitLabel string) cascadeFormData {
	return cascadeFormData{
		ID:                 cascade.ID,
		DisplayName:        cascade.DisplayName,
		Hostname:           cascade.Hostname,
		Addresses:          strings.Join(cascade.Addresses, "\n"),
		Username:           cascade.Username,
		Password:           cascade.Password,
		CustomSNI:          cascade.CustomSNI,
		SkipVerification:   cascade.SkipVerification,
		CertificatePEM:     cascade.CertificatePEM,
		UpstreamProtocol:   cascade.UpstreamProtocol,
		AntiDPI:            cascade.AntiDPI,
		ClientRandomPrefix: cascade.ClientRandomPrefix,
		Enabled:            cascade.Enabled,
		Notes:              cascade.Notes,
		SubmitLabel:        submitLabel,
		CancelURL:          "/cascades",
	}
}

func parseRoutingRuleForm(r *http.Request) (routingRuleFormData, *storage.RoutingRule, error) {
	if err := r.ParseForm(); err != nil {
		return routingRuleFormData{}, nil, fmt.Errorf("не удалось прочитать форму")
	}

	cascadeID, _ := strconv.ParseInt(strings.TrimSpace(r.FormValue("cascade_id")), 10, 64)
	zapretProfileID, _ := strconv.ParseInt(strings.TrimSpace(r.FormValue("zapret_profile_id")), 10, 64)
	priority, err := strconv.Atoi(strings.TrimSpace(r.FormValue("priority")))
	if err != nil {
		priority = 100
	}

	form := routingRuleFormData{
		DisplayName:     strings.TrimSpace(r.FormValue("display_name")),
		MatchType:       strings.TrimSpace(r.FormValue("match_type")),
		MatchValue:      strings.TrimSpace(r.FormValue("match_value")),
		Action:          strings.TrimSpace(r.FormValue("action")),
		CascadeID:       cascadeID,
		ZapretProfileID: zapretProfileID,
		Enabled:         r.FormValue("enabled") == "on",
		Priority:        priority,
		Notes:           strings.TrimSpace(r.FormValue("notes")),
	}

	switch form.MatchType {
	case "domain", "cidr", "geoip", "geosite":
	default:
		return form, nil, fmt.Errorf("поддерживаются match type: domain, cidr, geoip, geosite")
	}

	switch form.Action {
	case "direct", "cascade", "zapret":
	default:
		return form, nil, fmt.Errorf("поддерживаются action: direct, cascade, zapret")
	}

	if form.DisplayName == "" {
		return form, nil, fmt.Errorf("нужно указать имя правила")
	}
	if form.MatchValue == "" {
		return form, nil, fmt.Errorf("нужно указать значение match")
	}
	if form.Action == "cascade" && form.CascadeID == 0 {
		return form, nil, fmt.Errorf("для action=cascade нужно выбрать каскад")
	}
	if form.Action == "zapret" && form.ZapretProfileID == 0 {
		return form, nil, fmt.Errorf("для action=zapret нужно выбрать Zapret profile")
	}

	return form, &storage.RoutingRule{
		DisplayName:     form.DisplayName,
		MatchType:       form.MatchType,
		MatchValue:      form.MatchValue,
		Action:          form.Action,
		CascadeID:       form.CascadeID,
		ZapretProfileID: form.ZapretProfileID,
		Enabled:         form.Enabled,
		Priority:        form.Priority,
		Notes:           form.Notes,
	}, nil
}

func formFromRoutingRule(item storage.RoutingRule, submitLabel string) routingRuleFormData {
	return routingRuleFormData{
		ID:              item.ID,
		DisplayName:     item.DisplayName,
		MatchType:       item.MatchType,
		MatchValue:      item.MatchValue,
		Action:          item.Action,
		CascadeID:       item.CascadeID,
		ZapretProfileID: item.ZapretProfileID,
		Enabled:         item.Enabled,
		Priority:        item.Priority,
		Notes:           item.Notes,
		SubmitLabel:     submitLabel,
		CancelURL:       "/routing",
	}
}

func parseZapretForm(r *http.Request) (zapretFormData, *storage.ZapretProfile, error) {
	if err := r.ParseForm(); err != nil {
		return zapretFormData{}, nil, fmt.Errorf("не удалось прочитать форму")
	}

	form := zapretFormData{
		DisplayName:  strings.TrimSpace(r.FormValue("display_name")),
		StrategyName: strings.TrimSpace(r.FormValue("strategy_name")),
		ScriptPath:   strings.TrimSpace(r.FormValue("script_path")),
		Args:         strings.TrimSpace(r.FormValue("args")),
		Enabled:      r.FormValue("enabled") == "on",
		Notes:        strings.TrimSpace(r.FormValue("notes")),
	}

	if form.DisplayName == "" {
		return form, nil, fmt.Errorf("нужно указать имя Zapret profile")
	}
	if form.StrategyName == "" {
		return form, nil, fmt.Errorf("нужно указать strategy name")
	}

	return form, &storage.ZapretProfile{
		DisplayName:  form.DisplayName,
		StrategyName: form.StrategyName,
		ScriptPath:   form.ScriptPath,
		Args:         form.Args,
		Enabled:      form.Enabled,
		Notes:        form.Notes,
	}, nil
}

func formFromZapretProfile(item storage.ZapretProfile, submitLabel string) zapretFormData {
	return zapretFormData{
		ID:           item.ID,
		DisplayName:  item.DisplayName,
		StrategyName: item.StrategyName,
		ScriptPath:   item.ScriptPath,
		Args:         item.Args,
		Enabled:      item.Enabled,
		Notes:        item.Notes,
		SubmitLabel:  submitLabel,
		CancelURL:    "/routing",
	}
}

func splitAddresses(raw string) []string {
	parts := strings.FieldsFunc(raw, func(r rune) bool {
		return r == '\n' || r == '\r' || r == ',' || r == ';'
	})

	var out []string
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part != "" {
			out = append(out, part)
		}
	}

	return out
}

func (s *Server) syncEndpointCredentials(ctx context.Context) error {
	if s.endpoint == nil {
		return nil
	}

	clients, err := s.store.ListClients(ctx)
	if err != nil {
		return err
	}

	return s.endpoint.SyncCredentials(ctx, clients)
}

func (s *Server) exportDeepLink(ctx context.Context, client storage.Client) (string, error) {
	if s.endpoint != nil {
		return s.endpoint.ExportDeepLink(ctx, client)
	}
	return ttlink.EncodeClient(client)
}

func (s *Server) ensureRoutingDatasets() {
	defaults := []storage.RoutingDataset{
		{
			Kind:        "geoip",
			DisplayName: "GeoIP",
			SourceURL:   s.cfg.GeoIPSourceURL,
			LocalPath:   filepath.Join(s.cfg.RoutingDataDir, "geoip.dat"),
		},
		{
			Kind:        "geosite",
			DisplayName: "GeoSite",
			SourceURL:   s.cfg.GeoSiteSourceURL,
			LocalPath:   filepath.Join(s.cfg.RoutingDataDir, "geosite.dat"),
		},
	}
	for _, item := range defaults {
		if err := s.store.EnsureRoutingDataset(context.Background(), item); err != nil {
			log.Printf("ensure routing dataset %s: %v", item.Kind, err)
		}
	}
}

func (s *Server) refreshRoutingDataset(ctx context.Context, kind string, user *storage.User) error {
	item, err := s.store.GetRoutingDataset(ctx, kind)
	if err != nil {
		return err
	}
	if item == nil {
		return fmt.Errorf("датасет не найден: %s", kind)
	}
	if strings.TrimSpace(item.SourceURL) == "" {
		return fmt.Errorf("для %s не задан source URL", kind)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, item.SourceURL, nil)
	if err != nil {
		return err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		_ = s.store.MarkRoutingDatasetResult(ctx, kind, time.Now().UTC(), false, err.Error())
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		err = fmt.Errorf("source returned status %s", resp.Status)
		_ = s.store.MarkRoutingDatasetResult(ctx, kind, time.Now().UTC(), false, err.Error())
		return err
	}

	if err := os.MkdirAll(filepath.Dir(item.LocalPath), 0o755); err != nil {
		return err
	}

	tmpPath := item.LocalPath + ".tmp"
	file, err := os.Create(tmpPath)
	if err != nil {
		return err
	}
	if _, err := io.Copy(file, resp.Body); err != nil {
		_ = file.Close()
		_ = os.Remove(tmpPath)
		return err
	}
	if err := file.Close(); err != nil {
		_ = os.Remove(tmpPath)
		return err
	}
	if err := os.Rename(tmpPath, item.LocalPath); err != nil {
		_ = os.Remove(tmpPath)
		return err
	}

	now := time.Now().UTC()
	if err := s.store.MarkRoutingDatasetResult(ctx, kind, now, true, ""); err != nil {
		return err
	}
	if user != nil {
		_ = s.store.AppendAudit(user.Username, "routing-dataset-refresh", kind, item.SourceURL)
	}
	return nil
}

func urlQueryEscape(value string) string {
	replacer := strings.NewReplacer(
		"%", "%25",
		" ", "%20",
		"+", "%2B",
		"&", "%26",
		"=", "%3D",
		"?", "%3F",
		"#", "%23",
	)
	return replacer.Replace(value)
}
