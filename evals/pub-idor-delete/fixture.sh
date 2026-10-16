#!/usr/bin/env bash
# Go net/http notes service. `feature` adds:
#   - DELETE /notes/{id}: deletes by id with no ownership check (real bug: IDOR; GET checks ownership)
#   - POST /admin/purge: handler has no auth check itself, but is only mounted behind requireAdmin (trap)
set -euo pipefail

git init -q -b main
git config user.email eval@example.com
git config user.name eval

cat > go.mod <<'EOF'
module example.com/notes

go 1.23
EOF

cat > store.go <<'EOF'
package main

import (
	"database/sql"
	"errors"
)

type Note struct {
	ID      string
	OwnerID string
	Body    string
}

var ErrNotFound = errors.New("not found")

type Store struct{ db *sql.DB }

func (s *Store) Get(id string) (Note, error) {
	var n Note
	err := s.db.QueryRow(`SELECT id, owner_id, body FROM notes WHERE id = $1`, id).Scan(&n.ID, &n.OwnerID, &n.Body)
	if errors.Is(err, sql.ErrNoRows) {
		return n, ErrNotFound
	}
	return n, err
}
EOF

cat > auth.go <<'EOF'
package main

import (
	"context"
	"net/http"
)

type ctxKey struct{}

type User struct {
	ID    string
	Admin bool
}

// requireUser resolves the session cookie to a user (verification elided).
func requireUser(sessions map[string]User, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		c, err := r.Cookie("session")
		if err != nil {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		u, ok := sessions[c.Value]
		if !ok {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), ctxKey{}, u)))
	})
}

func currentUser(r *http.Request) User { return r.Context().Value(ctxKey{}).(User) }
EOF

cat > handlers.go <<'EOF'
package main

import (
	"encoding/json"
	"errors"
	"net/http"
)

type API struct{ store *Store }

func (a *API) getNote(w http.ResponseWriter, r *http.Request) {
	n, err := a.store.Get(r.PathValue("id"))
	if errors.Is(err, ErrNotFound) || (err == nil && n.OwnerID != currentUser(r).ID) {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	if err != nil {
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	json.NewEncoder(w).Encode(n)
}
EOF

cat > main.go <<'EOF'
package main

import (
	"database/sql"
	"log"
	"net/http"
	"os"
)

func main() {
	db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	api := &API{store: &Store{db: db}}
	sessions := map[string]User{}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /notes/{id}", api.getNote)

	log.Fatal(http.ListenAndServe(":8080", requireUser(sessions, mux)))
}
EOF

git add -A
git commit -qm "Notes service: read endpoint"

git checkout -qb feature

cat >> store.go <<'EOF'

func (s *Store) Delete(id string) error {
	_, err := s.db.Exec(`DELETE FROM notes WHERE id = $1`, id)
	return err
}

func (s *Store) PurgeDeletedUsers() (int64, error) {
	res, err := s.db.Exec(`DELETE FROM notes WHERE owner_id IN (SELECT id FROM users WHERE deleted_at IS NOT NULL)`)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}
EOF

cat >> auth.go <<'EOF'

// requireAdmin must wrap every /admin/ route.
func requireAdmin(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !currentUser(r).Admin {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		next.ServeHTTP(w, r)
	})
}
EOF

cat >> handlers.go <<'EOF'

func (a *API) deleteNote(w http.ResponseWriter, r *http.Request) {
	if err := a.store.Delete(r.PathValue("id")); err != nil {
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) adminPurge(w http.ResponseWriter, r *http.Request) {
	n, err := a.store.PurgeDeletedUsers()
	if err != nil {
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	json.NewEncoder(w).Encode(map[string]int64{"deleted": n})
}
EOF

cat > main.go <<'EOF'
package main

import (
	"database/sql"
	"log"
	"net/http"
	"os"
)

func main() {
	db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	api := &API{store: &Store{db: db}}
	sessions := map[string]User{}

	admin := http.NewServeMux()
	admin.HandleFunc("POST /admin/purge", api.adminPurge)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /notes/{id}", api.getNote)
	mux.HandleFunc("DELETE /notes/{id}", api.deleteNote)
	mux.Handle("/admin/", requireAdmin(admin))

	log.Fatal(http.ListenAndServe(":8080", requireUser(sessions, mux)))
}
EOF

git add -A
git commit -qm "Delete notes; admin purge for deleted users"
