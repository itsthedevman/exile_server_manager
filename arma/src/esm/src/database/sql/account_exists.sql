-- Whether this server has ever seen the player, which is the account row Exile writes on their first
-- connect. A row here says they have joined; no row says they have not.
SELECT
    uid
FROM
    account
WHERE
    uid = :uid;
