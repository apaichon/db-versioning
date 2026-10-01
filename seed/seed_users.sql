-- Seed data for users table (V001 schema only)
INSERT INTO users (email, username, password) VALUES
  ('john.doe@example.com', 'johndoe', 'hashed_pw_1'),
  ('jane.smith@example.com', 'janesmith', 'hashed_pw_2'),
  ('bob.wilson@example.com', 'bobwilson', 'hashed_pw_3'),
  ('alice.brown@example.com', 'alicebrown', 'hashed_pw_4'),
  ('charlie.davis@example.com', 'charlied', 'hashed_pw_5'),
  ('emma.garcia@example.com', 'emmag', 'hashed_pw_6'),
  ('michael.chen@example.com', 'michaelc', 'hashed_pw_7'),
  ('sarah.johnson@example.com', 'sarahj', 'hashed_pw_8'),
  ('david.lee@example.com', 'davidl', 'hashed_pw_9'),
  ('lisa.wang@example.com', 'lisaw', 'hashed_pw_10')
ON CONFLICT DO NOTHING;
