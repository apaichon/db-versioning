-- Seed data for users, products, and orders
-- Run: make seed

BEGIN;

-- Insert sample users
INSERT INTO users (email, username, password, first_name, last_name, phone, is_active) VALUES
  ('john.doe@example.com', 'johndoe', 'hashed_pw_1', 'John', 'Doe', '+1234567890', true),
  ('jane.smith@example.com', 'janesmith', 'hashed_pw_2', 'Jane', 'Smith', '+0987654321', true),
  ('bob.wilson@example.com', 'bobwilson', 'hashed_pw_3', 'Bob', 'Wilson', '+1122334455', true),
  ('alice.brown@example.com', 'alicebrown', 'hashed_pw_4', 'Alice', 'Brown', '+5544332211', true),
  ('charlie.davis@example.com', 'charlied', 'hashed_pw_5', 'Charlie', 'Davis', '+6677889900', false),
  ('emma.garcia@example.com', 'emmag', 'hashed_pw_6', 'Emma', 'Garcia', '+9988776655', true),
  ('michael.chen@example.com', 'michaelc', 'hashed_pw_7', 'Michael', 'Chen', '+1231231234', true),
  ('sarah.johnson@example.com', 'sarahj', 'hashed_pw_8', 'Sarah', 'Johnson', '+3213214321', true),
  ('david.lee@example.com', 'davidl', 'hashed_pw_9', 'David', 'Lee', '+4564564567', true),
  ('lisa.wang@example.com', 'lisaw', 'hashed_pw_10', 'Lisa', 'Wang', '+7897897890', true)
ON CONFLICT DO NOTHING;

-- Insert sample products
INSERT INTO products (name, description, price, stock) VALUES
  ('Laptop Pro 15', 'High-performance laptop with 15-inch display', 1299.99, 50),
  ('Wireless Mouse', 'Ergonomic wireless mouse with USB receiver', 29.99, 200),
  ('Mechanical Keyboard', 'RGB mechanical keyboard with blue switches', 89.99, 150),
  ('Monitor 27"', '4K IPS monitor with HDR support', 449.99, 75),
  ('USB-C Hub', '7-in-1 USB-C hub with HDMI and ethernet', 49.99, 300),
  ('Webcam HD', '1080p webcam with built-in microphone', 79.99, 120),
  ('Headphones', 'Noise-cancelling over-ear headphones', 199.99, 90),
  ('External SSD 1TB', 'Portable SSD with USB 3.2', 129.99, 180),
  ('Desk Lamp', 'LED desk lamp with adjustable brightness', 39.99, 250),
  ('Mouse Pad XL', 'Extended mouse pad with stitched edges', 19.99, 400)
ON CONFLICT DO NOTHING;

-- Insert sample orders
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

-- Insert sample order items
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
  (1, 1, 1, 1299.99),
  (1, 2, 1, 29.99),
  (2, 4, 1, 449.99),
  (2, 5, 1, 49.99),
  (3, 8, 1, 129.99),
  (4, 3, 1, 89.99),
  (5, 7, 1, 199.99),
  (5, 2, 1, 29.99),
  (6, 1, 1, 1299.99),
  (7, 6, 1, 79.99),
  (7, 10, 1, 19.99),
  (8, 4, 1, 449.99),
  (8, 3, 1, 89.99),
  (9, 5, 1, 49.99),
  (10, 7, 1, 199.99),
  (10, 8, 1, 129.99),
  (11, 1, 1, 1299.99),
  (11, 9, 1, 39.99),
  (12, 3, 1, 89.99),
  (13, 4, 1, 449.99),
  (14, 2, 1, 29.99),
  (14, 5, 1, 49.99),
  (15, 7, 1, 199.99)
ON CONFLICT DO NOTHING;

COMMIT;
