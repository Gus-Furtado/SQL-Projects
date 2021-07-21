---------------------------------------------------------------------------------------------------
/*
READ ME:

 Goal for this query:
    Integrate into 1 query YTD data of Digital Advertising Campaigns run by one client 
    and its brands.
 
 What problem are we trying to solve?
    Currently, people have to manually download data across 3 or more sources of 
    digital advertising (DSP - Demand Side Platform) and combine all the data into 
    one excel file to create a report. Also, this report has no connection 
    with the Finance system which control all the digital advertising bookings and
    approvals. 
 
 Main Challenges: 
    1-This query is based on a star schema starting from DSP metrics, which already 
    contain the fact table of all DSPs, except for 1 metric from YouTube which sits 
    in another DSP fact table, thus the need to use union all.
    2-The Finance system not always has a connection with the DSP meta table even 
    though that should be the best practice. To overcome this I used inner query 
    within some left joins as the main priority is to showcase what advertising campaign 
    has run regardless with the 'connection with Finance system is not in place. 
    Most often that is because a different id was assigned. 
  
 Results:
    Now the analysts can quick query the results and focus on the visualizations
    and analysis rather than building the database in excel, which has roughly 
    gave a half day back in the diary. 
        
*/
---------------------------------------------------------------------------------------------------
-- DSP
--- DSP - SELECT META (Campaing attribuites)
SELECT
    metrics.date AS date_,
    io.advertiser,
    io.finance_io_name,
    io.dsp_io_name,
    dsp_name.name AS dsp_name,
    io.finance_campaign_start_date,
    io.finance_campaign_end_date,
    line.name AS line_item,
    dsp_creative.name AS creative_name,
    dsp_creative.adserver_placement_id AS dsp_adsv_placid,
    ---- DSP - SELECT FACT (Agreegate functions for campaign metrics)
    SUM(metrics.impressions) AS impressions,
    SUM(metrics.clicks) AS clicks,
    0 AS "TRUEVIEW_VIEWS",
    SUM(metrics.first_quartile_views) AS "FIRST_QUARTILE_VIEWS",
    SUM(metrics.midpoint_views) AS "MIDPOINT_QUARTILE_VIEWS",
    SUM(metrics.third_quartile_views) AS "THIRD_QUARTILE_VIEWS",
    SUM(metrics.completed_views) AS completed_views,
    SUM(metrics.billablecost) AS dsp_billable_cost,
    0 AS view_conversions,
    0 AS click_conversions,
    0 AS tt_conversions 
--- DSP - FROM METRICS (Campaign Metrics)
/* This query is based on a star schema starting from the Metrics campaign */
FROM
    DATA_DSP.DSP_FACT_METRICS metrics --- DSP - FROM LINE ITEM (Advertising Strategies)
/* Advertising Campaign Strategies within each DSP */
    INNER JOIN DSAF.DATA_DSP.DSP_META_LINEITEM line on metrics.concatlineitem_id = line.concat_id 
--- DSP - FROM DSP NAME (DSP Names)
/* DSP actual name */
    LEFT JOIN DSAF.DATA_DSP.DSP_META_DSP dsp_name on metrics.dsp_id = dsp_name.id 
--- FINANCE - FROM  ADVERTISER & IO CAMPAIGN (ERP/Finance system)
/* Joining meta data from our ERP/Finance system. Each advertising campaign within DSPs
needs to be related to a campaign in the ERP system in each among other functions is used
for manage approved and billed campaigns */
    INNER JOIN (
        SELECT
            advertiser.name advertiser,
            camp.name finance_io_name,
            io.name dsp_io_Name,
            camp.start_date finance_campaign_start_date,
            camp.end_date finance_campaign_end_date,
            io.id
        FROM
            DSAF.DATA_DSP.DSP_META_INSERTIONORDER io
            LEFT JOIN data_finance.finance_meta_platform plat ON io.name = plat.campaing_name
            LEFT JOIN data_finance.finance_meta_campaign camp ON camp.id = plat.campaign_id
            LEFT JOIN data_finance.finance_meta_advertiser advertiser ON advertiser.id = camp.advertiser_id
            LEFT JOIN data_finance.finance_meta_io financeio on financeio.id = plat.io_id
            LEFT JOIN data_finance.finance_meta_dsp dsp on dsp.id = plat.dps_id
        GROUP BY
            advertiser.name,
            camp.name,
            io.name,
            camp.start_date,
            camp.end_date,
            io.id
    ) io ON metrics.insertionorder_id = io.id 
--- DSP - CREATIVE (Creative level campaign )
/* Creative level data */
    LEFT JOIN DSAF.DATA_DSP.DSP_META_CREATIVE dsp_creative ON metrics.concatcreative_id = dsp_creative.concat_id 
