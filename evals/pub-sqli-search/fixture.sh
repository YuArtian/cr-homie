#!/usr/bin/env bash
# Builds a tiny Express app: `main` = base, `feature` (checked out) = the change under review.
# feature adds:
#   - GET /users/search — interpolates req.query.name into SQL (the real bug)
#   - GET /reports      — interpolates ORDER BY from an allowlist (safe; trap)
set -euo pipefail

git init -q -b main
git config user.email eval@example.com
git config user.name eval
mkdir -p src/routes

cat > package.json <<'EOF'
{
  "name": "notes-api",
  "private": true,
  "main": "src/app.js",
  "dependencies": { "express": "^4.21.0", "jsonwebtoken": "^9.0.2", "pg": "^8.13.0" }
}
EOF

cat > src/db.js <<'EOF'
const { Pool } = require("pg");

const pool = new Pool();

module.exports = {
  query: (text, params) => pool.query(text, params),
};
EOF

cat > src/auth.js <<'EOF'
const jwt = require("jsonwebtoken");

module.exports = function requireUser(req, res, next) {
  const token = (req.headers.authorization || "").replace(/^Bearer /, "");
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: "unauthorized" });
  }
};
EOF

cat > src/routes/users.js <<'EOF'
const express = require("express");
const db = require("../db");

const router = express.Router();

router.get("/users/:id", async (req, res) => {
  const { rows } = await db.query(
    "SELECT id, name FROM users WHERE id = $1",
    [req.params.id],
  );
  if (!rows.length) return res.status(404).json({ error: "not_found" });
  res.json(rows[0]);
});

module.exports = router;
EOF

cat > src/app.js <<'EOF'
const express = require("express");
const requireUser = require("./auth");

const app = express();
app.use(express.json());
app.use(requireUser);
app.use(require("./routes/users"));

module.exports = app;
EOF

git add -A
git commit -qm "Initial notes API"

git checkout -qb feature

cat > src/routes/users.js <<'EOF'
const express = require("express");
const db = require("../db");

const router = express.Router();

// Typeahead for the share dialog: match users by name.
router.get("/users/search", async (req, res) => {
  const name = String(req.query.name || "");
  const { rows } = await db.query(
    `SELECT id, name FROM users WHERE name ILIKE '%${name}%' LIMIT 20`,
  );
  res.json(rows);
});

router.get("/users/:id", async (req, res) => {
  const { rows } = await db.query(
    "SELECT id, name FROM users WHERE id = $1",
    [req.params.id],
  );
  if (!rows.length) return res.status(404).json({ error: "not_found" });
  res.json(rows[0]);
});

module.exports = router;
EOF

cat > src/routes/reports.js <<'EOF'
const express = require("express");
const db = require("../db");

const router = express.Router();

// Only these exact strings can reach the ORDER BY clause.
const SORT_COLUMNS = {
  newest: "created_at DESC",
  oldest: "created_at ASC",
  title: "title ASC",
};

router.get("/reports", async (req, res) => {
  const order = SORT_COLUMNS[req.query.sort] || SORT_COLUMNS.newest;
  const { rows } = await db.query(
    `SELECT id, title, created_at FROM reports WHERE owner_id = $1 ORDER BY ${order}`,
    [req.user.sub],
  );
  res.json(rows);
});

module.exports = router;
EOF

cat > src/app.js <<'EOF'
const express = require("express");
const requireUser = require("./auth");

const app = express();
app.use(express.json());
app.use(requireUser);
app.use(require("./routes/users"));
app.use(require("./routes/reports"));

module.exports = app;
EOF

git add -A
git commit -qm "Add user search and report listing"
