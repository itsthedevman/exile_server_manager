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
                    JSON_OBJECT("id", id, "name", name) SEPARATOR ", "
                ),
                "]"
            )
        FROM
            territory
        WHERE
            deleted_at IS NULL
            AND (
                owner_uid = :uid
                OR build_rights LIKE :uid_wildcard
                OR moderators LIKE :uid_wildcard
            )
    ) as territories
FROM
    account a
    LEFT JOIN player p ON p.account_uid = a.uid
WHERE
    a.uid = :uid
