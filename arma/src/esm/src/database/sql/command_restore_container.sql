UPDATE
    container
SET
    deleted_at = NULL
WHERE
    territory_id = :territory_id;
