-- MySQL initialization script for SpeakUp
-- Database & user are auto-created by environment variables
-- This script runs additional grants

GRANT ALL PRIVILEGES ON db_speakup.* TO 'speakup_user'@'%';
FLUSH PRIVILEGES;
