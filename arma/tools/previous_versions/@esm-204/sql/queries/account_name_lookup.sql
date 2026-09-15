SELECT
    uid,
    name
FROM
    account
WHERE
    uid IN (:uids);
