#!/bin/sh


# fetch content for search index
# saves to result.json file
QUERY="\t on \pset format unaligned ${SQL_QUERY} SELECT json_agg(result) FROM result \g result.json"
RESULT=`psql $PSQL_CONNECTION_STRING -a "'${QUERY}'"`

# create new index 
MEILI_NEW_INDEX="${MEILI_INDEX}New"
curl \
  -X PATCH "https://${MEILI_HOST}/indexes" \
  -H "Authorization: Bearer ${MEILI_MASTER_KEY}" \
  -H 'Content-Type: application/json' \
  --data-binary '{
    "uid": "'$MEILI_NEW_INDEX'",
    "primaryKey": "id"
  }'

# update settings of new index
curl \
  -X PATCH "https://${MEILI_HOST}/indexes/${MEILI_NEW_INDEX}/settings" \
  -H "Authorization: Bearer ${MEILI_MASTER_KEY}" \
  -H 'Content-Type: application/json' \
  --data-binary '{
    "searchableAttributes": [
      "*"
    ],
    "filterableAttributes": [
      "company",
      "department",
      "location",
      "days"
    ],
    "sortableAttributes": [
      "days"
    ],
    "pagination": {
      "maxTotalHits": 10000
    }
  }'

# add results to new index
curl \
  -X POST "https://${MEILI_HOST}/indexes/${MEILI_NEW_INDEX}/documents" \
  -H "Authorization: Bearer ${MEILI_MASTER_KEY}" \
  -H 'Content-Type: application/json' \
  --data-binary @result.json

# swap current production index with new index
curl \
  -X POST "https://${MEILI_HOST}/swap-indexes" \
  -H "Authorization: Bearer ${MEILI_MASTER_KEY}" \
  -H 'Content-Type: application/json' \
  --data-binary '[
    {
      "indexes": [
        "'$MEILI_INDEX'",
        "'$MEILI_NEW_INDEX'"
      ]
    }
  ]'

# delete non-production index
curl \
  -X DELETE "https://${MEILI_HOST}/indexes/${MEILI_NEW_INDEX}" \
  -H "Authorization: Bearer ${MEILI_MASTER_KEY}" \

# delete result file
rm result.json