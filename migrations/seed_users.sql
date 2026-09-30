-- Seed data for users table
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
