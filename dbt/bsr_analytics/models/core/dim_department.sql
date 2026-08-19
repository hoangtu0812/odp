select
    md5(department_code) as department_key,
    department_code
from {{ ref('stg_maximo_workorder') }}
where department_code is not null
group by department_code
