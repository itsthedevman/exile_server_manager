SELECT
    a.uid,
    a.locker,
    a.score,
    a.name,
    a.kills,
    a.deaths,
    a.first_connect_at,
    a.last_disconnect_at,
    a.total_connections,
    p.money,
    p.damage,
    p.hunger,
    p.thirst,
    COALESCE(
        (
            SELECT
                JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'id', CONVERT(t.id, char),
                        'esm_custom_id', t.esm_custom_id,
                        'name', t.name,
                        'last_paid_at', t.last_paid_at,
                        'flag_texture', t.flag_texture,
                        'flag_stolen', t.flag_stolen,
                        'level', t.level,
                        'object_count', COALESCE(c.object_count, 0)
                    )
                )
            FROM
                territory t
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
                t.deleted_at IS NULL
                AND (
                    t.owner_uid = a.uid
                    OR t.build_rights LIKE CONCAT('%', a.uid, '%')
                    OR t.moderators LIKE CONCAT('%', a.uid, '%')
                )
        ),
        JSON_ARRAY()
    ) as territories
FROM
    account a
    LEFT JOIN player p ON a.uid = p.account_uid
WHERE
    a.uid = :player_uid;
