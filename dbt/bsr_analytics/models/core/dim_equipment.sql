select
    md5(concat_ws('|', site_id, equipment_code)) as equipment_key,
    site_id,
    equipment_code
from {{ ref('stg_maximo_workorder') }}
where equipment_code is not null
group by site_id, equipment_code
