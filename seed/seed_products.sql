-- Seed data for products table
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
