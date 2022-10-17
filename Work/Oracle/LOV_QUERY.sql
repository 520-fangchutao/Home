--LOV_QUERY
select
    LISTAGG(t.sql_text) within group(
        order by
            t.piece
    )
from
    v$sqltext_with_newlines t,
    v$session s
where
    1 = 1
    and t.address = s.prev_sql_addr
    and s.sid = 2803;