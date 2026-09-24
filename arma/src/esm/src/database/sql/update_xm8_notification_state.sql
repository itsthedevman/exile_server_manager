UPDATE
    xm8_notification
SET
    state = :state,
    state_details = :state_details,
    acknowledged_at = CURRENT_TIME()
WHERE
    uuid = :uuid;
