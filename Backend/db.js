// YBT Wallpaper — Database Connection + Schema Init (sql.js)
const initSqlJs = require('sql.js');
const fs = require('fs');
const bcrypt = require('bcryptjs');
const config = require('./config');

let db = null;
let dbReady = null;

function initDb() {
  if (dbReady) return dbReady;

  dbReady = (async () => {
    const SQL = await initSqlJs();

    // Load existing DB file if it exists
    if (fs.existsSync(config.dbPath)) {
      const buffer = fs.readFileSync(config.dbPath);
      db = new SQL.Database(buffer);
    } else {
      db = new SQL.Database();
    }

    db.run('PRAGMA foreign_keys = ON');
    initSchema();
    seedAdmin();
    saveDb();

    return db;
  })();

  return dbReady;
}

function getDb() {
  if (!db) throw new Error('Database not initialized. Call initDb() first.');
  return db;
}

function saveDb() {
  const data = db.export();
  const buffer = Buffer.from(data);
  fs.writeFileSync(config.dbPath, buffer);
}

function initSchema() {
  db.run(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      password TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'user',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      is_active BOOLEAN DEFAULT 1
    )
  `);

  db.run(`
    CREATE TABLE IF NOT EXISTS categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  db.run(`
    CREATE TABLE IF NOT EXISTS wallpapers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      file_name TEXT NOT NULL,
      category_id INTEGER NOT NULL,
      uploaded_by INTEGER NOT NULL,
      downloads INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      is_active BOOLEAN DEFAULT 1,
      FOREIGN KEY (category_id) REFERENCES categories(id),
      FOREIGN KEY (uploaded_by) REFERENCES users(id)
    )
  `);
}

function seedAdmin() {
  const stmt = db.prepare('SELECT id FROM users WHERE role = ?');
  stmt.bind(['admin']);
  const hasAdmin = stmt.step();
  stmt.free();

  if (!hasAdmin) {
    const hash = bcrypt.hashSync(config.adminPassword, 10);
    db.run(
      'INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)',
      ['Admin', config.adminEmail, hash, 'admin']
    );
    console.log(`Admin account created: ${config.adminEmail}`);
  }
}

// ── Query Helpers ───────────────────────────────────
// These provide a better-sqlite3-like API on top of sql.js

function queryAll(sql, params = []) {
  const stmt = db.prepare(sql);
  if (params.length) stmt.bind(params);

  const results = [];
  while (stmt.step()) {
    results.push(stmt.getAsObject());
  }
  stmt.free();
  return results;
}

function queryGet(sql, params = []) {
  const stmt = db.prepare(sql);
  if (params.length) stmt.bind(params);

  let result = null;
  if (stmt.step()) {
    result = stmt.getAsObject();
  }
  stmt.free();
  return result;
}

function queryRun(sql, params = []) {
  db.run(sql, params);
  saveDb();
  const lastId = db.exec('SELECT last_insert_rowid() as id')[0];
  const changes = db.getRowsModified();
  return {
    lastInsertRowid: lastId ? lastId.values[0][0] : 0,
    changes,
  };
}

module.exports = { initDb, getDb, saveDb, queryAll, queryGet, queryRun };
