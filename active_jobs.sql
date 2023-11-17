\t on
\pset format unaligned

WITH jobs_data AS (
    SELECT
        j.id,
        c.name AS company,
        c.slug AS company_slug,
        j.title,
        j.location AS job_location,
        COALESCE(json_agg(json_build_object('name', l.name)), '[]'::json) AS normalized_location,
        j.company_department,
        d.name AS department,
        j.active_days
    FROM
        core_job j
    LEFT JOIN
        core_company c ON j.company_id = c.id
    LEFT JOIN
        core_locationmapping_normalized lm ON j.normalized_location_id = lm.locationmapping_id
    LEFT JOIN
        core_location l ON lm.location_id = l.id
    LEFT JOIN
        core_departmentmapping dm ON j.normalized_department_id = dm.id
    LEFT JOIN
        core_department d ON dm.normalized_id = d.id
    WHERE j.active = true
    GROUP BY
        j.id, c.name, c.slug, j.title, j.location, j.company_department, d.name, j.active_days
    ORDER BY
        j.id DESC
),
result AS (
    SELECT
        jd.id,
        jd.company,
        jd.title,
        jd.company_department,
        jd.department AS department,
        jd.active_days AS days,
        jd.company_slug,
        json_agg(json_array_elements.value -> 'name'::text) AS locations
    FROM
        jobs_data jd,
        LATERAL json_array_elements(jd.normalized_location) json_array_elements(value)
    GROUP BY
        jd.id, jd.company, jd.title, jd.company_department, jd.department, jd.active_days, jd.company_slug, jd.normalized_location::text
)

SELECT json_agg(result)
FROM result \g result.json