SELECT
    CASE
        WHEN EXISTS(
            SELECT
                id
            FROM
                territory
            WHERE
                id = :territory_id
                AND owner_uid = :owner_uid
        ) THEN 'true'
        ELSE 'false'
    END
