with source as (
    select * from {{ source('raw', 'maximo_workorder') }}
),

typed as (
    select
        source_key as work_order_key,
        trim(wo_number) as wo_number,
        nullif(trim(description), '') as description,
        upper(trim(status)) as status,
        upper(trim(area)) as area,
        upper(trim(equipment_code)) as equipment_code,
        upper(trim(department_code)) as department_code,
        upper(trim(site_id)) as site_id,
        reported_at::timestamp as reported_at,
        target_finish_at::timestamp as target_finish_at,
        actual_finish_at::timestamp as actual_finish_at,
        estimated_cost::numeric(18, 2) as estimated_cost,
        source_updated_at::timestamp as source_updated_at,
        ingested_at::timestamp as ingested_at
    from source
)

select * from typed
