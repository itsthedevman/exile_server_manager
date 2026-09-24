UPDATE
    xm8_notification
SET
    state = "pending",
    state_details = "attempting delivery",
    attempt_count = attempt_count + 1,
    last_attempt_at = CURRENT_TIME()
WHERE
    uuid IN (:uuids);
