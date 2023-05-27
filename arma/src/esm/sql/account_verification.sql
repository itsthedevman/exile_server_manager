SELECT
    CASE
        WHEN EXISTS(
            SELECT
                uid
            FROM
                account
            WHERE
                uid = :uid
        ) THEN 'true'
        ELSE 'false'
    END
