select
    reported_at::date as reported_date,
    area,
    status,
    count(*) as work_order_count,
    count(*) filter (where status = 'COMP') as completed_count,
    count(*) filter (where status = 'INPRG') as in_progress_count,
    count(*) filter (where is_overdue) as overdue_count,
    coalesce(sum(estimated_cost), 0)::numeric(18, 2) as estimated_cost_total
from {{ ref('fact_work_order') }}
group by 1, 2, 3
