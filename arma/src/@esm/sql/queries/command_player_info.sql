SELECT
    a.uid,
    a.locker,
    a.score,
    a.name,
    a.kills,
    a.deaths,
    p.money,
    p.damage,
    p.hunger,
    p.thirst,
    COALESCE(
        (
            SELECT
                JSON_ARRAYAGG(JSON_OBJECT('id', id, 'name', name))
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
