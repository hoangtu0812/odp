select
    md5(equipment_code) as equipment_key,
    equipment_code
from {{ ref('stg_maximo_workorder') }}
where equipment_code is not null
group by equipment_code
