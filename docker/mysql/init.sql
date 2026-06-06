-- MySQL initialization script for SpeakUp
-- This runs when the container is first created

-- Ensure proper character set
ALTER DATABASE IF EXISTS db_speakup CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Grant privileges
GRANT ALL PRIVILEGES ON db_speakup.* TO 'speakup_user'@'%';
FLUSH PRIVILEGES;
