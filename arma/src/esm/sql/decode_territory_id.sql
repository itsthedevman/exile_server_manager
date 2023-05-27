SELECT
    id
FROM
    territory
WHERE
    esm_custom_id = :territory_id
ORDER BY
    esm_custom_id
