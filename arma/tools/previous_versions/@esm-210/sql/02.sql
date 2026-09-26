-- Adds `xm8_notification` table.
-- This table stores all outbound XM8 notifications.
CREATE TABLE xm8_notification (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    uuid VARCHAR(36) NOT NULL,
    recipient_uid VARCHAR(32) NOT NULL,
    territory_id INT UNSIGNED,
    type VARCHAR(50) NOT NULL,
    content TEXT NOT NULL,
    state ENUM("new", "pending", "failed", "sent") NOT NULL DEFAULT "new",
    state_details TEXT,
    attempt_count INT DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_attempt_at DATETIME,
    acknowledged_at DATETIME,
    INDEX idx_recipient_uid (recipient_uid),
    INDEX idx_territory_id (territory_id),
    INDEX idx_last_attempt_acknowledged (last_attempt_at, acknowledged_at, attempt_count),
    CONSTRAINT fk_recipient_account FOREIGN KEY (recipient_uid) REFERENCES account (uid) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_territory FOREIGN KEY (territory_id) REFERENCES territory (id) ON DELETE SET NULL ON UPDATE CASCADE
) DEFAULT CHARSET = utf8mb4;
