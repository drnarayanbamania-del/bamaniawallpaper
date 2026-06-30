// YBT Wallpaper — Auth Routes + Middleware
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const config = require('./config');
const { queryAll, queryGet, queryRun } = require('./db');

const router = express.Router();

// ── Register ────────────────────────────────────────
router.post('/register', (req, res) => {
  try {
    const { name, email, password, confirm_password } = req.body;

    if (!name || !email || !password || !confirm_password) {
      return res.status(400).json({ error: 'All fields are required' });
    }

    if (password !== confirm_password) {
      return res.status(400).json({ error: 'Passwords do not match' });
    }

    if (password.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    const existing = queryGet('SELECT id FROM users WHERE email = ?', [email.toLowerCase()]);
    if (existing) {
      return res.status(409).json({ error: 'Email already registered' });
    }

    const hash = bcrypt.hashSync(password, 10);
    const result = queryRun(
      'INSERT INTO users (name, email, password) VALUES (?, ?, ?)',
      [name, email.toLowerCase(), hash]
    );

    const token = jwt.sign(
      { id: result.lastInsertRowid, role: 'user' },
      config.jwtSecret,
      { expiresIn: config.jwtExpiry }
    );

    res.status(201).json({
      message: 'Registration successful',
      token,
      user: { id: result.lastInsertRowid, name, email, role: 'user', is_pro: 0 },
    });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Login ───────────────────────────────────────────
router.post('/login', (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    const user = queryGet('SELECT * FROM users WHERE email = ?', [email.toLowerCase()]);

    if (!user || !bcrypt.compareSync(password, user.password)) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    if (!user.is_active) {
      return res.status(403).json({ error: 'Account has been deactivated' });
    }

    const token = jwt.sign(
      { id: user.id, role: user.role },
      config.jwtSecret,
      { expiresIn: config.jwtExpiry }
    );

    res.json({
      message: 'Login successful',
      token,
      user: { id: user.id, name: user.name, email: user.email, role: user.role, is_pro: user.is_pro },
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Me ──────────────────────────────────────────────
router.get('/me', authMiddleware, (req, res) => {
  try {
    const user = queryGet(
      'SELECT id, name, email, role, created_at, is_active, is_pro FROM users WHERE id = ?',
      [req.user.id]
    );

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ user });
  } catch (err) {
    console.error('Me error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Upgrade Current User to Pro ──────────────────────
router.post('/me/upgrade', authMiddleware, (req, res) => {
  try {
    queryRun('UPDATE users SET is_pro = 1 WHERE id = ?', [req.user.id]);
    res.json({ message: 'Upgraded to Pro successfully', is_pro: true });
  } catch (err) {
    console.error('Upgrade to Pro error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Auth Middleware ──────────────────────────────────
function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No token provided' });
  }

  try {
    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, config.jwtSecret);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

// ── Admin Middleware ────────────────────────────────
function adminMiddleware(req, res, next) {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
}

module.exports = { router, authMiddleware, adminMiddleware };
