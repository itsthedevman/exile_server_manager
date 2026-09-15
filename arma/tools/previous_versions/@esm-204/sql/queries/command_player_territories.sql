SELECT
    t.id,
    t.owner_uid,
    a.name as owner_name,
    t.name as territory_name,
    t.radius,
    t.level,
    t.flag_texture,
    t.flag_stolen,
    CONVERT_TZ(t.last_paid_at, @@GLOBAL.time_zone, '+00:00') as last_paid_at,
    t.build_rights,
    t.moderators,
    COUNT(c.id) as object_count,
    t.esm_custom_id
FROM
    territory t
    LEFT JOIN account a ON t.owner_uid = a.uid
    LEFT JOIN construction c ON t.id = c.territory_id
WHERE
    t.deleted_at IS NULL
    AND (
        t.owner_uid = :player_uid
        OR t.build_rights LIKE :wildcard_uid
        OR t.moderators LIKE :wildcard_uid
    )
GROUP BY
    t.id
