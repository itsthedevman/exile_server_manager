SELECT
    CONVERT(t.id, char) as id,
    t.esm_custom_id,
    t.name,
    t.owner_uid,
    a.name as owner_name,
    t.level,
    COALESCE(c.object_count, 0) as object_count,
    CONVERT_TZ(t.last_paid_at, @@GLOBAL.time_zone, '+00:00') AS last_paid_at,
    t.flag_stolen,
    CONVERT_TZ(t.deleted_at, @@GLOBAL.time_zone, '+00:00') AS deleted_at
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
