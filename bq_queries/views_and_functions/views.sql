-- Represents basic app campaign settings that are used when creating
-- final tables for dashboards
CREATE OR REPLACE VIEW `{bq_project}.{target_dataset}.AppCampaignSettingsView`
AS (
    SELECT
        campaign_id,
        campaign_sub_type,
        app_id,
        app_store,
        bidding_strategy,
        start_date,
        ARRAY_TO_STRING(ARRAY_AGG(DISTINCT conversion_source ORDER BY conversion_source), "|") AS conversion_sources,
        ARRAY_TO_STRING(ARRAY_AGG(DISTINCT conversion_name ORDER BY conversion_name), " | ") AS target_conversions,
        COUNT(DISTINCT conversion_name) AS n_of_target_conversions
    FROM {bq_project}.{bq_dataset}.app_campaign_settings
    GROUP BY 1, 2, 3, 4, 5, 6
);

-- Campaign level geo and language targeting
CREATE OR REPLACE VIEW `{bq_project}.{target_dataset}.GeoLanguageView` AS (
    SELECT
        COALESCE(CampaignGeoTarget.campaign_id, CampaignLanguages.campaign_id) AS campaign_id,
        ARRAY_TO_STRING(ARRAY_AGG(DISTINCT country_code ORDER BY country_code), " | ") AS geos,
        ARRAY_TO_STRING(ARRAY_AGG(DISTINCT language ORDER BY language), " | ") AS languages
    FROM {bq_project}.{bq_dataset}.campaign_geo_targets AS CampaignGeoTarget
    LEFT JOIN {bq_project}.{bq_dataset}.geo_target_constant AS GeoTargetConstant
        ON CampaignGeoTarget.geo_target = CAST(GeoTargetConstant.constant_id AS STRING)
    FULL JOIN {bq_project}.{bq_dataset}.campaign_languages AS CampaignLanguages
        ON CampaignGeoTarget.campaign_id = CampaignLanguages.campaign_id
    GROUP BY 1
);
