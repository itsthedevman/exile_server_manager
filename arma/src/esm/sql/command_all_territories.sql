SELECT
    CONVERT(t.id, char) as id,
    t.esm_custom_id,
    t.name,
    t.owner_uid,
    a.name as owner_name
FROM
    territory t
    INNER JOIN account a ON a.uid = t.owner_uid
