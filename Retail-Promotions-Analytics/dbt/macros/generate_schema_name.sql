{#
  Dev and prod are separate workspaces (separate wh_gold warehouses), so there is no need to prefix
  schemas per environment. Use the folder's custom schema as-is: staging, intermediate, marts.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
