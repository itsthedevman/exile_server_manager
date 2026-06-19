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
                        'object_count', COUNT(c.id) as object_count
                    )
                )
            FROM
                territory t
            LEFT JOIN construction ON t.id = c.territory_id
            WHERE
                deleted_at IS NULL
                AND (
                    owner_uid = a.uid
                    OR build_rights LIKE CONCAT('%', a.uid, '%')
                    OR moderators LIKE CONCAT('%', a.uid, '%')
                )
        ),
        JSON_ARRAY()
    ) as territories
FROM
    account a
    LEFT JOIN player p ON a.uid = p.account_uid
WHERE
    a.uid = :player_uid;
