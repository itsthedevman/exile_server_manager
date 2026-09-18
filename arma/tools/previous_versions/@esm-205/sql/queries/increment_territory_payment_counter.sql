UPDATE
    territory
SET
    esm_payment_counter = esm_payment_counter + 1
WHERE
    id = :territory_id
