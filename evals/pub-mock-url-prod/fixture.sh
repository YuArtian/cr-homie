#!/usr/bin/env bash
# React + Vite app. `feature` adds a Billing page:
#   - fetches from a hard-coded localhost mock URL in production code (real bug)
#   - on fetch failure, silently shows DEMO_INVOICES as if they were the user's (real bug)
#   - __fixtures__/invoices.json imported only by the test (trap: not prod-reachable)
set -euo pipefail

git init -q -b main
git config user.email eval@example.com
git config user.name eval
mkdir -p src/api src/pages

cat > package.json <<'EOF'
{
  "name": "billing-web",
  "private": true,
  "type": "module",
  "scripts": { "dev": "vite", "build": "vite build", "test": "vitest" },
  "dependencies": { "react": "^19.0.0", "react-dom": "^19.0.0" },
  "devDependencies": { "vite": "^6.0.0", "vitest": "^3.0.0", "@testing-library/react": "^16.0.0" }
}
EOF

cat > src/api/client.js <<'EOF'
const API_URL = import.meta.env.VITE_API_URL;

export async function getJson(path) {
  const res = await fetch(`${API_URL}${path}`, { credentials: "include" });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}
EOF

cat > src/pages/Orders.jsx <<'EOF'
import { useEffect, useState } from "react";
import { getJson } from "../api/client";

export default function Orders() {
  const [orders, setOrders] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    getJson("/orders").then(setOrders).catch(setError);
  }, []);

  if (error) return <p role="alert">Could not load orders.</p>;
  return (
    <ul>
      {orders.map((o) => (
        <li key={o.id}>{o.title}</li>
      ))}
    </ul>
  );
}
EOF

git add -A
git commit -qm "Orders page"

git checkout -qb feature
mkdir -p src/pages/__fixtures__

cat > src/pages/Billing.jsx <<'EOF'
import { useEffect, useState } from "react";

const BILLING_URL = "http://localhost:4000/mock/billing/invoices";

const DEMO_INVOICES = [
  { id: "inv_001", amount: 4900, status: "paid", period: "2026-08" },
  { id: "inv_002", amount: 4900, status: "paid", period: "2026-09" },
];

export default function Billing() {
  const [invoices, setInvoices] = useState([]);

  useEffect(() => {
    fetch(BILLING_URL)
      .then((res) => res.json())
      .then(setInvoices)
      .catch(() => setInvoices(DEMO_INVOICES));
  }, []);

  return (
    <table>
      <tbody>
        {invoices.map((inv) => (
          <tr key={inv.id}>
            <td>{inv.period}</td>
            <td>{(inv.amount / 100).toFixed(2)}</td>
            <td>{inv.status}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
EOF

cat > src/pages/__fixtures__/invoices.json <<'EOF'
[
  { "id": "inv_test_1", "amount": 1200, "status": "open", "period": "2026-01" }
]
EOF

cat > src/pages/Billing.test.jsx <<'EOF'
import { render, screen } from "@testing-library/react";
import { afterEach, expect, test, vi } from "vitest";
import invoices from "./__fixtures__/invoices.json";
import Billing from "./Billing";

afterEach(() => vi.restoreAllMocks());

test("renders invoices", async () => {
  vi.spyOn(globalThis, "fetch").mockResolvedValue({ json: async () => invoices });
  render(<Billing />);
  expect(await screen.findByText("2026-01")).toBeTruthy();
});
EOF

git add -A
git commit -qm "Add billing page"
