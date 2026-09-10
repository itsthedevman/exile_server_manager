-- vehicle_count deliberately does not filter on deleted_at. Exile loads a garage with
-- `SELECT class, nickname FROM vehicle WHERE territory_id = ?` and enforces capacity against that count.
SELECT
    t.id,
    t.esm_custom_id,
    t.name AS territory_name,
    t.level,
    (
        SELECT
            COUNT(*)
        FROM
            vehicle v
        WHERE
            v.territory_id = t.id
    ) AS vehicle_count
FROM
    territory t
WHERE
    t.deleted_at IS NULL
    AND (
        t.owner_uid = :player_uid
        OR t.build_rights LIKE :wildcard_uid
        OR t.moderators LIKE :wildcard_uid
    )
ORDER BY
    t.name
