-- Seed data for orders table
INSERT INTO orders (user_id, total, status) VALUES
  (1, 1329.98, 'completed'),
  (2, 479.98, 'completed'),
  (3, 129.99, 'pending'),
  (1, 89.99, 'shipped'),
  (4, 229.98, 'completed'),
  (5, 1299.99, 'cancelled'),
  (6, 179.98, 'pending'),
  (7, 529.98, 'shipped'),
  (8, 49.99, 'completed'),
  (9, 319.98, 'completed'),
  (10, 1499.98, 'pending'),
  (2, 89.99, 'shipped'),
  (3, 449.99, 'completed'),
  (4, 69.98, 'completed'),
  (1, 199.99, 'pending')
ON CONFLICT DO NOTHING;
