#!/bin/bash
setup() {
	echo "Welcome to installation of App Reporting Pack"
	echo -n "Enter account_id: "
	read -r CUSTOMER_ID
	echo -n "Enter BigQuery project_id: "
	read -r project
	echo -n "Enter BigQuery dataset: "
	read -r bq_dataset
	echo -n "Enter start_date in YYYY-MM-DD format: "
	read -r start_date
	echo -n "Enter end_date in YYYY-MM-DD format: "
	read -r end_date
	ask_for_cohorts
	echo  "Script are expecting google-ads.yaml file in your home directory"
	echo -n "Is the file there (Y/n): "
	read -r ads_config_answer
	if [[ $ads_config_answer = "Y" ]]; then
		ads_config=$HOME/google-ads.yaml
	else
		echo -n "Enter full path to google-ads.yaml file: "
		read -r ads_config
	fi

}

deploy() {
	echo -n "Deploy App Reporting Pack? Y/n/q: "
	read -r answer

	if [[ $answer = "Y" ]]; then
		echo "Deploying..."
	elif [[ $answer = "q" ]]; then
		exit 1
	else
		setup
	fi
}

ask_for_cohorts() {
	echo -n "Asset performance can have cohorts. Enter Y if you want to activate: "
	read -r cohorts_answer
	if [[ $cohorts_answer = "Y" ]]; then
		echo -n "Please enter cohort number in the following format 1,2,3,4,5: "
		read -r cohorts
	fi
}
generate_parameters() {
	bq_dataset_output=$(echo $bq_dataset"_output")
	bq_dataset_legacy=$(echo $bq_dataset"_legacy")
	macros="--macro.bq_project=$project --macro.bq_dataset=$bq_dataset --macro.target_dataset=$bq_dataset_output --macro.legacy_dataset=$bq_dataset_legacy --template.cohort_days=$cohorts"
}


fetch_reports() {
	echo "===fetching reports==="
	gaarf google_ads_queries/*/*.sql \
	--account=$CUSTOMER_ID \
	--output=bq \
	--bq.project=$project --bq.dataset=$bq_dataset \
	--macro.start_date=$start_date --macro.end_date=$end_date \
	--ads-config=$ads_config

}

generate_bq_views() {
	echo "===generating views and functions==="
	gaarf-bq bq_queries/views_and_functions/*.sql \
		--project=$project --target=$bq_dataset $macros
}


generate_snapshots() {
	echo "===generating snapshots==="
	gaarf-bq bq_queries/snapshots/*.sql \
		--project=$project --target=$bq_dataset $macros
}

generate_output_tables() {
	echo "===generating final tables==="
	gaarf-bq bq_queries/*.sql \
		--project=$project --target=$bq_dataset $macros
}

generate_legacy_views() {
	echo "===generating legacy views==="
	gaarf-bq bq_queries/legacy_views/*.sql \
		--project=$project --target=$bq_dataset $macros
}

print_configuration() {
	echo "Your configuration:"
	echo "account_id: $CUSTOMER_ID"
	echo "BigQuery project_id: $project"
	echo "BigQuery dataset:: $bq_dataset"
	echo "Start date: $start_date"
	echo "End date: $end_date"
	echo "Ads config: $ads_config"
	echo "Cohorts: $cohorts"
}

setup
print_configuration
deploy
generate_parameters
fetch_reports
generate_bq_views
generate_snapshots
generate_output_tables
generate_legacy_views