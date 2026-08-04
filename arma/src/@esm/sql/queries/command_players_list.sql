SELECT
    a.uid,
    a.name,
    a.locker,
    a.score,
    a.kills,
    a.deaths,
    a.first_connect_at,
    a.last_connect_at,
    a.last_disconnect_at,
    a.total_connections,
    p.money,
    (
        a.last_disconnect_at IS NULL
        OR a.last_connect_at > a.last_disconnect_at
    ) AS online
FROM
    account a
    LEFT JOIN player p ON a.uid = p.account_uid
WHERE
    a.last_connect_at >= :connected_since
ORDER BY
    online DESC,
    a.last_connect_at DESC
LIMIT
    :row_limit;
