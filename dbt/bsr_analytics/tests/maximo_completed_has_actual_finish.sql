select *
from {{ ref('fact_work_order') }}
where status in ('COMP', 'CLOSE')
  and actual_finish_at is null
