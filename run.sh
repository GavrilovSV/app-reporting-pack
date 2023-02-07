# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#!/bin/bash
COLOR='\033[0;36m' # Cyan
NC='\033[0m' # No color

ads_config=/google-ads.yaml
reporting_pack_config=/app_reporting_pack.yaml

curl -s -H "X-Vault-Token: $VAULT_CLIENT_TOKEN" -H "Content-Type: application/json" -X GET "$VAULT_CLIENT_URI/v1/internal-tools/data/vizorlytics/application/$ENVIRONMENT" | jq -r '.data.data.'"\"$SERVICE_ACCOUNT_SECRET\"" > /actualizer_credentials.json

export GOOGLE_APPLICATION_CREDENTIALS=/actualizer_credentials.json

if [[ -z ${loglevel} ]]; then
	loglevel="INFO"
fi

# Результат сохраняем в BigQuery
output=bq
# Этот плейсхолдер будет соответствовать сегодняшней дате
end_date=:YYYYMMDD

api_version=$(cat $reporting_pack_config | shyaml get-value uac-report-pack.api-version)
accounts=$(cat $reporting_pack_config | shyaml get-values uac-report-pack.accounts)
start_date=$(cat $reporting_pack_config | shyaml get-value uac-report-pack.start-date)
cohort_days=$(cat $reporting_pack_config | shyaml get-value uac-report-pack.cohort-days)
dataset=$(cat $reporting_pack_config | shyaml get-value uac-report-pack.bq.intermediate-dataset)
project=$(cat $reporting_pack_config | shyaml get-value uac-report-pack.bq.project)
target_dataset=$(cat $reporting_pack_config | shyaml get-value uac-report-pack.bq.target-dataset)

while IFS= read -r account;
  do echo "Actualizing account $account"

  echo -e "${COLOR}===fetching reports===${NC}"
  gaarf google_ads_queries/**/*.sql --ads-config=$ads_config \
    --output=$output \
    --api_version=$api_version \
    --account=$account \
    --macro.start_date=$start_date \
    --macro.end_date=$end_date \
    --bq.project=$project \
    --bq.dataset=$dataset \
    --log=$loglevel

  echo -e "${COLOR}===calculating conversion lag adjustment===${NC}"
  $(which python3) /scripts/conv_lag_adjustment.py  --ads-config=$ads_config \
    --output=$output \
    --api_version=$api_version \
    --account=$account \
    --macro.start_date=$start_date \
    --macro.end_date=$end_date \
    --bq.project=$project \
    --bq.dataset=$dataset \
    --log=$loglevel

  echo -e "${COLOR}===generating snapshots===${NC}"
  gaarf-bq bq_queries/snapshots/*.sql --ads-config=$ads_config \
    --project=$project \
    --macro.bq_dataset=$dataset \
    --macro.start_date=$start_date \
    --macro.target_dataset=$target_dataset \
    --macro.account=$((account)) \
    --template.cohort_days=$cohort_days \
    --log=$loglevel

  echo -e "${COLOR}===generating views and functions===${NC}"
  gaarf-bq bq_queries/views_and_functions/*.sql --ads-config=$ads_config \
    --project=$project \
    --macro.bq_dataset=$dataset \
    --macro.start_date=$start_date \
    --macro.target_dataset=$target_dataset \
    --macro.account=$((account)) \
    --template.cohort_days=$cohort_days \
    --log=$loglevel

  echo -e "${COLOR}===saving results to target tables===${NC}"
  gaarf-bq bq_queries/asset_performance.sql \
    --project=$project \
    --macro.bq_dataset=$dataset \
    --macro.start_date=$start_date \
    --macro.target_dataset=$target_dataset \
    --macro.account=$((account)) \
    --template.cohort_days=$cohort_days \
    --log=$loglevel

  if [[ $legacy = "y" ]]; then
    echo -e "${COLOR}===generating legacy views===${NC}"
    gaarf-bq bq_queries/legacy_views/*.sql -c=$reporting_pack_config --log=$loglevel
  fi;
done <<< $(cat $reporting_pack_config | shyaml get-values uac-report-pack.accounts)
