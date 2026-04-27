SELECT
    t.id,
    t.owner_uid,
    a.name as owner_name,
    t.name as territory_name,
    t.radius,
    t.level,
    t.flag_texture,
    t.flag_stolen,
    CONVERT_TZ(t.last_paid_at, @@GLOBAL.time_zone, '+00:00') AS last_paid_at,
    t.build_rights,
    t.moderators,
    COALESCE(c.object_count, 0) as object_count,
    t.esm_custom_id
FROM
    territory t
    LEFT JOIN account a ON a.uid = t.owner_uid
    LEFT JOIN (
        SELECT
            territory_id,
            COUNT(*) as object_count
        FROM
            construction
        GROUP BY
            territory_id
    ) c ON c.territory_id = t.id
WHERE
    t.id = :territory_id
