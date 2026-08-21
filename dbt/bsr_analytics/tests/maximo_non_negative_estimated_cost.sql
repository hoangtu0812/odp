select *
from {{ ref('fact_work_order') }}
where estimated_cost < 0
