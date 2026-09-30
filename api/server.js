const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Database connection
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'tutorial',
  password: process.env.DB_PASSWORD || 'tutorial_secret',
  database: process.env.DB_NAME || 'app_db',
});

// API v1: Get user profile (uses 'email' column)
// This will BREAK after V007 migration renames the column
app.get('/api/v1/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      'SELECT id, email, username, created_at FROM users WHERE id = $1',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({
      success: true,
      version: 'v1',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error fetching user (v1):', error.message);
    res.status(500).json({ error: 'Internal server error - column may not exist' });
  }
});

// Get all users (v1)
app.get('/api/v1/users', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, email, username, created_at FROM users ORDER BY id LIMIT 10'
    );

    res.json({
      success: true,
      version: 'v1',
      count: result.rows.length,
      data: result.rows
    });
  } catch (error) {
    console.error('Error fetching users (v1):', error.message);
    res.status(500).json({ error: 'Internal server error - column may not exist' });
  }
});

// API v2: Get user profile (uses 'email_address' column)
// This will WORK after V007 migration
app.get('/api/v2/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      'SELECT id, email_address, username, created_at FROM users WHERE id = $1',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({
      success: true,
      version: 'v2',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error fetching user (v2):', error.message);
    res.status(500).json({ error: 'Internal server error - column may not exist' });
  }
});

// Get all users (v2)
app.get('/api/v2/users', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, email_address, username, created_at FROM users ORDER BY id LIMIT 10'
    );

    res.json({
      success: true,
      version: 'v2',
      count: result.rows.length,
      data: result.rows
    });
  } catch (error) {
    console.error('Error fetching users (v2):', error.message);
    res.status(500).json({ error: 'Internal server error - column may not exist' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`API server running on http://localhost:${PORT}`);
  console.log(`  v1: /api/v1/users (uses 'email' column)`);
  console.log(`  v2: /api/v2/users (uses 'email_address' column)`);
});
