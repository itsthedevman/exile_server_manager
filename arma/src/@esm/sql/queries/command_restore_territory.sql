UPDATE
    territory
SET
    deleted_at = NULL,
    xm8_protectionmoney_notified = 0,
    last_paid_at = NOW()
WHERE
    id = :territory_id;
