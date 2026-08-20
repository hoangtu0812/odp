select
    md5(concat_ws('|', site_id, department_code)) as department_key,
    site_id,
    department_code
from {{ ref('stg_maximo_workorder') }}
where department_code is not null
group by site_id, department_code
