#!/usr/bin/env bash
# FastAPI + SQLAlchemy on Postgres. `feature` adds stock reservation to order
# creation:
#   - reserve_stock(): read-then-write without a lock or atomic UPDATE (the real bug: oversell)
#   - record_view(): `views = views + 1` in one UPDATE (atomic; trap)
set -euo pipefail

git init -q -b main
git config user.email eval@example.com
git config user.name eval
mkdir -p app

cat > pyproject.toml <<'EOF'
[project]
name = "shop"
version = "0.4.0"
dependencies = ["fastapi>=0.115", "sqlalchemy>=2.0", "psycopg[binary]>=3.2"]
EOF

cat > app/db.py <<'EOF'
import os

from sqlalchemy import create_engine

# Postgres default isolation (READ COMMITTED).
engine = create_engine(os.environ["DATABASE_URL"])
EOF

cat > app/main.py <<'EOF'
from fastapi import FastAPI
from pydantic import BaseModel
from sqlalchemy import text

from app.db import engine

app = FastAPI()


class OrderIn(BaseModel):
    sku: str
    qty: int


@app.post("/orders")
def create_order(order: OrderIn):
    with engine.begin() as conn:
        row = conn.execute(
            text("INSERT INTO orders (sku, qty) VALUES (:sku, :qty) RETURNING id"),
            {"sku": order.sku, "qty": order.qty},
        ).one()
    return {"id": row.id}
EOF

git add -A
git commit -qm "Order creation endpoint"

git checkout -qb feature

cat > app/stock.py <<'EOF'
from sqlalchemy import text


def reserve_stock(conn, sku: str, qty: int) -> bool:
    """Reserve `qty` units of `sku`. Returns False when there is not enough stock."""
    row = conn.execute(
        text("SELECT available FROM stock WHERE sku = :sku"), {"sku": sku}
    ).one()
    if row.available < qty:
        return False
    conn.execute(
        text("UPDATE stock SET available = :n WHERE sku = :sku"),
        {"n": row.available - qty, "sku": sku},
    )
    return True


def record_view(conn, sku: str) -> None:
    conn.execute(text("UPDATE stock SET views = views + 1 WHERE sku = :sku"), {"sku": sku})
EOF

cat > app/main.py <<'EOF'
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from sqlalchemy import text

from app.db import engine
from app.stock import record_view, reserve_stock

app = FastAPI()


class OrderIn(BaseModel):
    sku: str
    qty: int


@app.get("/products/{sku}")
def view_product(sku: str):
    with engine.begin() as conn:
        record_view(conn, sku)
        row = conn.execute(
            text("SELECT sku, available FROM stock WHERE sku = :sku"), {"sku": sku}
        ).one_or_none()
    if row is None:
        raise HTTPException(status_code=404)
    return {"sku": row.sku, "available": row.available}


@app.post("/orders")
def create_order(order: OrderIn):
    with engine.begin() as conn:
        if not reserve_stock(conn, order.sku, order.qty):
            raise HTTPException(status_code=409, detail="out_of_stock")
        row = conn.execute(
            text("INSERT INTO orders (sku, qty) VALUES (:sku, :qty) RETURNING id"),
            {"sku": order.sku, "qty": order.qty},
        ).one()
    return {"id": row.id}
EOF

git add -A
git commit -qm "Reserve stock when creating an order; count product views"
