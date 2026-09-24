SELECT
    CONCAT('["', GROUP_CONCAT(DISTINCT uuid SEPARATOR '","'), '"]') as uuids,
    CONCAT('["', GROUP_CONCAT(DISTINCT recipient_uid SEPARATOR '","'), '"]') as recipient_uids,
    type,
    content,
    MIN(created_at) as created_at
FROM
    xm8_notification
WHERE
    acknowledged_at IS NULL
    AND (
        last_attempt_at IS NULL
        OR last_attempt_at < DATE_SUB(NOW(), INTERVAL 30 SECOND)
    )
    AND attempt_count < 10
GROUP BY
    territory_id, type, content
ORDER BY
    MIN(created_at) ASC
LIMIT
    100;
