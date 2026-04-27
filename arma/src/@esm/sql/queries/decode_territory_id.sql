SELECT
    id
FROM
    territory
WHERE
    esm_custom_id = :custom_id
ORDER BY
    esm_custom_id
