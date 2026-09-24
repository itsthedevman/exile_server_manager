-- Paired with command_players_recently_connected.sql: both feed the same Account struct in
-- command_players_list.rs, so a column added here has to be added there and to the struct.
--
-- No window constraint. Reaching past the recency cutoff is the entire point of a name search: the
-- player being looked up is usually one who stopped showing up in the listing.
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
    p.damage,
    (
        a.last_disconnect_at IS NULL
        OR a.last_connect_at > a.last_disconnect_at
    ) AS online
FROM
    account a
    LEFT JOIN player p ON a.uid = p.account_uid
WHERE
    a.name LIKE CONCAT('%', :name, '%')
ORDER BY
    online DESC,
    a.last_connect_at DESC
LIMIT
    :row_limit;