--- DSP - WHERE
/* This particular report was for a particular client brands and only for YTD data */
WHERE
    metrics.date >= '2021-01-01'
    AND io.advertiser IN (
        'Client XYZ - Brand One',
        'Client XYZ - Brand Two',
        'Client XYZ - Brand Three',
        'Client XYZ - Brand Four',
        'Client XYZ - Brand Five'
    ) 
--- DSP - GROUP BY
GROUP BY
    metrics.date,
    io.advertiser,
    io.finance_io_name,
    io.dsp_io_Name,
    dsp_name,
    io.finance_campaign_start_date,
    io.finance_campaign_end_date,
    line_item,
    creative_name,
    dsp_adsv_placid 
---------------------------------------------------------------------------------------------------
-- UNION ALL (2 fact table and all the meta tables) and YouTube True View Fact Table
/* The center of our schema is the Metrics table which already contain the data of 5 DSPs (5 
other metrics table combined), with the exception of 1 metric from YouTube each sits in another 
DSP fact table, thus the need to use  union all. */

UNION ALL

---------------------------------------------------------------------------------------------------

--- YOUTUBE - SELECT META (Campaing attribuites)
SELECT
    metrics.date AS date_,
    io.advertiser,
    io.finance_io_name,
    io.dsp_io_name,
    'DV360' AS dsp_name,
    io.finance_campaign_start_date,
    io.finance_campaign_end_date,
    line.name AS line_item,
    dsp_creative.name AS creative_name,
    dsp_creative.adserver_placement_id AS dsp_adsv_placid,
--- YOUTUBE - SELECT FACT (Agreegate functions for campaign metrics)
    0 AS impressions,
    0 AS clicks,
    SUM(metrics.trueview_views) AS "TRUEVIEW_VIEWS",
    0 AS "FIRST_QUARTILE_VIEWS",
    0 AS "MIDPOINT_QUARTILE_VIEWS",
    0 AS "THIRD_QUARTILE_VIEWS",
    0 AS completed_views,
    0 AS dsp_billable_cost,
    0 AS view_conversions,
    0 AS click_conversions,
    0 AS tt_conversions 
--- YOUTUBE - FROM METRICS (Campaign Metrics)
FROM
    DSAF.DATA_DBM.DBM_FACT_TRUEVIEW metrics 
--- YOUTUBE - FROM LINE ITEM (Advertising Strategies)
    INNER JOIN DSAF.DATA_DBM.DBM_META_LINEITEM line on metrics.lineitem_id = line.id 
--- FINANCE - FROM  ADVERTISER & IO CAMPAIGN (ERP/Finance system)
/* Joining meta data from our ERP/Finance system. Each advertising campaign within DSPs
needs to be related to a campaign in the ERP system in each among other functions is used
for manage approved and billed campaigns */
    INNER JOIN (
        SELECT
            advertiser.name advertiser,
            camp.name finance_io_name,
            io.name dsp_io_name,
            camp.start_date finance_campaign_start_date,
            camp.end_date finance_campaign_end_date,
            io.id
        FROM
            DSAF.DATA_DSP.DSP_META_INSERTIONORDER io
            LEFT JOIN data_finance.finance_meta_platform plat ON io.name = plat.campaing_name
            LEFT JOIN data_finance.finance_meta_campaign camp ON camp.id = plat.campaign_id
            LEFT JOIN data_finance.finance_meta_advertiser advertiser ON advertiser.id = camp.advertiser_id
            LEFT JOIN data_finance.finance_meta_io financeio on financeio.id = plat.io_id
            LEFT JOIN data_finance.finance_meta_dsp dsp on dsp.id = plat.dps_id
        GROUP BY
            advertiser.name,
            camp.name,
            io.name,
            camp.start_date,
            camp.end_date,
            io.id
    ) io ON metrics.insertionorder_id = io.id 
--- YOUTUBE - (Creative level campaign )
/* Creative level data */
    LEFT JOIN (
        SELECT
            id,
            name,
            ADSERVER_PLACEMENT_ID AS adserver_placement_id
        FROM
            DSAF.DATA_DBM.DBM_META_CREATIVE
    ) dsp_creative ON metrics.ad_id = dsp_creative.id 
--- YOUTUBE - WHERE
    /* This particular report was for a particular client brands and only for YTD data */
WHERE
    metrics.date >= '2021-01-01'
    AND io.advertiser IN (
        'Client XYZ - Brand One',
        'Client XYZ - Brand Two',
        'Client XYZ - Brand Three',
        'Client XYZ - Brand Four',
        'Client XYZ - Brand Five'
    ) 
--- YOUTUBE - GROUP BY
GROUP BY
    metrics.date,
    io.advertiser,
    io.finance_io_name,
    io.DSP_IO_Name,
    dsp_name,
    io.finance_campaign_start_date,
    io.finance_campaign_end_date,
    line_item,
    creative_name,
    dsp_adsv_placid 

--- THE END
---------------------------------------------------------------------------------------------------
