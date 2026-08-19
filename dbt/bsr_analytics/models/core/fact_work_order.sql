select
    wo.wo_number,
    wo.description,
    wo.status,
    wo.area,
    equipment.equipment_key,
    department.department_key,
    wo.reported_at,
    wo.target_finish_at,
    wo.actual_finish_at,
    wo.estimated_cost,
    case
        when wo.status not in ('COMP', 'CAN')
            and wo.actual_finish_at is null
            and wo.target_finish_at < current_timestamp then true
        else false
    end as is_overdue
from {{ ref('stg_maximo_workorder') }} as wo
left join {{ ref('dim_equipment') }} as equipment
    on wo.equipment_code = equipment.equipment_code
left join {{ ref('dim_department') }} as department
    on wo.department_code = department.department_code
