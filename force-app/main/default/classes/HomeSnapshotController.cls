// ================================================================================================
//  Backs the Home Snapshot component (Lightning Home Page): the top KPI tiles, the two "My
//  Prospect & Opportunity Overview" charts, and which of the 5 bottom dashboard link tiles the
//  running user's profile is allowed to see. Record-level visibility (role hierarchy + Lead__Share/
//  Opportunity__Share grants) is shared with the Pro-Active Pipeline dashboard via
//  DashboardVisibilityUtil - see that class for why this exists (both objects' OWD is Public Read
//  Only, so `with sharing` alone doesn't restrict who sees what).
//
//  Single Year + Quarter filtering reuses ProspectsDashboardController's
//  buildDateCondition/buildOpportunityDateCondition (kept public for this reuse) rather than
//  maintaining a second copy of that date-condition logic - each is just wrapped in a single-
//  element list before being handed to those shared, multi-value-capable methods.
// ================================================================================================
public with sharing class HomeSnapshotController {

    public class KpiTiles {
        @AuraEnabled public Integer prospectsGenerated;
        @AuraEnabled public Integer prospectsLost;
        @AuraEnabled public Decimal opportunityRevenueWon;
        @AuraEnabled public Decimal opportunityPipeline;
        @AuraEnabled public Integer samplesRequested;
    }

    public class ChartSeries {
        @AuraEnabled public String label;
        @AuraEnabled public List<Decimal> data;
    }

    public class ChartData {
        @AuraEnabled public List<String> labels;
        @AuraEnabled public List<ChartSeries> series;
    }

    // Mirrors Dashboard_Tile_Access__mdt's 5 checkbox fields one-for-one. Dashboard Ids are looked
    // up by Title at runtime (never hardcoded) since a Dashboard's Id/DeveloperName is org-specific
    // and won't be the same in production as in sandbox - Title is the one thing expected to match
    // across environments for these 4 standard, already-established dashboards.
    public class DashboardTileAccess {
        @AuraEnabled public Boolean sampleRequestDashboard;
        @AuraEnabled public Boolean campaignMetrics;
        @AuraEnabled public Boolean opportunityOverview;
        @AuraEnabled public Boolean opportunityHistoryTracking;
        @AuraEnabled public Boolean proactivePipeline;
        @AuraEnabled public String sampleRequestDashboardId;
        @AuraEnabled public String campaignMetricsId;
        @AuraEnabled public String opportunityOverviewId;
        @AuraEnabled public String opportunityHistoryTrackingId;
    }

    public class HomeSnapshot {
        @AuraEnabled public Integer year;
        @AuraEnabled public String quarter;
        @AuraEnabled public KpiTiles tiles;
        @AuraEnabled public ChartData generationByMonth;
        @AuraEnabled public ChartData pipelineByStage;
        @AuraEnabled public DashboardTileAccess dashboardAccess;
    }

    private static final Map<String, Integer> QUARTER_START_MONTH = new Map<String, Integer>{
        'Q1' => 1, 'Q2' => 4, 'Q3' => 7, 'Q4' => 10
    };
    private static final List<String> MONTH_NAMES = new List<String>{
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    };
    // Won/Lost use the exact Status__c values confirmed on Opportunity__c (not the shorter
    // "Won"/"Lost" labels used loosely in conversation - see ProspectsDashboardController's own
    // OPP_STATUS_WON/OPP_STATUS_LOST for the same confirmation).
    private static final String OPP_STATUS_WON = 'Closed Won';

    @AuraEnabled
    public static HomeSnapshot getHomeSnapshot(Integer year, String quarter) {
        Integer effectiveYear = year != null ? year : Date.today().year();
        String effectiveQuarter = String.isNotBlank(quarter) ? quarter : quarterOfMonth(Date.today().month());

        ProspectsDashboardController.FilterRequest filters = new ProspectsDashboardController.FilterRequest();
        filters.years = new List<Integer>{ effectiveYear };
        filters.quarters = new List<String>{ effectiveQuarter };

        HomeSnapshot result = new HomeSnapshot();
        result.year = effectiveYear;
        result.quarter = effectiveQuarter;
        result.tiles = buildKpiTiles(filters);
        result.generationByMonth = buildGenerationByMonthChart(filters);
        result.pipelineByStage = buildPipelineByStageChart(filters);
        result.dashboardAccess = getDashboardTileAccess();
        return result;
    }

    private static String quarterOfMonth(Integer month) {
        if (month <= 3) {
            return 'Q1';
        } else if (month <= 6) {
            return 'Q2';
        } else if (month <= 9) {
            return 'Q3';
        }
        return 'Q4';
    }

    // The 3 months implied by the filter's single Quarter selection - the X-axis of the
    // Generation-by-month chart.
    private static List<Integer> effectiveChartMonths(ProspectsDashboardController.FilterRequest filters) {
        List<Integer> result = new List<Integer>();
        if (filters.quarters == null || filters.quarters.isEmpty()) {
            return result;
        }
        String q = filters.quarters[0];
        List<String> parts = q.split('-');
        String quarterLabel = parts.size() == 2 ? parts[1] : parts[0];
        Integer startMonth = QUARTER_START_MONTH.get(quarterLabel);
        if (startMonth != null) {
            result.add(startMonth);
            result.add(startMonth + 1);
            result.add(startMonth + 2);
        }
        return result;
    }

    private static String leadVisibilityWhere(Map<String, Object> binds) {
        return DashboardVisibilityUtil.applyDashboardVisibility('', binds, false);
    }

    private static String opportunityVisibilityWhere(Map<String, Object> binds) {
        return DashboardVisibilityUtil.applyDashboardVisibility('', binds, true);
    }

    private static String appendCondition(String existingClause, String condition) {
        return String.isBlank(existingClause) ? ' WHERE ' + condition : existingClause + ' AND ' + condition;
    }

    private static KpiTiles buildKpiTiles(ProspectsDashboardController.FilterRequest filters) {
        KpiTiles tiles = new KpiTiles();

        Map<String, Object> leadBinds = new Map<String, Object>();
        String leadWhere = leadVisibilityWhere(leadBinds);
        String leadDateCondition = ProspectsDashboardController.buildDateCondition(filters, leadBinds);
        if (String.isNotBlank(leadDateCondition)) {
            leadWhere = appendCondition(leadWhere, leadDateCondition);
        }

        List<AggregateResult> stageResults = Database.queryWithBinds(
            'SELECT Lead_Stage__c stage, COUNT(Id) cnt FROM Lead__c' + leadWhere + ' GROUP BY Lead_Stage__c',
            leadBinds,
            AccessLevel.USER_MODE
        );
        Integer totalLeads = 0;
        Integer unqualified = 0;
        for (AggregateResult ar : stageResults) {
            Integer cnt = (Integer) ar.get('cnt');
            totalLeads += cnt;
            if (ar.get('stage') == 'Unqualified') {
                unqualified = cnt;
            }
        }
        tiles.prospectsGenerated = totalLeads;
        tiles.prospectsLost = unqualified;

        Map<String, Object> oppBinds = new Map<String, Object>();
        String oppWhere = opportunityVisibilityWhere(oppBinds);
        String oppDateCondition = ProspectsDashboardController.buildOpportunityDateCondition(filters, oppBinds);
        if (String.isNotBlank(oppDateCondition)) {
            oppWhere = appendCondition(oppWhere, oppDateCondition);
        }

        List<AggregateResult> oppStatusResults = Database.queryWithBinds(
            'SELECT Status__c status, SUM(Total_PF_ASP__c) totalValue FROM Opportunity__c' + oppWhere + ' GROUP BY Status__c',
            oppBinds,
            AccessLevel.USER_MODE
        );
        Decimal won = 0;
        // "Opportunity Pipeline" = not-Won revenue (every Status__c other than Closed Won,
        // matching the literal "not won opportunity - revenue" spec) - includes Closed Lost and
        // every open stage, not just active/open ones.
        Decimal notWon = 0;
        for (AggregateResult ar : oppStatusResults) {
            Decimal value = (Decimal) ar.get('totalValue');
            if (value == null) {
                continue;
            }
            if (ar.get('status') == OPP_STATUS_WON) {
                won += value;
            } else {
                notWon += value;
            }
        }
        tiles.opportunityRevenueWon = won;
        tiles.opportunityPipeline = notWon;

        // Uses buildOpportunityDateCondition, not buildDateCondition, even though this queries
        // Sample_Request_Header__c - the Lead__c version's Quarter handling references
        // Lead_Created_Quarter_No__c, a field that only exists on Lead__c. The Opportunity version
        // builds its quarter condition purely from CALENDAR_YEAR/CALENDAR_MONTH, so it works
        // against any object with a CreatedDate field, Sample_Request_Header__c included.
        Map<String, Object> sampleBinds = new Map<String, Object>();
        String sampleDateCondition = ProspectsDashboardController.buildOpportunityDateCondition(filters, sampleBinds);
        String sampleWhere = ' WHERE Approval_Status__c = \'Approved\'';
        if (String.isNotBlank(sampleDateCondition)) {
            sampleWhere += ' AND ' + sampleDateCondition;
        }
        if (!DashboardVisibilityUtil.currentUserHasFullDataAccess()) {
            sampleBinds.put('sampleOwnerIds', new List<Id>(DashboardVisibilityUtil.currentVisibilityScope().visibleOwnerIds));
            sampleWhere += ' AND OwnerId IN :sampleOwnerIds';
        }
        AggregateResult sampleResult = (AggregateResult) Database.queryWithBinds(
            'SELECT COUNT(Id) cnt FROM Sample_Request_Header__c' + sampleWhere,
            sampleBinds,
            AccessLevel.USER_MODE
        )[0];
        tiles.samplesRequested = (Integer) sampleResult.get('cnt');

        return tiles;
    }

    private static ChartData buildGenerationByMonthChart(ProspectsDashboardController.FilterRequest filters) {
        List<Integer> chartMonths = effectiveChartMonths(filters);

        Map<String, Object> leadBinds = new Map<String, Object>();
        String leadWhere = leadVisibilityWhere(leadBinds);
        String leadDateCondition = ProspectsDashboardController.buildDateCondition(filters, leadBinds);
        if (String.isNotBlank(leadDateCondition)) {
            leadWhere = appendCondition(leadWhere, leadDateCondition);
        }

        Map<Integer, Integer> leadsByMonth = new Map<Integer, Integer>();
        List<AggregateResult> leadMonthResults = Database.queryWithBinds(
            'SELECT CALENDAR_MONTH(CreatedDate) mo, COUNT(Id) cnt FROM Lead__c' + leadWhere + ' GROUP BY CALENDAR_MONTH(CreatedDate)',
            leadBinds,
            AccessLevel.USER_MODE
        );
        for (AggregateResult ar : leadMonthResults) {
            leadsByMonth.put((Integer) ar.get('mo'), (Integer) ar.get('cnt'));
        }

        Map<String, Object> oppBinds = new Map<String, Object>();
        String oppWhere = opportunityVisibilityWhere(oppBinds);
        String oppDateCondition = ProspectsDashboardController.buildOpportunityDateCondition(filters, oppBinds);
        if (String.isNotBlank(oppDateCondition)) {
            oppWhere = appendCondition(oppWhere, oppDateCondition);
        }

        Map<Integer, Integer> oppsByMonth = new Map<Integer, Integer>();
        List<AggregateResult> oppMonthResults = Database.queryWithBinds(
            'SELECT CALENDAR_MONTH(CreatedDate) mo, COUNT(Id) cnt FROM Opportunity__c' + oppWhere + ' GROUP BY CALENDAR_MONTH(CreatedDate)',
            oppBinds,
            AccessLevel.USER_MODE
        );
        for (AggregateResult ar : oppMonthResults) {
            oppsByMonth.put((Integer) ar.get('mo'), (Integer) ar.get('cnt'));
        }

        ChartData data = new ChartData();
        data.labels = new List<String>();
        ChartSeries prospectSeries = new ChartSeries();
        prospectSeries.label = 'Prospects Generated';
        prospectSeries.data = new List<Decimal>();
        ChartSeries oppSeries = new ChartSeries();
        oppSeries.label = 'Opportunities Generated';
        oppSeries.data = new List<Decimal>();

        for (Integer mo : chartMonths) {
            data.labels.add(MONTH_NAMES[mo]);
            prospectSeries.data.add(leadsByMonth.containsKey(mo) ? leadsByMonth.get(mo) : 0);
            oppSeries.data.add(oppsByMonth.containsKey(mo) ? oppsByMonth.get(mo) : 0);
        }
        data.series = new List<ChartSeries>{ prospectSeries, oppSeries };
        return data;
    }

    private static ChartData buildPipelineByStageChart(ProspectsDashboardController.FilterRequest filters) {
        Map<String, Object> oppBinds = new Map<String, Object>();
        String oppWhere = opportunityVisibilityWhere(oppBinds);
        String oppDateCondition = ProspectsDashboardController.buildOpportunityDateCondition(filters, oppBinds);
        if (String.isNotBlank(oppDateCondition)) {
            oppWhere = appendCondition(oppWhere, oppDateCondition);
        }
        // Pipeline-by-stage is about ACTIVE deals in progress, so unlike the "Opportunity
        // Pipeline" KPI tile (not-Won, which includes Lost), this excludes both Closed Won and
        // Closed Lost - a lost deal was never really "in the pipeline by stage".
        oppWhere = appendCondition(oppWhere, 'Status__c != \'Closed Won\' AND Status__c != \'Closed Lost\' AND Status__c != null');

        List<AggregateResult> results = Database.queryWithBinds(
            'SELECT Status__c status, SUM(Total_PF_ASP__c) totalValue FROM Opportunity__c' + oppWhere + ' GROUP BY Status__c',
            oppBinds,
            AccessLevel.USER_MODE
        );

        ChartData data = new ChartData();
        data.labels = new List<String>();
        ChartSeries series = new ChartSeries();
        series.label = 'Pipeline Value';
        series.data = new List<Decimal>();

        for (AggregateResult ar : results) {
            data.labels.add((String) ar.get('status'));
            Decimal value = (Decimal) ar.get('totalValue');
            series.data.add(value == null ? 0 : value);
        }
        data.series = new List<ChartSeries>{ series };
        return data;
    }

    // Looks up the running user's Profile in Dashboard_Tile_Access__mdt to decide which of the 5
    // bottom dashboard link tiles to show - a custom, admin-maintainable substitute for real
    // Salesforce Dashboard-folder sharing (see that type's own description for why). No matching
    // record means no tiles show, rather than defaulting to "show everything" - safer default for
    // an access-control lookup with no configured entry.
    private static DashboardTileAccess getDashboardTileAccess() {
        DashboardTileAccess access = new DashboardTileAccess();

        // Dashboard Ids are always resolved regardless of visibility, so a visible tile always has
        // somewhere to link to - only the boolean flags below decide whether the tile renders.
        Map<String, String> dashboardIdByTitle = new Map<String, String>();
        for (Dashboard d : [
            SELECT Id, Title FROM Dashboard
            WHERE Title IN ('Sample Request Dashboard', 'Campaign Metrics & Target Tracking', 'Opportunity Overview', 'Opportunity History Tracking')
        ]) {
            dashboardIdByTitle.put(d.Title, d.Id);
        }
        access.sampleRequestDashboardId = dashboardIdByTitle.get('Sample Request Dashboard');
        access.campaignMetricsId = dashboardIdByTitle.get('Campaign Metrics & Target Tracking');
        access.opportunityOverviewId = dashboardIdByTitle.get('Opportunity Overview');
        access.opportunityHistoryTrackingId = dashboardIdByTitle.get('Opportunity History Tracking');

        // System Administrators bypass the profile-visibility lookup entirely and see all 5 tiles,
        // same admin exemption used by DashboardVisibilityUtil - also means the tiles aren't
        // silently blank for an admin testing this component before Dashboard_Tile_Access__mdt has
        // any records.
        Boolean unrestricted = DashboardVisibilityUtil.currentUserIsUnrestricted();
        access.sampleRequestDashboard = unrestricted;
        access.campaignMetrics = unrestricted;
        access.opportunityOverview = unrestricted;
        access.opportunityHistoryTracking = unrestricted;
        access.proactivePipeline = unrestricted;
        if (unrestricted) {
            return access;
        }

        String profileName = [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId()].Profile.Name;
        List<Dashboard_Tile_Access__mdt> rows = [
            SELECT Sample_Request_Dashboard_Visible__c, Campaign_Metrics_Visible__c, Opportunity_Overview_Visible__c,
                Opportunity_History_Tracking_Visible__c, Proactive_Pipeline_Visible__c
            FROM Dashboard_Tile_Access__mdt
            WHERE MasterLabel = :profileName
            LIMIT 1
        ];
        if (!rows.isEmpty()) {
            Dashboard_Tile_Access__mdt row = rows[0];
            access.sampleRequestDashboard = row.Sample_Request_Dashboard_Visible__c;
            access.campaignMetrics = row.Campaign_Metrics_Visible__c;
            access.opportunityOverview = row.Opportunity_Overview_Visible__c;
            access.opportunityHistoryTracking = row.Opportunity_History_Tracking_Visible__c;
            access.proactivePipeline = row.Proactive_Pipeline_Visible__c;
        }
        return access;
    }
}