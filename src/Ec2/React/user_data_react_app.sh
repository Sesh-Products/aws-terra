#!/bin/bash
set -e

# Variables injected by Terraform as env var exports before this script
APP_DIR="/home/ec2-user/app"
WEB_DIR="/var/www/products-app"

# =============================================================================
# System Updates & Dependencies
# =============================================================================
dnf update -y
dnf install -y nginx certbot python3-certbot-nginx

# Node.js 20
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs

# =============================================================================
# App Directory Structure
# =============================================================================
mkdir -p $APP_DIR/frontend
mkdir -p $APP_DIR/backend
mkdir -p $WEB_DIR
chown -R ec2-user:ec2-user $APP_DIR

# =============================================================================
# Backend — Node.js Express API
# =============================================================================
cat > $APP_DIR/backend/package.json << 'EOF'
{
  "name": "products-api",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": { "start": "node index.js" },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "snowflake-sdk": "^1.9.0",
    "@aws-sdk/client-secrets-manager": "^3.0.0"
  }
}
EOF

cat > $APP_DIR/backend/index.js << 'EOF'
const express = require('express');
const cors = require('cors');
const snowflake = require('snowflake-sdk');
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');

const app = express();
app.use(cors());
app.use(express.json());

const secretsClient = new SecretsManagerClient({ region: process.env.AWS_REGION || 'us-east-1' });

async function getSnowflakeCreds() {
  const [credsRes, keyRes] = await Promise.all([
    secretsClient.send(new GetSecretValueCommand({
      SecretId: `snowflake/pos-pipeline/${process.env.ENVIRONMENT}/credentials`
    })),
    secretsClient.send(new GetSecretValueCommand({
      SecretId: `snowflake/pos-pipeline/${process.env.ENVIRONMENT}/private-key`
    }))
  ]);
  return {
    creds: JSON.parse(credsRes.SecretString),
    privateKey: keyRes.SecretString
  };
}

async function getConnection() {
  const { creds, privateKey } = await getSnowflakeCreds();
  return new Promise((resolve, reject) => {
    const conn = snowflake.createConnection({
      account:       `${creds.organization}-${creds.account}`,
      username:      creds.username,
      authenticator: 'SNOWFLAKE_JWT',
      privateKey:    privateKey.replace(/\\n/g, '\n'),
      database:      'SESH_METADATA',
      warehouse:     'COMPUTE_WH',
      role:          'ACCOUNTADMIN'
    });
    conn.connect(err => err ? reject(err) : resolve(conn));
  });
}

