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
                        'id', CONVERT(id, char),
                        'name', name,
                        'last_paid_at', last_paid_at,
                        'flag_texture', flag_texture,
                        'flag_stolen', flag_stolen
                    )
                )
            FROM
                territory
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
