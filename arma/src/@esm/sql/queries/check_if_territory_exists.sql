SELECT
    CASE
        WHEN EXISTS(
            SELECT
                id
            FROM
                territory
            WHERE
                id = :territory_id
        ) THEN 'true'
        ELSE 'false'
    END
