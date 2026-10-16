#!/usr/bin/env bash
# Clean case (false-positive probe). `feature` extracts duplicated email
# normalization into one helper, keeps behavior identical, and adds tests.
set -euo pipefail

git init -q -b main
git config user.email eval@example.com
git config user.name eval
mkdir -p accounts tests

cat > pyproject.toml <<'EOF'
[project]
name = "accounts"
version = "1.2.0"

[tool.ruff]
line-length = 100
EOF

cat > accounts/__init__.py <<'EOF'
EOF

cat > accounts/signup.py <<'EOF'
def signup(repo, email: str, password_hash: str):
    email = email.strip().lower()
    if repo.exists(email):
        raise ValueError("email_taken")
    return repo.create(email=email, password_hash=password_hash)
EOF

cat > accounts/login.py <<'EOF'
def find_account(repo, email: str):
    email = email.strip().lower()
    return repo.get(email)
EOF

git add -A
git commit -qm "Signup and login lookup"

git checkout -qb feature

cat > accounts/emails.py <<'EOF'
def normalize_email(email: str) -> str:
    """Canonical form used as the account key: surrounding whitespace removed, lower-cased."""
    return email.strip().lower()
EOF

cat > accounts/signup.py <<'EOF'
from accounts.emails import normalize_email


def signup(repo, email: str, password_hash: str):
    email = normalize_email(email)
    if repo.exists(email):
        raise ValueError("email_taken")
    return repo.create(email=email, password_hash=password_hash)
EOF

cat > accounts/login.py <<'EOF'
from accounts.emails import normalize_email


def find_account(repo, email: str):
    return repo.get(normalize_email(email))
EOF

cat > tests/test_emails.py <<'EOF'
import pytest

from accounts.emails import normalize_email


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("Alice@Example.com", "alice@example.com"),
        ("  bob@example.com\n", "bob@example.com"),
        ("carol@example.com", "carol@example.com"),
    ],
)
def test_normalize_email(raw, expected):
    assert normalize_email(raw) == expected


def test_signup_and_login_agree_on_the_key():
    class Repo:
        def __init__(self):
            self.rows = {}

        def exists(self, email):
            return email in self.rows

        def create(self, email, password_hash):
            self.rows[email] = password_hash
            return email

        def get(self, email):
            return self.rows.get(email)

    from accounts.login import find_account
    from accounts.signup import signup

    repo = Repo()
    signup(repo, " Dana@Example.com ", "h")
    assert find_account(repo, "dana@example.COM") == "h"
EOF

git add -A
git commit -qm "Extract normalize_email and test it"
