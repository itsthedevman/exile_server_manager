SELECT
    territory.id,
    territory.owner_uid,
    account.name AS owner_name,
    territory.name AS territory_name,
    territory.radius,
    territory.level,
    territory.flag_texture,
    territory.flag_stolen,
    CONVERT_TZ(
        territory.last_paid_at,
        @@GLOBAL.time_zone,
        '+00:00'
    ) AS last_paid_at,
    territory.build_rights,
    territory.moderators,
    COUNT(construction.id) AS object_count,
    territory.esm_custom_id
FROM
    territory
    LEFT JOIN account ON territory.owner_uid = account.uid
    LEFT JOIN construction ON territory.id = construction.territory_id
WHERE
    territory.deleted_at IS NULL
    AND (
        territory.owner_uid = :player_uid
        OR territory.build_rights LIKE :wildcard_uid
        OR territory.moderators LIKE :wildcard_uid
    )
GROUP BY
    territory.id
