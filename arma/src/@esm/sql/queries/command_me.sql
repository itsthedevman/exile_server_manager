SELECT
    a.locker,
    a.score,
    a.name,
    p.money,
    p.damage,
    p.hunger,
    p.thirst,
    a.kills,
    a.deaths,
    (
        SELECT
            CONCAT(
                "[",
                GROUP_CONCAT(
                    JSON_OBJECT("id", CONVERT(id, char), "name", name) SEPARATOR ", "
                ),
                "]"
            )
        FROM
            territory
        WHERE
            deleted_at IS NULL
            AND (
                owner_uid = :player_uid
                OR build_rights LIKE :wildcard_uid
                OR moderators LIKE :wildcard_uid
            )
    ) as territories
FROM
    account a
    LEFT JOIN player p ON p.account_uid = a.uid
WHERE
    a.uid = :player_uid
