// YBT Wallpaper — User Management Routes (Admin only)
const express = require('express');
const { queryAll, queryGet, queryRun } = require('./db');
const { authMiddleware, adminMiddleware } = require('./auth');

const router = express.Router();

// ── List all users (admin) ──────────────────────────
router.get('/', authMiddleware, adminMiddleware, (req, res) => {
  try {
    const users = queryAll(
      'SELECT id, name, email, role, created_at, is_active, is_pro FROM users ORDER BY created_at DESC'
    );

    res.json({ users });
  } catch (err) {
    console.error('List users error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Toggle user active status (admin) ───────────────
router.patch('/:id/toggle', authMiddleware, adminMiddleware, (req, res) => {
  try {
    const user = queryGet('SELECT id, role, is_active FROM users WHERE id = ?', [parseInt(req.params.id)]);

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (user.role === 'admin') {
      return res.status(400).json({ error: 'Cannot deactivate admin accounts' });
    }

    const newStatus = user.is_active ? 0 : 1;
    queryRun('UPDATE users SET is_active = ? WHERE id = ?', [newStatus, parseInt(req.params.id)]);

    res.json({
      message: `User ${newStatus ? 'activated' : 'deactivated'}`,
      is_active: !!newStatus,
    });
  } catch (err) {
    console.error('Toggle user error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Delete user (admin) ─────────────────────────────
router.delete('/:id', authMiddleware, adminMiddleware, (req, res) => {
  try {
    const user = queryGet('SELECT id, role FROM users WHERE id = ?', [parseInt(req.params.id)]);

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (user.role === 'admin') {
      return res.status(400).json({ error: 'Cannot delete admin accounts' });
    }

    queryRun('DELETE FROM users WHERE id = ?', [parseInt(req.params.id)]);
    res.json({ message: 'User deleted' });
  } catch (err) {
    console.error('Delete user error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Toggle user Pro status (admin) ──────────────────
router.patch('/:id/toggle-pro', authMiddleware, adminMiddleware, (req, res) => {
  try {
    const user = queryGet('SELECT id, role, is_pro FROM users WHERE id = ?', [parseInt(req.params.id)]);

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const newProStatus = user.is_pro ? 0 : 1;
    queryRun('UPDATE users SET is_pro = ? WHERE id = ?', [newProStatus, parseInt(req.params.id)]);

    res.json({
      message: `User Pro status set to ${newProStatus ? 'Active' : 'Inactive'}`,
      is_pro: !!newProStatus,
    });
  } catch (err) {
    console.error('Toggle user Pro error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