// GET /api/brands
app.get('/api/brands', async (req, res) => {
  try {
    const conn = await getConnection();
    conn.execute({
      sqlText: `SELECT BRAND_ID, BRAND_NAME
                FROM SESH_METADATA.PUBLIC.DIM_BRAND
                ORDER BY BRAND_NAME`,
      complete: (err, stmt, rows) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(rows);
      }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/products?brand_id=X
app.get('/api/products', async (req, res) => {
  const { brand_id } = req.query;
  const whereClause = brand_id ? `WHERE p.BRAND_ID = ${parseInt(brand_id)}` : '';
  try {
    const conn = await getConnection();
    conn.execute({
      sqlText: `SELECT
                  p.PROD_ID,
                  p.UPC,
                  p.PACK_CNT,
                  p.POUCH_CNT,
                  p.STRENGTH,
                  p.FLAVOUR,
                  p.BRAND_ID,
                  p.PROD_NAME,
                  b.BRAND_NAME
                FROM SESH_METADATA.PUBLIC.DIM_PRODUCT p
                JOIN SESH_METADATA.PUBLIC.DIM_BRAND b ON p.BRAND_ID = b.BRAND_ID
                ${whereClause}
                ORDER BY b.BRAND_NAME, p.PROD_NAME`,
      complete: (err, stmt, rows) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(rows);
      }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/products
app.post('/api/products', async (req, res) => {
  const { upc, pack_cnt, pouch_cnt, strength, flavour, brand_id, prod_name } = req.body;
  if (!upc || !brand_id || !prod_name) {
    return res.status(400).json({ error: 'upc, brand_id and prod_name are required' });
  }
  try {
    const conn = await getConnection();
    conn.execute({
      sqlText: `INSERT INTO SESH_METADATA.PUBLIC.DIM_PRODUCT
                (UPC, PACK_CNT, POUCH_CNT, STRENGTH, FLAVOUR, BRAND_ID, PROD_NAME)
                VALUES (?, ?, ?, ?, ?, ?, ?)`,
      binds: [upc, pack_cnt || null, pouch_cnt || null, strength || null, flavour || null, brand_id, prod_name],
      complete: (err) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ success: true });
      }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.listen(process.env.APP_PORT || 3001, () => {
  console.log(`API running on port ${process.env.APP_PORT || 3001}`);
});
EOF

cd $APP_DIR/backend && npm install
chown -R ec2-user:ec2-user $APP_DIR/backend

# =============================================================================
# Frontend — React App (Vite)
# =============================================================================
cd $APP_DIR/frontend
sudo -u ec2-user npx create-vite@latest . --template react -- --yes || true
sudo -u ec2-user npm install
sudo -u ec2-user npm install axios

cat > $APP_DIR/frontend/src/App.jsx << 'REACTEOF'
import { useState, useEffect } from 'react'
import axios from 'axios'
import './App.css'

const API = '/api'
const SESH_BRAND_NAME = 'SESH (SESH PRODUCTS US)'

export default function App() {
  const [products, setProducts] = useState([])
  const [brands, setBrands] = useState([])
  const [seshBrandId, setSeshBrandId] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [showSeshOnly, setShowSeshOnly] = useState(false)
  const [filterFlavour, setFilterFlavour] = useState('all')
  const [filterStrength, setFilterStrength] = useState('all')
  const [search, setSearch] = useState('')
  const [form, setForm] = useState({
    upc: '', pack_cnt: '', pouch_cnt: '',
    strength: '', flavour: '', brand_id: '', prod_name: ''
  })
  const [submitting, setSubmitting] = useState(false)
  const [success, setSuccess] = useState(null)
  const [formError, setFormError] = useState(null)

  useEffect(() => {
    fetchBrands()
    fetchProducts()
  }, [])

  async function fetchBrands() {
    try {
      const { data } = await axios.get(`${API}/brands`)
      setBrands(data)
      const sesh = data.find(b => b.BRAND_NAME === SESH_BRAND_NAME)
      if (sesh) setSeshBrandId(sesh.BRAND_ID)
    } catch (e) {
      console.error('Failed to load brands')
    }
  }

  async function fetchProducts(brandId) {
    try {
      setLoading(true)
      const params = brandId ? `?brand_id=${brandId}` : ''
      const { data } = await axios.get(`${API}/products${params}`)
      setProducts(data)
    } catch (e) {
      setError('Failed to load products')
    } finally {
      setLoading(false)
    }
  }

  function handleToggleSesh() {
    const next = !showSeshOnly
    setShowSeshOnly(next)
    setFilterFlavour('all')
    setFilterStrength('all')
    setSearch('')
    fetchProducts(next && seshBrandId ? seshBrandId : null)
  }

  async function handleSubmit(e) {
    e.preventDefault()
    setSubmitting(true)
    setSuccess(null)
    setFormError(null)
    try {
      await axios.post(`${API}/products`, form)
      setSuccess('Product added successfully')
      setForm({ upc: '', pack_cnt: '', pouch_cnt: '', strength: '', flavour: '', brand_id: '', prod_name: '' })
      fetchProducts(showSeshOnly && seshBrandId ? seshBrandId : null)
    } catch (e) {
      setFormError(e.response?.data?.error || 'Failed to add product')
    } finally {
      setSubmitting(false)
    }
  }

  const flavours = [...new Set(products.map(p => p.FLAVOUR).filter(Boolean))].sort()
  const strengths = [...new Set(products.map(p => p.STRENGTH).filter(Boolean))].sort()

  const filtered = products.filter(p => {
    const matchesFlavour = filterFlavour === 'all' || p.FLAVOUR === filterFlavour
    const matchesStrength = filterStrength === 'all' || p.STRENGTH === filterStrength
    const matchesSearch = !search ||
      p.PROD_NAME?.toLowerCase().includes(search.toLowerCase()) ||
      String(p.UPC).includes(search)
    return matchesFlavour && matchesStrength && matchesSearch
  })

  const grouped = filtered.reduce((acc, p) => {
    const key = p.BRAND_NAME
    if (!acc[key]) acc[key] = []
    acc[key].push(p)
    return acc
  }, {})

  return (
    <div className="app">
      <header>
        <h1>Product Catalog</h1>
        <p>Manage your Product data</p>
      </header>
      <main>
        <section className="add-product">
          <h2>Add Product</h2>
          <form onSubmit={handleSubmit}>
            <div className="form-grid">
              <input
                placeholder="Product Name *"
                value={form.prod_name}
                onChange={e => setForm({ ...form, prod_name: e.target.value })}
                required
              />
              <input
                placeholder="UPC *"
                value={form.upc}
                onChange={e => setForm({ ...form, upc: e.target.value })}
                required
              />
              <select
                value={form.brand_id}
                onChange={e => setForm({ ...form, brand_id: e.target.value })}
                required
              >
                <option value="">Select Brand *</option>
                {brands.map(b => (
                  <option key={b.BRAND_ID} value={b.BRAND_ID}>{b.BRAND_NAME}</option>
                ))}
              </select>
              <input
                placeholder="Flavour"
                value={form.flavour}
                onChange={e => setForm({ ...form, flavour: e.target.value })}
              />
              <input
                placeholder="Strength (e.g. 4 MILLIGRAM)"
                value={form.strength}
                onChange={e => setForm({ ...form, strength: e.target.value })}
              />
              <input
                placeholder="Pack Count (e.g. 1 Pack)"
                value={form.pack_cnt}
                onChange={e => setForm({ ...form, pack_cnt: e.target.value })}
              />
              <input
                placeholder="Pouch Count (e.g. 21 COUNT)"
                value={form.pouch_cnt}
                onChange={e => setForm({ ...form, pouch_cnt: e.target.value })}
              />
            </div>
            <button type="submit" disabled={submitting}>
              {submitting ? 'Adding...' : 'Add Product'}
            </button>
          </form>
          {success && <p className="success">{success}</p>}
          {formError && <p className="error">{formError}</p>}
        </section>

        <section className="product-list">
          <div className="list-header">
            <div className="list-title">
              <h2>Products ({filtered.length})</h2>
              <button
                className={`sesh-toggle ${showSeshOnly ? 'active' : ''}`}
                onClick={handleToggleSesh}
              >
                {showSeshOnly ? 'Showing SESH Only' : 'Show SESH Only'}
              </button>
            </div>
            <div className="filters">
              <select value={filterFlavour} onChange={e => setFilterFlavour(e.target.value)}>
                <option value="all">All Flavours</option>
                {flavours.map(f => <option key={f} value={f}>{f}</option>)}
              </select>
              <select value={filterStrength} onChange={e => setFilterStrength(e.target.value)}>
                <option value="all">All Strengths</option>
                {strengths.map(s => <option key={s} value={s}>{s}</option>)}
              </select>
              <input
                className="search"
                placeholder="Search by name or UPC..."
                value={search}
                onChange={e => setSearch(e.target.value)}
              />
            </div>
          </div>

          {loading ? (
            <p className="loading">Loading products...</p>
          ) : error ? (
            <p className="error">{error}</p>
          ) : (
            Object.entries(grouped).map(([brand, items]) => (
              <div key={brand} className="brand-group">
                <h3>{brand}</h3>
                <table>
                  <thead>
                    <tr>
                      <th>Product Name</th>
                      <th>UPC</th>
                      <th>Flavour</th>
                      <th>Strength</th>
                      <th>Pack</th>
                      <th>Pouch</th>
                    </tr>
                  </thead>
                  <tbody>
                    {items.map((p, i) => (
                      <tr key={i}>
                        <td>{p.PROD_NAME}</td>
                        <td>{p.UPC}</td>
                        <td>{p.FLAVOUR}</td>
                        <td>{p.STRENGTH}</td>
                        <td>{p.PACK_CNT}</td>
                        <td>{p.POUCH_CNT}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ))
          )}
        </section>
      </main>
    </div>
  )
}
REACTEOF

cat > $APP_DIR/frontend/src/App.css << 'CSSEOF'
* { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  background: #f0f2f5;
  color: #1a1a2e;
}

.app { max-width: 1100px; margin: 0 auto; padding: 24px; }

header {
  margin-bottom: 32px;
  padding-bottom: 16px;
  border-bottom: 2px solid #dde3ed;
}

header h1 { font-size: 28px; font-weight: 700; color: #1a1a2e; }
header p  { color: #6b7280; margin-top: 4px; }

section {
  background: #ffffff;
  border-radius: 12px;
  padding: 24px;
  margin-bottom: 24px;
  border: 1px solid #e5e9f0;
  box-shadow: 0 2px 8px rgba(0,0,0,0.06);
}

h2 { font-size: 18px; font-weight: 600; margin-bottom: 16px; color: #1a1a2e; }

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  margin-bottom: 12px;
}

input, select {
  width: 100%;
  padding: 9px 12px;
  border: 1px solid #dde3ed;
  border-radius: 8px;
  font-size: 14px;
  background: #f8fafc;
  color: #1a1a2e;
}

input::placeholder { color: #9ca3af; }
input:focus, select:focus { outline: none; border-color: #4f7ef8; background: #ffffff; box-shadow: 0 0 0 3px rgba(79,126,248,0.1); }

select option { background: #ffffff; color: #1a1a2e; }

button {
  padding: 10px 24px;
  background: #4f7ef8;
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
}

button:disabled { opacity: 0.5; cursor: not-allowed; }
button:hover:not(:disabled) { background: #3b6af0; }

.success { color: #16a34a; margin-top: 10px; font-size: 14px; }
.error   { color: #dc2626; margin-top: 10px; font-size: 14px; }
.loading { color: #6b7280; font-size: 14px; }

.list-header { margin-bottom: 16px; }

.list-title {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 12px;
}

.sesh-toggle {
  padding: 6px 14px;
  border-radius: 20px;
  border: 2px solid #4f7ef8;
  background: transparent;
  color: #4f7ef8;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
}

.sesh-toggle.active {
  background: #4f7ef8;
  color: white;
}

.filters {
  display: flex;
  gap: 10px;
  align-items: center;
  flex-wrap: wrap;
}

.search { flex: 1; min-width: 200px; }

.brand-group { margin-bottom: 32px; }

.brand-group h3 {
  font-size: 12px;
  font-weight: 600;
  margin-bottom: 8px;
  padding: 6px 12px;
  background: #eef2ff;
  border-radius: 6px;
  color: #4f7ef8;
  letter-spacing: 0.5px;
  text-transform: uppercase;
}

table { width: 100%; border-collapse: collapse; font-size: 14px; }
th {
  text-align: left;
  padding: 10px 12px;
  background: #f8fafc;
  border-bottom: 2px solid #e5e9f0;
  font-weight: 600;
  color: #6b7280;
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
td { padding: 9px 12px; border-bottom: 1px solid #f0f4f8; color: #1a1a2e; }
tr:hover td { background: #f8fafc; }
CSSEOF

# Build React and copy to web dir with correct permissions
sudo -u ec2-user npm run build
cp -r $APP_DIR/frontend/dist/* $WEB_DIR/
chown -R nginx:nginx $WEB_DIR
chmod -R 755 $WEB_DIR

# =============================================================================
# Nginx — HTTP only first (no SSL until certbot runs)
# =============================================================================
cat > /etc/nginx/conf.d/products-app.conf << NGINXEOF
server {
    listen 80;
    server_name $DOMAIN;

    root $WEB_DIR;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://localhost:$APP_PORT/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
NGINXEOF

rm -f /etc/nginx/conf.d/default.conf

# =============================================================================
# Systemd Service for Node API
# =============================================================================
cat > /etc/systemd/system/products-api.service << SERVICEEOF
[Unit]
Description=Products API
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=$APP_DIR/backend
ExecStart=/usr/bin/node index.js
Restart=on-failure
Environment=APP_PORT=$APP_PORT
Environment=ENVIRONMENT=$ENVIRONMENT
Environment=AWS_REGION=$AWS_REGION

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable products-api
systemctl start products-api

# =============================================================================
# Start Nginx on HTTP then issue SSL cert
# =============================================================================
systemctl enable nginx
systemctl start nginx

sleep 5

certbot --nginx -d $DOMAIN \
  --non-interactive \
  --agree-tos \
  -m admin@seshproducts.com \
  --redirect && echo "SSL cert issued successfully" || echo "SSL cert failed — DNS may not be propagated yet"

systemctl enable certbot-renew.timer
systemctl start certbot-renew.timer