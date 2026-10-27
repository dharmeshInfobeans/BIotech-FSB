public with sharing class ProspectsDashboardController {

    public class FilterRequest {
        // Period disabled per request - field kept only so an older cached payload still
        // deserializes cleanly. Nothing reads it anymore; see buildDateCondition's commented-out
        // predecessor (resolveDateRange/resolveEffectiveYear/resolvePeriodPreset) below for the
        // logic that used to consume it.
        @AuraEnabled public String period;
        @AuraEnabled public List<String> zones;
        @AuraEnabled public List<String> countries;
        @AuraEnabled public List<String> ownerIds;
        @AuraEnabled public List<String> teams;
        @AuraEnabled public List<Integer> years;
        @AuraEnabled public List<String> quarters;
        @AuraEnabled public List<Integer> months;
        @AuraEnabled public List<Integer> weeks;
    }

    public class OwnerOption implements Comparable {
        @AuraEnabled public String id;
        @AuraEnabled public String name;

        public Integer compareTo(Object other) {
            OwnerOption o = (OwnerOption) other;
            return name == o.name ? 0 : (name > o.name ? 1 : -1);
        }
    }

    // value = the raw Country__c value actually stored on the record (what filtering matches
    // against); label = the human-readable name shown in the dropdown. Needed because Lead__c's
    // Country__c picklist stores a handful of values as short codes (e.g. 'IN', 'ES', 'DE') whose
    // labels are the full country name ('INDIA', 'SPAIN', 'GERMANY') - most picklist entries have
    // label == API value, but not all, so the dropdown was showing raw codes for those few.
    public class CountryOption implements Comparable {
        @AuraEnabled public String value;
        @AuraEnabled public String label;

        public Integer compareTo(Object other) {
            CountryOption o = (CountryOption) other;
            return label == o.label ? 0 : (label > o.label ? 1 : -1);
        }
    }

    public class FilterOptions {
        @AuraEnabled public List<String> zones;
        @AuraEnabled public List<CountryOption> countries;
        @AuraEnabled public List<OwnerOption> owners;
        @AuraEnabled public List<Integer> years;
    }

    public class KpiSummary {
        @AuraEnabled public Integer totalProspects;
        @AuraEnabled public Integer wonProspects;
        @AuraEnabled public Integer lostProspects;
        @AuraEnabled public Integer unqualifiedProspects;
        @AuraEnabled public Integer netProspects;
        @AuraEnabled public Integer noFollowUpProspects;
        @AuraEnabled public Integer prospectsClosed;
        @AuraEnabled public Decimal unqualifiedPct;
        @AuraEnabled public Decimal netPct;
        @AuraEnabled public Decimal wonPct;
        @AuraEnabled public Decimal lostPct;
        @AuraEnabled public Decimal noFollowUpPct;
        @AuraEnabled public Decimal closedPct;
        // Opportunity__c is a separate object from every other figure on this tile row (Lead__c) -
        // see getOpportunityUntouchRatio's own comment for why it's counted independently rather
        // than folded into the Lead__c stage breakdown above.
        @AuraEnabled public Integer opportunityUntouchCount;
        @AuraEnabled public Decimal opportunityUntouchPct;
        @AuraEnabled public Integer oppCount;
        @AuraEnabled public Integer wonOpp;
        @AuraEnabled public Integer lostOpp;
        @AuraEnabled public Integer expiredOpp;
        @AuraEnabled public Decimal wonOppPct;
        @AuraEnabled public Decimal lostOppPct;
        @AuraEnabled public Decimal expiredOppPct;
        // Same dedup as the Product Family chart (see uniqueLeadsByNameAndFamily) - two leads
        // named "A" under the same Product Family count once here, not twice.
        @AuraEnabled public Integer uniqueFamilyProspects;
    }

    public class ChartSeries {
        @AuraEnabled public String label;
        @AuraEnabled public List<Decimal> data;
    }

    public class ChartData {
        @AuraEnabled public List<String> labels;
        @AuraEnabled public List<ChartSeries> series;
    }

    // One row of a chart bar's drill-down list. matchedVia names which part of a (possibly
    // multi-part) series this record satisfied - e.g. "Actual Commercialization" vs "Actual
    // Upgrade" within a "Conversion" series - since a record can appear once per matching part,
    // the same way the chart's own count sums parts rather than deduplicating them.
    public class DrillDownRecord {
        @AuraEnabled public String recordId;
        @AuraEnabled public String name;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String zone;
        @AuraEnabled public String country;
        @AuraEnabled public String stage;
        @AuraEnabled public String sapCode;
        @AuraEnabled public String matchedVia;
        @AuraEnabled public String createdDate;
        // Lead__c/Prospect-only export columns (per explicit request, 2026-10) - left null for
        // every non-Lead__c-based DrillDownRecord (Opportunity__c, Task/Event, Campaign_Member__c),
        // same tolerant-blank approach already used for zone/country/sapCode on record types that
        // don't carry them.
        @AuraEnabled public String ceCisRating;
        @AuraEnabled public String phakicRating;
        @AuraEnabled public String actualAppointmentsWeek;
        @AuraEnabled public String convertedDate;
        @AuraEnabled public String unqualifiedDate;
        // Populated only by the whole-chart "deep dive" export (getChartFullDetail /
        // getOpportunityFullDetail) below, where records from every period/series are combined
        // into one list and need these to say which period/series each one belongs to - the
        // single-bar drill-down already has that context from the click itself, so it leaves
        // these null rather than populate them redundantly.
        @AuraEnabled public String seriesLabel;
        @AuraEnabled public String period;
    }

    // A series' count can be built from more than one part summed together - e.g. "Conversion" is
    // actual-commercialization records PLUS actual-upgrade records, not a single
    // Lead_Stage__c IN (...) snapshot (a record can only hold one Lead_Stage__c value at a time,
    // so that snapshot missed anyone who reached Commercialization and later moved on to Upgrade
    // or beyond). Every part - STAGE_* and ACTUAL_DATE alike - is bucketed by CreatedDate, so a
    // lead's count always lands in the quarter it was created in, consistent across every series
    // in a chart (2026-09 correction - ACTUAL_DATE parts previously bucketed by the milestone's own
    // date instead, which put a lead's Evaluation/Conversion count in a different quarter than its
    // Prospect count and broke every ratio chart's quarter-to-quarter comparison).
    private enum SeriesPartType { STAGE_ALL, STAGE_EQUALS, STAGE_NOT_EQUALS, STAGE_IS_BLANK, STAGE_IS_NOT_BLANK, IS_CLOSED, ACTUAL_DATE }

    private class SeriesPart {
        SeriesPartType partType;
        String stageValue;
        String weekNumberField;

        SeriesPart(SeriesPartType partType, String stageValue, String weekNumberField) {
            this.partType = partType;
            this.stageValue = stageValue;
            this.weekNumberField = weekNumberField;
        }
    }

    private class SeriesDef {
        String label;
        List<SeriesPart> parts;

        SeriesDef(String label, List<SeriesPart> parts) {
            this.label = label;
            this.parts = parts;
        }
    }

    private class ChartDef {
        List<SeriesDef> series;
        ChartDef(List<SeriesDef> series) {
            this.series = series;
        }
    }

    private static SeriesPart stageAll() {
        return new SeriesPart(SeriesPartType.STAGE_ALL, null, null);
    }
    private static SeriesPart stageEquals(String value) {
        return new SeriesPart(SeriesPartType.STAGE_EQUALS, value, null);
    }
    private static SeriesPart stageNotEquals(String value) {
        return new SeriesPart(SeriesPartType.STAGE_NOT_EQUALS, value, null);
    }
    private static SeriesPart stageIsBlank() {
        return new SeriesPart(SeriesPartType.STAGE_IS_BLANK, null, null);
    }
    private static SeriesPart stageIsNotBlank() {
        return new SeriesPart(SeriesPartType.STAGE_IS_NOT_BLANK, null, null);
    }
    // weekNumberField is what decides whether a record counts in this part at all (its != null
    // condition, bucketed by CreatedDate like every other part) - it points at the
    // Actual_*_Week_Dashboard__c fields, not the Actual_*_Week_Number__c formula fields directly:
    // those are flagged non-groupable by the platform (though that only matters for GROUP BY, not
    // for a != null check), but more importantly a formula field can't be safely bulk-backfilled
    // the way these plain fields were - existing records were populated manually, and the
    // Lead_Sync_Actual_Week_Numbers flow keeps the Dashboard field in sync with the formula field
    // going forward for every record created/updated from here on.
    private static SeriesPart actualDate(String weekNumberField) {
        return new SeriesPart(SeriesPartType.ACTUAL_DATE, null, weekNumberField);
    }

    // Reuses the exact filter logic already defined on the 15 existing Prospects reports where it
    // still applies, so this chart's numbers match those certified reports rather than a new
    // interpretation - except where a series is explicitly redefined below. "Prospect" is Net
    // Prospects (Total minus Unqualified, i.e. stageNotEquals('Unqualified')) on every chart on
    // this dashboard (2026-09 correction - Overall Reporting/Prospect to Unqualified Ratio/
    // Prospect to Untouch Ratio/End to End Visibility/Expired Prospects previously used the true,
    // unfiltered total instead, which was wrong; every "Prospect" series is Net Prospects now, with
    // no exceptions).
    private static Map<String, ChartDef> chartDefinitions() {
        return new Map<String, ChartDef>{
            'prospectTrend' => new ChartDef(new List<SeriesDef>{
                new SeriesDef('Prospect', new List<SeriesPart>{ stageNotEquals('Unqualified') }),
                new SeriesDef('Actual Commercialization', new List<SeriesPart>{ actualDate('Actual_Commercialization_Week_Dashboard__c') }),
                new SeriesDef('Upgrade', new List<SeriesPart>{ actualDate('Actual_Upgrade_Week_Dashboard__c') })
            }),
            'prospectToEvaluationRatio' => new ChartDef(new List<SeriesDef>{
                new SeriesDef('Prospect', new List<SeriesPart>{ stageNotEquals('Unqualified') }),
                new SeriesDef('Evaluation', new List<SeriesPart>{ actualDate('Actual_Evaluation_Week_Dashboard__c') })
            }),
            'evaluationToConversionRatio' => new ChartDef(new List<SeriesDef>{
                new SeriesDef('Evaluation', new List<SeriesPart>{ actualDate('Actual_Evaluation_Week_Dashboard__c') }),
                new SeriesDef('Conversion', new List<SeriesPart>{
                    actualDate('Actual_Commercialization_Week_Dashboard__c'),
                    actualDate('Actual_Upgrade_Week_Dashboard__c')
                })
            }),
            'prospectToConversionRatio' => new ChartDef(new List<SeriesDef>{
                new SeriesDef('Prospect', new List<SeriesPart>{ stageNotEquals('Unqualified') }),
                new SeriesDef('Conversion', new List<SeriesPart>{
                    actualDate('Actual_Commercialization_Week_Dashboard__c'),
                    actualDate('Actual_Upgrade_Week_Dashboard__c')
                })
            }),
            'overallReporting' => new ChartDef(new List<SeriesDef>{
                new SeriesDef('Prospect', new List<SeriesPart>{ stageNotEquals('Unqualified') }),
                new SeriesDef('WIP & Concluded', new List<SeriesPart>{ stageIsNotBlank() })
            }),
            'prospectToUnqualifiedRatio' => new ChartDef(new List<SeriesDef>{
                new SeriesDef('Prospect', new List<SeriesPart>{ stageNotEquals('Unqualified') }),
                new SeriesDef('Unqualified', new List<SeriesPart>{ stageEquals('Unqualified') })
            }),
            'prospectToUntouchRatio' => new ChartDef(new List<SeriesDef>{
                new SeriesDef('Prospect', new List<SeriesPart>{ stageNotEquals('Unqualified') }),
                new SeriesDef('Untouch', new List<SeriesPart>{ stageIsBlank() })
            }),
            'endToEndVisibility' => new ChartDef(new List<SeriesDef>{
                new SeriesDef('Prospect', new List<SeriesPart>{ stageNotEquals('Unqualified') }),
                new SeriesDef('Advanced or Exited', new List<SeriesPart>{
                    actualDate('Actual_Commercialization_Week_Dashboard__c'),
                    actualDate('Actual_Upgrade_Week_Dashboard__c'),
                    stageEquals('Unqualified'),
                    stageEquals('Lost')
                })
            })
        };
    }

    // Accepts filters as a raw JSON string and deserializes manually with JSON.deserialize rather
    // than declaring FilterRequest as the parameter type directly: automatic Aura/LWC parameter
    // deserialization for this custom inner class was observed (via debug log) to silently produce
    // a blank FilterRequest instance, losing every field, even though the client sent a fully
    // populated object. Manual deserialization avoids that failure mode entirely.
    @AuraEnabled
    public static ChartData getChartData(String chartKey, String filtersJson) {
        // Opportunity to Untouch Ratio queries Opportunity__c, not Lead__c - it's handled by its
        // own dedicated method (see below) rather than forced through chartDefinitions()/
        // queryPartCounts(), which are Lead__c-specific (hardcoded FROM Lead__c, Lead__c-only
        // filter fields like Sales_Marketing_Lead__c). The LWC doesn't need to know the
        // difference - it calls getChartData with a chartKey exactly like every other chart.
        if (chartKey == 'opportunityToUntouchRatio') {
            return getOpportunityUntouchRatio(filtersJson);
        }
        if (chartKey == 'opportunityEndToEndVisibility') {
            return getOpportunityEndToEndVisibility(filtersJson);
        }
        if (chartKey == 'opportunityTrend') {
            return getOpportunityTrend(filtersJson);
        }
        if (chartKey == 'opportunityToEvaluationRatio') {
            return getOpportunityToEvaluationRatio(filtersJson);
        }
        if (chartKey == 'opportunityEvaluationToConversionRatio') {
            return getOpportunityEvaluationToConversionRatio(filtersJson);
        }
        if (chartKey == 'expiredOpportunity') {
            return getExpiredOpportunity(filtersJson);
        }
        if (chartKey == 'overallReportingOpp') {
            return getOverallReportingOpp(filtersJson);
        }
        if (chartKey == 'expiredProspects') {
            return getExpiredProspects(filtersJson);
        }
        if (chartKey == 'inClinicTarget') {
            return getInClinicTargetActivities(filtersJson);
        }
        if (chartKey == 'marketingTarget') {
            return getMarketingTargetCampaignMembers(filtersJson);
        }

        FilterRequest filters = parseFilters(filtersJson);
        ChartDef def = chartDefinitions().get(chartKey);
        if (def == null) {
            throw new AuraHandledException('Unknown chart: ' + chartKey);
        }

        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildWhereClause(filters, baseBinds);

        List<String> periodKeys = new List<String>();
        Set<String> seenPeriods = new Set<String>();
        Map<Integer, Map<String, Integer>> countsBySeries = new Map<Integer, Map<String, Integer>>();
        for (Integer i = 0; i < def.series.size(); i++) {
            countsBySeries.put(i, new Map<String, Integer>());
        }

        // A part shape (e.g. actualDate('Actual_Commercialization_week__c', 'Actual_Commercialization_Week_Dashboard__c')) is only ever queried
        // once per chart even if more than one series in that chart uses it, rather than once per
        // series that references it.
        Map<String, Map<String, Integer>> partCountsCache = new Map<String, Map<String, Integer>>();

        for (Integer i = 0; i < def.series.size(); i++) {
            for (SeriesPart part : def.series[i].parts) {
                String cacheKey = partCacheKey(part);
                Map<String, Integer> partCounts = partCountsCache.get(cacheKey);
                if (partCounts == null) {
                    partCounts = queryPartCounts(part, baseWhere, baseBinds);
                    partCountsCache.put(cacheKey, partCounts);
                }

                Map<String, Integer> seriesCounts = countsBySeries.get(i);
                for (String period : partCounts.keySet()) {
                    if (!seenPeriods.contains(period)) {
                        seenPeriods.add(period);
                        periodKeys.add(period);
                    }
                    Integer existing = seriesCounts.containsKey(period) ? seriesCounts.get(period) : 0;
                    seriesCounts.put(period, existing + partCounts.get(period));
                }
            }
        }

        periodKeys.sort();

        ChartData result = new ChartData();
        result.labels = periodKeys;
        result.series = new List<ChartSeries>();
        for (Integer i = 0; i < def.series.size(); i++) {
            ChartSeries cs = new ChartSeries();
            cs.label = def.series[i].label;
            cs.data = new List<Decimal>();
            Map<String, Integer> seriesCounts = countsBySeries.get(i);
            for (String key : periodKeys) {
                cs.data.add(seriesCounts.containsKey(key) ? seriesCounts.get(key) : 0);
            }
            result.series.add(cs);
        }
        return result;
    }

    // ============================================================================================
    //  Expired Prospects (2026-09 rewrite) - "Closed (Expired)" was Lead_Closed__c = true; per
    //  request this now specifically means "closed WITHOUT converting to an Opportunity" -
    //  Lead_Closed__c = true AND this Lead's Id doesn't appear as any Opportunity__c.Lead_Id__c
    //  (the same join used by Opportunity Trend - Opportunity__c.Lead_Id__c is a plain Text field
    //  storing the Lead's Id, not a true lookup; Lead__c's own Converted_Opportunity_Id__c lookup
    //  is unused/always-null in production, confirmed while building Opportunity Trend).
    //
    //  Pulled out of the generic chartDefinitions()/SeriesPart system below because that system
    //  applies ONE baseWhere uniformly to every series via a fixed enum of condition shapes, and
    //  can't express "exclude these specific Ids" per series. Reuses queryPartCounts/
    //  queryPartRecords/queryPartFullDetail directly instead of duplicating their quarter-bucketing
    //  and GMT->IST boundary-correction logic: passing stageAll() as the "part" is a no-op condition
    //  (see appendPartCondition's STAGE_ALL branch), so the actual Closed-and-not-converted
    //  condition is baked into the baseWhere string handed in instead.
    // ============================================================================================
    private static Set<Id> allConvertedLeadIds() {
        Set<Id> leadIds = new Set<Id>();
        if (!OPP_LEAD_ID_FIELD_EXISTS) {
            return leadIds;
        }
        for (SObject row : Database.query('SELECT Lead_Id__c FROM Opportunity__c WHERE Lead_Id__c != null', AccessLevel.USER_MODE)) {
            Object rawLeadId = row.get('Lead_Id__c');
            String rawLeadIdStr = rawLeadId == null ? null : String.valueOf(rawLeadId).trim();
            if (String.isNotBlank(rawLeadIdStr)) {
                try {
                    leadIds.add(Id.valueOf(rawLeadIdStr));
                } catch (Exception e) {
                    // malformed value - not a real Lead Id, skip
                }
            }
        }
        return leadIds;
    }

    // Mutates binds (adding the excluded-Ids bind when there are any) and returns the WHERE clause
    // - same mutate-and-return shape buildWhereClause/buildOpportunityWhereClause already use.
    private static String expiredProspectsClosedWhere(String baseWhere, Map<String, Object> binds) {
        String closedWhere = appendCondition(baseWhere, 'Lead_Closed__c = true');
        Set<Id> convertedLeadIds = allConvertedLeadIds();
        if (!convertedLeadIds.isEmpty()) {
            binds.put('expiredExcludedLeadIds', new List<Id>(convertedLeadIds));
            closedWhere = appendCondition(closedWhere, 'Id NOT IN :expiredExcludedLeadIds');
        }
        return closedWhere;
    }

    private static ChartData getExpiredProspects(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildWhereClause(filters, baseBinds);

        Map<String, Integer> prospectCounts = queryPartCounts(stageNotEquals('Unqualified'), baseWhere, baseBinds);

        Map<String, Object> closedBinds = baseBinds.clone();
        String closedWhere = expiredProspectsClosedWhere(baseWhere, closedBinds);
        Map<String, Integer> closedCounts = queryPartCounts(stageAll(), closedWhere, closedBinds);

        Set<String> allPeriods = new Set<String>();
        allPeriods.addAll(prospectCounts.keySet());
        allPeriods.addAll(closedCounts.keySet());
        List<String> periodKeys = new List<String>(allPeriods);
        periodKeys.sort();

        ChartSeries prospectSeries = new ChartSeries();
        prospectSeries.label = 'Prospect';
        prospectSeries.data = new List<Decimal>();

        ChartSeries closedSeries = new ChartSeries();
        closedSeries.label = 'Closed (Expired)';
        closedSeries.data = new List<Decimal>();

        for (String key : periodKeys) {
            prospectSeries.data.add(prospectCounts.containsKey(key) ? prospectCounts.get(key) : 0);
            closedSeries.data.add(closedCounts.containsKey(key) ? closedCounts.get(key) : 0);
        }

        ChartData result = new ChartData();
        result.labels = periodKeys;
        result.series = new List<ChartSeries>{ prospectSeries, closedSeries };
        return result;
    }

    private static List<DrillDownRecord> getExpiredProspectsDrillDownRecords(String seriesLabel, String period, String filtersJson) {
        if (seriesLabel != 'Prospect' && seriesLabel != 'Closed (Expired)') {
            throw new AuraHandledException('Unknown series: ' + seriesLabel);
        }
        List<String> periodParts = period != null ? period.split('-') : new List<String>();
        if (periodParts.size() != 2 || !QUARTER_START_MONTH.containsKey(periodParts[1])) {
            throw new AuraHandledException('Unrecognized period: ' + period);
        }
        Integer year = Integer.valueOf(periodParts[0]);
        String quarter = periodParts[1];

        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildWhereClause(filters, baseBinds);

        if (seriesLabel == 'Prospect') {
            return queryPartRecords(stageNotEquals('Unqualified'), baseWhere, baseBinds, year, quarter);
        }

        Map<String, Object> closedBinds = baseBinds.clone();
        String closedWhere = expiredProspectsClosedWhere(baseWhere, closedBinds);
        List<DrillDownRecord> matched = queryPartRecords(stageAll(), closedWhere, closedBinds, year, quarter);
        for (DrillDownRecord dr : matched) {
            dr.matchedVia = 'Closed';
        }
        return matched;
    }

    private static List<DrillDownRecord> getExpiredProspectsFullDetail(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildWhereClause(filters, baseBinds);
        // Smaller than the usual FULL_DETAIL_BUDGET/2 split - allConvertedLeadIds() above adds its
        // own several-thousand-row query on top of these two parts' own queries, all within the
        // same 50,000-row-per-transaction budget.
        Integer perPartCap = Math.max(FULL_DETAIL_MIN_PER_PART, 35000 / 2);

        List<DrillDownRecord> results = new List<DrillDownRecord>();
        results.addAll(queryPartFullDetail(stageNotEquals('Unqualified'), baseWhere, baseBinds, 'Prospect', perPartCap));

        Map<String, Object> closedBinds = baseBinds.clone();
        String closedWhere = expiredProspectsClosedWhere(baseWhere, closedBinds);
        List<DrillDownRecord> closedResults = queryPartFullDetail(stageAll(), closedWhere, closedBinds, 'Closed (Expired)', perPartCap);
        for (DrillDownRecord dr : closedResults) {
            if (dr.recordId != null) {
                dr.matchedVia = 'Closed';
            }
        }
        results.addAll(closedResults);

        return results;
    }

    // ============================================================================================
    //  In-Clinic Target Activities & Marketing Target Campaign Members - a separate object tree
    //  entirely (Target__c / Campaign__c / Campaign_Member__c / Task / Event), not Lead__c or
    //  Opportunity__c. Target__c.Type__c ('In-Clinic Activities' / 'Marketing Activities') decides
    //  which of the two charts a Target belongs to:
    //    - In-Clinic Targets have Activities (Task/Event) logged directly against them via the
    //      standard polymorphic WhatId field (Target__c has Activities enabled) - no Campaign
    //      involved.
    //    - Marketing Targets instead drive Campaign__c records (Campaign__c.Target__c, a required
    //      lookup) which in turn get Campaign_Member__c rows (Campaign_Member__c.Campaign1__c).
    //      Attended__c (checkbox) marks whether that member actually produced a Lead
    //      (Campaign_Member__c.Lead1__c) - an unattended member has no real lead outcome to judge.
    //  Period for BOTH charts = the owning Target's own Year__c + '-' + Quater_No__c (e.g.
    //  "2026-Q1"), NOT the activity's/campaign member's own CreatedDate - these are per-target
    //  planning fields, and a target's actual execution can span dates outside its nominal period.
    //  Only Year/Quarter filters are honored here (they map directly onto Target__c's own
    //  Year__c/Quater_No__c picklists); Zone/Country/Owner/Team/Month/Week don't narrow either
    //  chart (same "tolerant" approach already used where Team doesn't narrow Opportunity charts) -
    //  Target__c's owner-ish field is User__c, not OwnerId, and its Country__c/Zone__c values
    //  haven't been confirmed to line up with Lead__c's, so those were deliberately left alone
    //  rather than guessed at.
    // ============================================================================================

    private static String targetPeriodKey(Target__c t) {
        return t.Year__c + '-' + t.Quater_No__c;
    }

    private static List<Target__c> queryTargetsByType(String typeValue, FilterRequest filters) {
        Map<String, Object> binds = new Map<String, Object>{ 'typeValue' => typeValue };
        List<String> conditions = new List<String>{ 'Type__c = :typeValue', 'Year__c != null', 'Quater_No__c != null' };
        if (filters != null && filters.years != null && !filters.years.isEmpty()) {
            List<String> yearStrings = new List<String>();
            for (Integer y : filters.years) {
                yearStrings.add(String.valueOf(y));
            }
            binds.put('targetYears', yearStrings);
            conditions.add('Year__c IN :targetYears');
        }
        if (filters != null && filters.quarters != null && !filters.quarters.isEmpty()) {
            binds.put('targetQuarters', filters.quarters);
            conditions.add('Quater_No__c IN :targetQuarters');
        }
        return Database.queryWithBinds(
            'SELECT Id, Name, Year__c, Quater_No__c FROM Target__c WHERE ' + String.join(conditions, ' AND ') + ' LIMIT 49000',
            binds,
            AccessLevel.USER_MODE
        );
    }

    // ---- In-Clinic Target Activities ----

    private static Map<Id, String> inClinicTargetPeriods(FilterRequest filters) {
        Map<Id, String> periodByTargetId = new Map<Id, String>();
        for (Target__c t : queryTargetsByType('In-Clinic Activities', filters)) {
            periodByTargetId.put(t.Id, targetPeriodKey(t));
        }
        return periodByTargetId;
    }

    private static DrillDownRecord toActivityDrillDownRecord(SObject activity, String matchedVia) {
        DrillDownRecord dr = new DrillDownRecord();
        dr.recordId = (Id) activity.get('Id');
        dr.name = (String) activity.get('Subject');
        SObject ownerRow = activity.getSObject('Owner');
        dr.ownerName = ownerRow == null ? null : (String) ownerRow.get('Name');
        dr.matchedVia = matchedVia;
        Datetime createdDate = (Datetime) activity.get('CreatedDate');
        dr.createdDate = createdDate == null ? null : createdDate.format('dd-MMM-yyyy hh:mm a');
        return dr;
    }

    private static ChartData getInClinicTargetActivities(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<Id, String> periodByTargetId = inClinicTargetPeriods(filters);

        Map<String, Integer> countsByPeriod = new Map<String, Integer>();
        for (String period : periodByTargetId.values()) {
            if (!countsByPeriod.containsKey(period)) {
                countsByPeriod.put(period, 0);
            }
        }

        if (!periodByTargetId.isEmpty()) {
            Set<Id> targetIds = periodByTargetId.keySet();
            for (AggregateResult ar : [SELECT WhatId wid, COUNT(Id) cnt FROM Task WHERE WhatId IN :targetIds GROUP BY WhatId]) {
                String period = periodByTargetId.get((Id) ar.get('wid'));
                countsByPeriod.put(period, (countsByPeriod.containsKey(period) ? countsByPeriod.get(period) : 0) + (Integer) ar.get('cnt'));
            }
            for (AggregateResult ar : [SELECT WhatId wid, COUNT(Id) cnt FROM Event WHERE WhatId IN :targetIds GROUP BY WhatId]) {
                String period = periodByTargetId.get((Id) ar.get('wid'));
                countsByPeriod.put(period, (countsByPeriod.containsKey(period) ? countsByPeriod.get(period) : 0) + (Integer) ar.get('cnt'));
            }
        }

        List<String> periods = new List<String>(countsByPeriod.keySet());
        periods.sort();

        ChartSeries s = new ChartSeries();
        s.label = 'Activities';
        s.data = new List<Decimal>();
        for (String p : periods) {
            s.data.add(countsByPeriod.get(p));
        }

        ChartData result = new ChartData();
        result.labels = periods;
        result.series = new List<ChartSeries>{ s };
        return result;
    }

    private static Set<Id> inClinicTargetIdsForPeriod(FilterRequest filters, String period) {
        Set<Id> matchingIds = new Set<Id>();
        for (Target__c t : queryTargetsByType('In-Clinic Activities', filters)) {
            if (targetPeriodKey(t) == period) {
                matchingIds.add(t.Id);
            }
        }
        return matchingIds;
    }

    private static List<DrillDownRecord> getInClinicTargetActivitiesDrillDownRecords(String seriesLabel, String period, String filtersJson) {
        if (seriesLabel != 'Activities') {
            throw new AuraHandledException('Unknown series: ' + seriesLabel);
        }
        FilterRequest filters = parseFilters(filtersJson);
        Set<Id> targetIds = inClinicTargetIdsForPeriod(filters, period);

        List<DrillDownRecord> results = new List<DrillDownRecord>();
        if (targetIds.isEmpty()) {
            return results;
        }
        Map<String, Object> binds = new Map<String, Object>{ 'targetIds' => targetIds };
        for (Task t : (List<Task>) Database.queryWithBinds(
            'SELECT Id, Subject, Owner.Name, CreatedDate FROM Task WHERE WhatId IN :targetIds LIMIT ' + DRILL_DOWN_LIMIT,
            binds,
            AccessLevel.USER_MODE
        )) {
            results.add(toActivityDrillDownRecord(t, 'Task'));
        }
        for (Event e : (List<Event>) Database.queryWithBinds(
            'SELECT Id, Subject, Owner.Name, CreatedDate FROM Event WHERE WhatId IN :targetIds LIMIT ' + DRILL_DOWN_LIMIT,
            binds,
            AccessLevel.USER_MODE
        )) {
            results.add(toActivityDrillDownRecord(e, 'Event'));
        }
        return results;
    }

    private static List<DrillDownRecord> getInClinicTargetActivitiesFullDetail(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<Id, String> periodByTargetId = inClinicTargetPeriods(filters);

        List<DrillDownRecord> results = new List<DrillDownRecord>();
        if (periodByTargetId.isEmpty()) {
            return results;
        }
        Integer perPartCap = Math.max(FULL_DETAIL_MIN_PER_PART, 35000 / 2);
        Map<String, Object> binds = new Map<String, Object>{ 'targetIds' => periodByTargetId.keySet() };

        for (Task t : (List<Task>) Database.queryWithBinds(
            'SELECT Id, Subject, Owner.Name, CreatedDate, WhatId FROM Task WHERE WhatId IN :targetIds LIMIT ' + perPartCap,
            binds,
            AccessLevel.USER_MODE
        )) {
            DrillDownRecord dr = toActivityDrillDownRecord(t, 'Task');
            dr.seriesLabel = 'Activities';
            dr.period = periodByTargetId.get((Id) t.get('WhatId'));
            results.add(dr);
        }
        for (Event e : (List<Event>) Database.queryWithBinds(
            'SELECT Id, Subject, Owner.Name, CreatedDate, WhatId FROM Event WHERE WhatId IN :targetIds LIMIT ' + perPartCap,
            binds,
            AccessLevel.USER_MODE
        )) {
            DrillDownRecord dr = toActivityDrillDownRecord(e, 'Event');
            dr.seriesLabel = 'Activities';
            dr.period = periodByTargetId.get((Id) e.get('WhatId'));
            results.add(dr);
        }
        return results;
    }

    // ---- Marketing Target Campaign Members ----

    private static final List<String> MARKETING_TARGET_SERIES = new List<String>{ 'Attended', 'Not Attended' };

    // Converted/In Progress/Not Converted per explicit confirmation: Lead_Stage__c has exactly 3
    // real values (Converted, Appointments, Unqualified) plus blank - Converted maps to Converted,
    // Unqualified maps to Not Converted, and both blank (no stage marked yet) and Appointments
    // (appointment scheduled but not yet resolved) map to In Progress.
    private static String leadStatusBucket(String leadStage) {
        if (leadStage == 'Converted') {
            return 'Converted';
        }
        if (leadStage == 'Unqualified') {
            return 'Not Converted';
        }
        return 'In Progress';
    }

    // Campaign Members belonging to a Marketing Target's campaign(s), joined to the period (the
    // owning Target's own Year/Quarter - see note above) - shared by the chart, drill-down, and
    // full-detail export so all three agree by construction. memberByIdOut is populated with every
    // matched Campaign_Member__c (including its related Lead1__r fields) so callers don't re-query.
    private static Map<Id, String> marketingTargetMemberPeriods(FilterRequest filters, Map<Id, Campaign_Member__c> memberByIdOut) {
        Map<Id, String> periodByMemberId = new Map<Id, String>();

        Map<Id, String> periodByTargetId = new Map<Id, String>();
        for (Target__c t : queryTargetsByType('Marketing Activities', filters)) {
            periodByTargetId.put(t.Id, targetPeriodKey(t));
        }
        if (periodByTargetId.isEmpty()) {
            return periodByMemberId;
        }

        Map<Id, Id> targetIdByCampaignId = new Map<Id, Id>();
        for (Campaign__c c : (List<Campaign__c>) Database.queryWithBinds(
            'SELECT Id, Target__c FROM Campaign__c WHERE Target__c IN :targetIds LIMIT 49000',
            new Map<String, Object>{ 'targetIds' => periodByTargetId.keySet() },
            AccessLevel.USER_MODE
        )) {
            targetIdByCampaignId.put(c.Id, c.Target__c);
        }
        if (targetIdByCampaignId.isEmpty()) {
            return periodByMemberId;
        }

        for (Campaign_Member__c m : (List<Campaign_Member__c>) Database.queryWithBinds(
            'SELECT Id, Name, Attended__c, Campaign1__c, Lead1__c, Lead1__r.Name, Lead1__r.Lead_Stage__c, ' +
            'Lead1__r.Owner.Name, Lead1__r.Zone__c, Lead1__r.Country__c, CreatedDate ' +
            'FROM Campaign_Member__c WHERE Campaign1__c IN :campaignIds LIMIT 49000',
            new Map<String, Object>{ 'campaignIds' => targetIdByCampaignId.keySet() },
            AccessLevel.USER_MODE
        )) {
            memberByIdOut.put(m.Id, m);
            Id targetId = targetIdByCampaignId.get(m.Campaign1__c);
            if (targetId != null) {
                periodByMemberId.put(m.Id, periodByTargetId.get(targetId));
            }
        }
        return periodByMemberId;
    }

    private static DrillDownRecord toMarketingTargetDrillDownRecord(Campaign_Member__c m, String seriesLabel) {
        DrillDownRecord dr = new DrillDownRecord();
        dr.recordId = m.Id;
        Lead__c lead = m.Lead1__r;
        dr.name = lead == null ? null : lead.Name;
        dr.ownerName = (lead == null || lead.Owner == null) ? null : lead.Owner.Name;
        dr.zone = lead == null ? null : lead.Zone__c;
        dr.country = lead == null ? null : lead.Country__c;
        dr.stage = lead == null ? null : leadStatusBucket(lead.Lead_Stage__c);
        dr.matchedVia = seriesLabel;
        dr.createdDate = m.CreatedDate == null ? null : m.CreatedDate.format('dd-MMM-yyyy hh:mm a');
        return dr;
    }

    private static ChartData getMarketingTargetCampaignMembers(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<Id, Campaign_Member__c> memberById = new Map<Id, Campaign_Member__c>();
        Map<Id, String> periodByMemberId = marketingTargetMemberPeriods(filters, memberById);

        Map<String, Map<String, Integer>> countsBySeries = new Map<String, Map<String, Integer>>();
        for (String series : MARKETING_TARGET_SERIES) {
            countsBySeries.put(series, new Map<String, Integer>());
        }
        Set<String> periodSet = new Set<String>();

        for (Id memberId : periodByMemberId.keySet()) {
            String period = periodByMemberId.get(memberId);
            periodSet.add(period);
            Campaign_Member__c m = memberById.get(memberId);
            String series = m.Attended__c ? 'Attended' : 'Not Attended';
            Map<String, Integer> counts = countsBySeries.get(series);
            counts.put(period, (counts.containsKey(period) ? counts.get(period) : 0) + 1);
        }

        List<String> periods = new List<String>(periodSet);
        periods.sort();

        List<ChartSeries> series = new List<ChartSeries>();
        for (String label : MARKETING_TARGET_SERIES) {
            ChartSeries cs = new ChartSeries();
            cs.label = label;
            cs.data = new List<Decimal>();
            Map<String, Integer> counts = countsBySeries.get(label);
            for (String p : periods) {
                cs.data.add(counts.containsKey(p) ? counts.get(p) : 0);
            }
            series.add(cs);
        }

        ChartData result = new ChartData();
        result.labels = periods;
        result.series = series;
        return result;
    }

    private static List<DrillDownRecord> getMarketingTargetCampaignMembersDrillDownRecords(String seriesLabel, String period, String filtersJson) {
        if (!MARKETING_TARGET_SERIES.contains(seriesLabel)) {
            throw new AuraHandledException('Unknown series: ' + seriesLabel);
        }
        FilterRequest filters = parseFilters(filtersJson);
        Map<Id, Campaign_Member__c> memberById = new Map<Id, Campaign_Member__c>();
        Map<Id, String> periodByMemberId = marketingTargetMemberPeriods(filters, memberById);

        Boolean wantAttended = seriesLabel == 'Attended';
        List<DrillDownRecord> matched = new List<DrillDownRecord>();
        for (Id memberId : periodByMemberId.keySet()) {
            if (periodByMemberId.get(memberId) != period) {
                continue;
            }
            Campaign_Member__c m = memberById.get(memberId);
            if (m.Attended__c == wantAttended) {
                matched.add(toMarketingTargetDrillDownRecord(m, seriesLabel));
            }
        }
        return matched;
    }

    private static List<DrillDownRecord> getMarketingTargetCampaignMembersFullDetail(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<Id, Campaign_Member__c> memberById = new Map<Id, Campaign_Member__c>();
        Map<Id, String> periodByMemberId = marketingTargetMemberPeriods(filters, memberById);

        List<DrillDownRecord> results = new List<DrillDownRecord>();
        for (Id memberId : periodByMemberId.keySet()) {
            Campaign_Member__c m = memberById.get(memberId);
            String seriesLabel = m.Attended__c ? 'Attended' : 'Not Attended';
            DrillDownRecord dr = toMarketingTargetDrillDownRecord(m, seriesLabel);
            dr.seriesLabel = seriesLabel;
            dr.period = periodByMemberId.get(memberId);
            results.add(dr);
        }
        return results;
    }

    // ============================================================================================
    //  Opportunity to Untouch Ratio - queries Opportunity__c, a separate object from every other
    //  chart on this dashboard (Lead__c). "Opportunity" is every Opportunity__c matching the active
    //  filters; "Untouch" is Status__c blank (2026-09 correction - same condition as Lead__c's
    //  "No Follow Up" tile/"Untouch" series, Lead_Stage__c blank; NOT Opportunity_Closed__c = true,
    //  which is a different concept covered by its own Expired Opportunity chart). Mirrors the
    //  Lead__c charts' own bucketing (CreatedDate
    //  quarter, calendar convention, GMT->IST boundary correction) and filter shape (Zone/Country/
    //  Owner-role-union/Year/Quarter/Month/Week), duplicated here in Opportunity__c-specific form
    //  rather than generalizing the Lead__c engine to be multi-object - Opportunity__c only
    //  partially overlaps Lead__c's filterable fields (no Sales/Marketing team equivalent, no
    //  Lead_Created_Quarter_No__c-style formula field for Quarter filtering, so that filter here
    //  derives its month set the same way the Lead__c Quarter filter did before it switched to a
    //  formula field - a small, rare GMT/local mismatch right at a quarter boundary is an accepted
    //  gap for this one chart rather than building an equivalent formula field for it).
    // ============================================================================================
    private static ChartData getOpportunityUntouchRatio(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);

        Map<String, Integer> allCounts = queryOpportunityCounts(baseWhere, baseBinds);

        Map<String, Object> untouchBinds = baseBinds.clone();
        String untouchWhere = appendCondition(baseWhere, 'Status__c = null');
        Map<String, Integer> untouchCounts = queryOpportunityCounts(untouchWhere, untouchBinds);

        Set<String> allPeriods = new Set<String>();
        allPeriods.addAll(allCounts.keySet());
        allPeriods.addAll(untouchCounts.keySet());
        List<String> periodKeys = new List<String>(allPeriods);
        periodKeys.sort();

        ChartSeries oppSeries = new ChartSeries();
        oppSeries.label = 'Opportunity';
        oppSeries.data = new List<Decimal>();

        ChartSeries untouchSeries = new ChartSeries();
        untouchSeries.label = 'Untouch';
        untouchSeries.data = new List<Decimal>();

        for (String key : periodKeys) {
            oppSeries.data.add(allCounts.containsKey(key) ? allCounts.get(key) : 0);
            untouchSeries.data.add(untouchCounts.containsKey(key) ? untouchCounts.get(key) : 0);
        }

        ChartData result = new ChartData();
        result.labels = periodKeys;
        result.series = new List<ChartSeries>{ oppSeries, untouchSeries };
        return result;
    }

    // ============================================================================================
    //  Opportunity End to End Visibility - same Opportunity__c object/bucketing/filters as
    //  Opportunity to Untouch Ratio above, but three series instead of two: every Opportunity__c
    //  matching the active filters ("Opportunity"), the subset with Status__c = 'Closed Won'
    //  ("Won"), and the subset with Status__c = 'Closed Lost' ("Lost") - the exact values stored on
    //  Status__c in this org (confirmed via a direct GROUP BY query), not the shorter "Won"/"Lost"
    //  labels used loosely in conversation.
    // ============================================================================================
    private static final String OPP_STATUS_WON = 'Closed Won';
    private static final String OPP_STATUS_LOST = 'Closed Lost';

    private static ChartData getOpportunityEndToEndVisibility(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);

        Map<String, Integer> allCounts = queryOpportunityCounts(baseWhere, baseBinds);

        Map<String, Object> wonBinds = baseBinds.clone();
        wonBinds.put('oppStatusVal', OPP_STATUS_WON);
        String wonWhere = appendCondition(baseWhere, 'Status__c = :oppStatusVal');
        Map<String, Integer> wonCounts = queryOpportunityCounts(wonWhere, wonBinds);

        Map<String, Object> lostBinds = baseBinds.clone();
        lostBinds.put('oppStatusVal', OPP_STATUS_LOST);
        String lostWhere = appendCondition(baseWhere, 'Status__c = :oppStatusVal');
        Map<String, Integer> lostCounts = queryOpportunityCounts(lostWhere, lostBinds);

        Set<String> allPeriods = new Set<String>();
        allPeriods.addAll(allCounts.keySet());
        allPeriods.addAll(wonCounts.keySet());
        allPeriods.addAll(lostCounts.keySet());
        List<String> periodKeys = new List<String>(allPeriods);
        periodKeys.sort();

        ChartSeries oppSeries2 = new ChartSeries();
        oppSeries2.label = 'Opportunity';
        oppSeries2.data = new List<Decimal>();

        ChartSeries wonSeries = new ChartSeries();
        wonSeries.label = 'Won';
        wonSeries.data = new List<Decimal>();

        ChartSeries lostSeries = new ChartSeries();
        lostSeries.label = 'Lost';
        lostSeries.data = new List<Decimal>();

        for (String key : periodKeys) {
            oppSeries2.data.add(allCounts.containsKey(key) ? allCounts.get(key) : 0);
            wonSeries.data.add(wonCounts.containsKey(key) ? wonCounts.get(key) : 0);
            lostSeries.data.add(lostCounts.containsKey(key) ? lostCounts.get(key) : 0);
        }

        ChartData result = new ChartData();
        result.labels = periodKeys;
        result.series = new List<ChartSeries>{ oppSeries2, wonSeries, lostSeries };
        return result;
    }

    private static List<DrillDownRecord> getOpportunityEndToEndDrillDownRecords(String seriesLabel, String period, String filtersJson) {
        if (seriesLabel != 'Opportunity' && seriesLabel != 'Won' && seriesLabel != 'Lost') {
            throw new AuraHandledException('Unknown series: ' + seriesLabel);
        }

        List<String> periodParts = period != null ? period.split('-') : new List<String>();
        if (periodParts.size() != 2 || !QUARTER_START_MONTH.containsKey(periodParts[1])) {
            throw new AuraHandledException('Unrecognized period: ' + period);
        }
        Integer year = Integer.valueOf(periodParts[0]);
        String quarter = periodParts[1];

        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);
        if (seriesLabel == 'Won') {
            baseBinds.put('oppStatusVal', OPP_STATUS_WON);
            baseWhere = appendCondition(baseWhere, 'Status__c = :oppStatusVal');
        } else if (seriesLabel == 'Lost') {
            baseBinds.put('oppStatusVal', OPP_STATUS_LOST);
            baseWhere = appendCondition(baseWhere, 'Status__c = :oppStatusVal');
        }

        return queryOpportunityPartRecords(baseWhere, baseBinds, year, quarter, seriesLabel);
    }

    private static List<DrillDownRecord> getOpportunityEndToEndFullDetail(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);
        Integer perPartCap = FULL_DETAIL_SINGLE_QUERY_LIMIT / 3;

        List<DrillDownRecord> results = new List<DrillDownRecord>();
        results.addAll(queryOpportunityFullDetail(baseWhere, baseBinds, 'Opportunity', perPartCap));

        Map<String, Object> wonBinds = baseBinds.clone();
        wonBinds.put('oppStatusVal', OPP_STATUS_WON);
        String wonWhere = appendCondition(baseWhere, 'Status__c = :oppStatusVal');
        results.addAll(queryOpportunityFullDetail(wonWhere, wonBinds, 'Won', perPartCap));

        Map<String, Object> lostBinds = baseBinds.clone();
        lostBinds.put('oppStatusVal', OPP_STATUS_LOST);
        String lostWhere = appendCondition(baseWhere, 'Status__c = :oppStatusVal');
        results.addAll(queryOpportunityFullDetail(lostWhere, lostBinds, 'Lost', perPartCap));

        return results;
    }

    // ============================================================================================
    //  Opportunity Trend (2026-09 rewrite) - was 3 quarter-wise series on Opportunity__c alone
    //  (Opportunity / Actual Commercialization (New) / Total Won Opp from Commercialization stage);
    //  fully replaced per request with a month-wise trend of Opportunities CREATED, bucketed by the
    //  Team (Sales_Marketing_Lead__c) of the Lead__c each Opportunity came from - "how many opps got
    //  created over time, split by whether they came from a Sales or Marketing prospect".
    //
    //  Opportunity__c -> Lead__c via Opportunity__c.Lead_Id__c - a plain Text field storing the
    //  Lead's Id (NOT a true lookup/reference field, which is why a schema describe filtered to
    //  DisplayType.REFERENCE never found it - Lead__c.Converted_Opportunity_Id__c, a real lookup,
    //  looked like the right field but is populated on zero records in production; Lead_Id__c on
    //  the Opportunity side is the one that's actually used). Values are cast with Id.valueOf()
    //  inside a try/catch so a blank or malformed value is skipped rather than throwing - an
    //  Opportunity with no valid Lead_Id__c contributes to none of the 3 series, since this chart
    //  is specifically about opportunities that came FROM a prospect.
    //
    //  Bucketing uses Datetime.year()/.month() (the org's local/IST-context time zone), not SOQL's
    //  CALENDAR_YEAR/CALENDAR_MONTH (which evaluate in GMT) - this is the same IST-correct instant
    //  every other chart on this dashboard reaches for quarters via a separate GMT/IST boundary
    //  correction step (see applyIstQuarterBoundaryCorrectionForOpportunity); at month granularity,
    //  reading the already-fetched record's local year()/month() directly gets the same correct
    //  answer with no separate correction pass needed.
    // ============================================================================================
    private static final List<String> OPP_TREND_TEAM_SERIES = new List<String>{ 'Sales Lead', 'Marketing Lead', 'Digital Marketing Leads' };

    // Schema-drift guard: this org's Opportunity__c may not have Lead_Id__c at all (confirmed
    // missing in this sandbox, present in production) - Apex validates typed field access
    // (o.Lead_Id__c) against the COMPILING org's schema regardless of dynamic vs static SOQL, so a
    // direct reference would fail to compile here at all. Checked once via describe (not a typed
    // reference) so this class compiles and deploys cleanly in either org; the field is only ever
    // added to the SELECT list / read via the untyped SObject.get() below when it actually exists,
    // so a Lead_Id__c-less org just sees an empty Opportunity Trend rather than a broken deploy.
    private static final Boolean OPP_LEAD_ID_FIELD_EXISTS = Schema.SObjectType.Opportunity__c.fields.getMap().containsKey('lead_id__c');

    private static String monthPeriodKey(Datetime dt) {
        return dt.year() + '-' + (dt.month() < 10 ? '0' + dt.month() : String.valueOf(dt.month()));
    }

    // Opportunity__c rows matching the active filters, joined to their source Lead__c's Team -
    // shared by the chart, its drill-down, and its full-detail export so all three agree by
    // construction rather than three separate re-derivations of "what does this bar mean".
    private static Map<Id, String> opportunityTrendTeamByOppId(String baseWhere, Map<String, Object> baseBinds, Map<Id, Opportunity__c> oppByIdOut) {
        String selectFields = 'Id, Name, Owner.Name, Zone__c, Country__c, Status__c, CreatedDate' + (OPP_LEAD_ID_FIELD_EXISTS ? ', Lead_Id__c' : '');
        List<Opportunity__c> opps = Database.queryWithBinds(
            'SELECT ' + selectFields + ' FROM Opportunity__c' + baseWhere + ' LIMIT 49000',
            baseBinds,
            AccessLevel.USER_MODE
        );
        for (Opportunity__c o : opps) {
            oppByIdOut.put(o.Id, o);
        }

        Map<Id, String> teamByOppId = new Map<Id, String>();
        if (!OPP_LEAD_ID_FIELD_EXISTS) {
            return teamByOppId;
        }

        Set<Id> leadIds = new Set<Id>();
        Map<Id, Id> leadIdByOppId = new Map<Id, Id>();
        for (Opportunity__c o : opps) {
            Object rawLeadId = o.get('Lead_Id__c');
            String rawLeadIdStr = rawLeadId == null ? null : String.valueOf(rawLeadId).trim();
            if (String.isNotBlank(rawLeadIdStr)) {
                Id leadId;
                try {
                    leadId = Id.valueOf(rawLeadIdStr);
                } catch (Exception e) {
                    leadId = null;
                }
                if (leadId != null) {
                    leadIds.add(leadId);
                    leadIdByOppId.put(o.Id, leadId);
                }
            }
        }

        Map<Id, String> teamByLeadId = new Map<Id, String>();
        if (!leadIds.isEmpty()) {
            for (Lead__c l : [
                SELECT Id, Sales_Marketing_Lead__c
                FROM Lead__c
                WHERE Id IN :leadIds AND Sales_Marketing_Lead__c IN :OPP_TREND_TEAM_SERIES
                LIMIT 49000
            ]) {
                teamByLeadId.put(l.Id, l.Sales_Marketing_Lead__c);
            }
        }

        for (Id oppId : leadIdByOppId.keySet()) {
            String team = teamByLeadId.get(leadIdByOppId.get(oppId));
            if (team != null) {
                teamByOppId.put(oppId, team);
            }
        }
        return teamByOppId;
    }

    private static ChartData getOpportunityTrend(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);

        Map<Id, Opportunity__c> oppById = new Map<Id, Opportunity__c>();
        Map<Id, String> teamByOppId = opportunityTrendTeamByOppId(baseWhere, baseBinds, oppById);

        Map<String, Map<String, Integer>> countsByTeam = new Map<String, Map<String, Integer>>();
        for (String team : OPP_TREND_TEAM_SERIES) {
            countsByTeam.put(team, new Map<String, Integer>());
        }
        Set<String> monthKeySet = new Set<String>();

        for (Id oppId : oppById.keySet()) {
            String team = teamByOppId.get(oppId);
            if (team == null) {
                continue;
            }
            String monthKey = monthPeriodKey(oppById.get(oppId).CreatedDate);
            monthKeySet.add(monthKey);
            Map<String, Integer> counts = countsByTeam.get(team);
            counts.put(monthKey, (counts.containsKey(monthKey) ? counts.get(monthKey) : 0) + 1);
        }

        List<String> monthKeys = new List<String>(monthKeySet);
        monthKeys.sort();

        List<ChartSeries> series = new List<ChartSeries>();
        for (String team : OPP_TREND_TEAM_SERIES) {
            ChartSeries s = new ChartSeries();
            s.label = team;
            s.data = new List<Decimal>();
            Map<String, Integer> counts = countsByTeam.get(team);
            for (String key : monthKeys) {
                s.data.add(counts.containsKey(key) ? counts.get(key) : 0);
            }
            series.add(s);
        }

        ChartData result = new ChartData();
        result.labels = monthKeys;
        result.series = series;
        return result;
    }

    private static List<DrillDownRecord> getOpportunityTrendDrillDownRecords(String seriesLabel, String period, String filtersJson) {
        if (!OPP_TREND_TEAM_SERIES.contains(seriesLabel)) {
            throw new AuraHandledException('Unknown series: ' + seriesLabel);
        }
        List<String> periodParts = period != null ? period.split('-') : new List<String>();
        if (periodParts.size() != 2) {
            throw new AuraHandledException('Unrecognized period: ' + period);
        }
        Integer year = Integer.valueOf(periodParts[0]);
        Integer month = Integer.valueOf(periodParts[1]);

        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);

        Map<Id, Opportunity__c> oppById = new Map<Id, Opportunity__c>();
        Map<Id, String> teamByOppId = opportunityTrendTeamByOppId(baseWhere, baseBinds, oppById);

        List<DrillDownRecord> matched = new List<DrillDownRecord>();
        for (Id oppId : oppById.keySet()) {
            if (teamByOppId.get(oppId) != seriesLabel) {
                continue;
            }
            Opportunity__c rec = oppById.get(oppId);
            if (rec.CreatedDate.year() == year && rec.CreatedDate.month() == month) {
                matched.add(toOpportunityDrillDownRecord(rec, seriesLabel));
            }
        }
        return matched;
    }

    private static List<DrillDownRecord> getOpportunityTrendFullDetail(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);

        Map<Id, Opportunity__c> oppById = new Map<Id, Opportunity__c>();
        Map<Id, String> teamByOppId = opportunityTrendTeamByOppId(baseWhere, baseBinds, oppById);

        List<DrillDownRecord> results = new List<DrillDownRecord>();
        for (Id oppId : oppById.keySet()) {
            String team = teamByOppId.get(oppId);
            if (team != null) {
                Opportunity__c rec = oppById.get(oppId);
                DrillDownRecord dr = toOpportunityDrillDownRecord(rec, team);
                // Whole-chart export convention (see queryOpportunityFullDetail) - matchedVia alone
                // (set above) is enough for a single-bar drill-down, which already has this context
                // from the click itself, but the combined multi-series export needs seriesLabel/
                // period explicitly stamped on every row so it knows which series/period each one
                // belongs to.
                dr.seriesLabel = team;
                dr.period = monthPeriodKey(rec.CreatedDate);
                results.add(dr);
            }
        }
        return results;
    }

    // ============================================================================================
    //  Opportunity to Evaluation Ratio - replaces Prospect to Evaluation Ratio's slot on the
    //  dashboard for Opportunity__c. Two series ("Opportunity" = every Opportunity__c matching the
    //  active filters, "Evaluation" = Actual_Evaluation_Week_Dashboard__c != null), so the existing
    //  2-series ratio rendering in the LWC (a % line + "Overall Evaluation: X%" label) picks it up
    //  automatically, same as every other *ToRatio chart.
    // ============================================================================================
    private static final String OPP_SERIES_EVALUATION = 'Evaluation';

    private static ChartData getOpportunityToEvaluationRatio(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);

        Map<String, Integer> allCounts = queryOpportunityCounts(baseWhere, baseBinds);

        Map<String, Object> evalBinds = baseBinds.clone();
        String evalWhere = appendCondition(baseWhere, 'Actual_Evaluation_Week_Dashboard__c != null');
        Map<String, Integer> evalCounts = queryOpportunityCounts(evalWhere, evalBinds);

        Set<String> allPeriods = new Set<String>();
        allPeriods.addAll(allCounts.keySet());
        allPeriods.addAll(evalCounts.keySet());
        List<String> periodKeys = new List<String>(allPeriods);
        periodKeys.sort();

        ChartSeries oppSeries4 = new ChartSeries();
        oppSeries4.label = 'Opportunity';
        oppSeries4.data = new List<Decimal>();

        ChartSeries evalSeries = new ChartSeries();
        evalSeries.label = OPP_SERIES_EVALUATION;
        evalSeries.data = new List<Decimal>();

        for (String key : periodKeys) {
            oppSeries4.data.add(allCounts.containsKey(key) ? allCounts.get(key) : 0);
            evalSeries.data.add(evalCounts.containsKey(key) ? evalCounts.get(key) : 0);
        }

        ChartData result = new ChartData();
        result.labels = periodKeys;
        result.series = new List<ChartSeries>{ oppSeries4, evalSeries };
        return result;
    }

    private static List<DrillDownRecord> getOpportunityToEvaluationDrillDownRecords(String seriesLabel, String period, String filtersJson) {
        if (seriesLabel != 'Opportunity' && seriesLabel != OPP_SERIES_EVALUATION) {
            throw new AuraHandledException('Unknown series: ' + seriesLabel);
        }

        List<String> periodParts = period != null ? period.split('-') : new List<String>();
        if (periodParts.size() != 2 || !QUARTER_START_MONTH.containsKey(periodParts[1])) {
            throw new AuraHandledException('Unrecognized period: ' + period);
        }
        Integer year = Integer.valueOf(periodParts[0]);
        String quarter = periodParts[1];

        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);
        if (seriesLabel == OPP_SERIES_EVALUATION) {
            baseWhere = appendCondition(baseWhere, 'Actual_Evaluation_Week_Dashboard__c != null');
        }

        return queryOpportunityPartRecords(baseWhere, baseBinds, year, quarter, seriesLabel);
    }

    private static List<DrillDownRecord> getOpportunityToEvaluationFullDetail(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);
        Integer perPartCap = FULL_DETAIL_SINGLE_QUERY_LIMIT / 2;

        List<DrillDownRecord> results = new List<DrillDownRecord>();
        results.addAll(queryOpportunityFullDetail(baseWhere, baseBinds, 'Opportunity', perPartCap));

        Map<String, Object> evalBinds = baseBinds.clone();
        String evalWhere = appendCondition(baseWhere, 'Actual_Evaluation_Week_Dashboard__c != null');
        results.addAll(queryOpportunityFullDetail(evalWhere, evalBinds, OPP_SERIES_EVALUATION, perPartCap));

        return results;
    }

    // ============================================================================================
    //  Opportunity Evaluation to Conversion Ratio - replaces Evaluation to Conversion Ratio's slot
    //  on the dashboard for Opportunity__c. "Evaluation" = Actual_Evaluation_Week_Dashboard__c !=
    //  null. "Total Won Opp from Evaluation Stage" (2026-09: replaces the original "Conversion"
    //  series, which summed Commercialization+Upgrade parts) = Actual_Evaluation_Week_Dashboard__c
    //  != null AND Status__c = 'Closed Won', i.e. opportunities that reached the Evaluation stage
    //  and were ultimately won - a subset of "Evaluation", making this a true conversion ratio.
    // ============================================================================================
    private static final String OPP_SERIES_WON_FROM_EVALUATION = 'Total Won Opp from Evaluation Stage';

    private static ChartData getOpportunityEvaluationToConversionRatio(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);

        Map<String, Object> evalBinds = baseBinds.clone();
        String evalWhere = appendCondition(baseWhere, 'Actual_Evaluation_Week_Dashboard__c != null');
        Map<String, Integer> evalCounts = queryOpportunityCounts(evalWhere, evalBinds);

        Map<String, Object> wonEvalBinds = baseBinds.clone();
        wonEvalBinds.put('oppStatusVal', OPP_STATUS_WON);
        String wonEvalWhere = appendCondition(baseWhere, 'Actual_Evaluation_Week_Dashboard__c != null AND Status__c = :oppStatusVal');
        Map<String, Integer> wonEvalCounts = queryOpportunityCounts(wonEvalWhere, wonEvalBinds);

        Set<String> allPeriods = new Set<String>();
        allPeriods.addAll(evalCounts.keySet());
        allPeriods.addAll(wonEvalCounts.keySet());
        List<String> periodKeys = new List<String>(allPeriods);
        periodKeys.sort();

        ChartSeries evalSeries2 = new ChartSeries();
        evalSeries2.label = OPP_SERIES_EVALUATION;
        evalSeries2.data = new List<Decimal>();

        ChartSeries wonEvalSeries = new ChartSeries();
        wonEvalSeries.label = OPP_SERIES_WON_FROM_EVALUATION;
        wonEvalSeries.data = new List<Decimal>();

        for (String key : periodKeys) {
            evalSeries2.data.add(evalCounts.containsKey(key) ? evalCounts.get(key) : 0);
            wonEvalSeries.data.add(wonEvalCounts.containsKey(key) ? wonEvalCounts.get(key) : 0);
        }

        ChartData result = new ChartData();
        result.labels = periodKeys;
        result.series = new List<ChartSeries>{ evalSeries2, wonEvalSeries };
        return result;
    }

    private static List<DrillDownRecord> getOpportunityEvaluationToConversionDrillDownRecords(String seriesLabel, String period, String filtersJson) {
        if (seriesLabel != OPP_SERIES_EVALUATION && seriesLabel != OPP_SERIES_WON_FROM_EVALUATION) {
            throw new AuraHandledException('Unknown series: ' + seriesLabel);
        }

        List<String> periodParts = period != null ? period.split('-') : new List<String>();
        if (periodParts.size() != 2 || !QUARTER_START_MONTH.containsKey(periodParts[1])) {
            throw new AuraHandledException('Unrecognized period: ' + period);
        }
        Integer year = Integer.valueOf(periodParts[0]);
        String quarter = periodParts[1];

        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);
        if (seriesLabel == OPP_SERIES_EVALUATION) {
            baseWhere = appendCondition(baseWhere, 'Actual_Evaluation_Week_Dashboard__c != null');
        } else if (seriesLabel == OPP_SERIES_WON_FROM_EVALUATION) {
            baseBinds.put('oppStatusVal', OPP_STATUS_WON);
            baseWhere = appendCondition(baseWhere, 'Actual_Evaluation_Week_Dashboard__c != null AND Status__c = :oppStatusVal');
        }

        return queryOpportunityPartRecords(baseWhere, baseBinds, year, quarter, seriesLabel);
    }

    private static List<DrillDownRecord> getOpportunityEvaluationToConversionFullDetail(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);
        Integer perPartCap = FULL_DETAIL_SINGLE_QUERY_LIMIT / 2;

        List<DrillDownRecord> results = new List<DrillDownRecord>();
        String evalWhere = appendCondition(baseWhere, 'Actual_Evaluation_Week_Dashboard__c != null');
        results.addAll(queryOpportunityFullDetail(evalWhere, baseBinds, OPP_SERIES_EVALUATION, perPartCap));

        Map<String, Object> wonEvalBinds = baseBinds.clone();
        wonEvalBinds.put('oppStatusVal', OPP_STATUS_WON);
        String wonEvalWhere = appendCondition(baseWhere, 'Actual_Evaluation_Week_Dashboard__c != null AND Status__c = :oppStatusVal');
        results.addAll(queryOpportunityFullDetail(wonEvalWhere, wonEvalBinds, OPP_SERIES_WON_FROM_EVALUATION, perPartCap));

        return results;
    }

    // ============================================================================================
    //  Expired Opportunity - new chart (not a replacement of an existing slot). "Net Opportunity"
    //  is every Opportunity__c matching the active filters; "Closed Opportunity" is the subset the
    //  org auto-closes without any follow-up 180 days after creation (Opportunity_Closed__c = true)
    //  - per spec, the same field/condition already used as "Untouch" on the Opportunity to Untouch
    //  Ratio chart, just under the "Expired" framing that matches Lead__c's own Expired Prospects
    //  chart (Prospect / Closed (Expired)).
    // ============================================================================================
    private static ChartData getExpiredOpportunity(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);

        Map<String, Integer> allCounts = queryOpportunityCounts(baseWhere, baseBinds);

        Map<String, Object> closedBinds = baseBinds.clone();
        String closedWhere = appendCondition(baseWhere, 'Opportunity_Closed__c = true');
        Map<String, Integer> closedCounts = queryOpportunityCounts(closedWhere, closedBinds);

        Set<String> allPeriods = new Set<String>();
        allPeriods.addAll(allCounts.keySet());
        allPeriods.addAll(closedCounts.keySet());
        List<String> periodKeys = new List<String>(allPeriods);
        periodKeys.sort();

        ChartSeries netSeries = new ChartSeries();
        netSeries.label = 'Net Opportunity';
        netSeries.data = new List<Decimal>();

        ChartSeries closedSeries = new ChartSeries();
        closedSeries.label = 'Closed Opportunity';
        closedSeries.data = new List<Decimal>();

        for (String key : periodKeys) {
            netSeries.data.add(allCounts.containsKey(key) ? allCounts.get(key) : 0);
            closedSeries.data.add(closedCounts.containsKey(key) ? closedCounts.get(key) : 0);
        }

        ChartData result = new ChartData();
        result.labels = periodKeys;
        result.series = new List<ChartSeries>{ netSeries, closedSeries };
        return result;
    }

    private static List<DrillDownRecord> getExpiredOpportunityDrillDownRecords(String seriesLabel, String period, String filtersJson) {
        if (seriesLabel != 'Net Opportunity' && seriesLabel != 'Closed Opportunity') {
            throw new AuraHandledException('Unknown series: ' + seriesLabel);
        }

        List<String> periodParts = period != null ? period.split('-') : new List<String>();
        if (periodParts.size() != 2 || !QUARTER_START_MONTH.containsKey(periodParts[1])) {
            throw new AuraHandledException('Unrecognized period: ' + period);
        }
        Integer year = Integer.valueOf(periodParts[0]);
        String quarter = periodParts[1];

        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);
        if (seriesLabel == 'Closed Opportunity') {
            baseWhere = appendCondition(baseWhere, 'Opportunity_Closed__c = true');
        }

        return queryOpportunityPartRecords(baseWhere, baseBinds, year, quarter, seriesLabel);
    }

    private static List<DrillDownRecord> getExpiredOpportunityFullDetail(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);
        Integer perPartCap = FULL_DETAIL_SINGLE_QUERY_LIMIT / 2;

        List<DrillDownRecord> results = new List<DrillDownRecord>();
        results.addAll(queryOpportunityFullDetail(baseWhere, baseBinds, 'Net Opportunity', perPartCap));

        Map<String, Object> closedBinds = baseBinds.clone();
        String closedWhere = appendCondition(baseWhere, 'Opportunity_Closed__c = true');
        results.addAll(queryOpportunityFullDetail(closedWhere, closedBinds, 'Closed Opportunity', perPartCap));

        return results;
    }

    // ============================================================================================
    //  Overall Reporting Opp - new chart, companion to Overall Reporting (renamed "Overall
    //  Reporting Prospect"). "Opportunity" is every Opportunity__c matching the active filters;
    //  "WIP & Concluded" is Status__c not blank, mirroring Lead__c's own WIP & Concluded series
    //  (Lead_Stage__c not blank) - the direct opposite of the Status__c-blank condition used for
    //  "Untouch"/"No Follow Up Opp" elsewhere on this dashboard.
    // ============================================================================================
    private static ChartData getOverallReportingOpp(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);

        Map<String, Integer> allCounts = queryOpportunityCounts(baseWhere, baseBinds);

        Map<String, Object> wipBinds = baseBinds.clone();
        String wipWhere = appendCondition(baseWhere, 'Status__c != null');
        Map<String, Integer> wipCounts = queryOpportunityCounts(wipWhere, wipBinds);

        Set<String> allPeriods = new Set<String>();
        allPeriods.addAll(allCounts.keySet());
        allPeriods.addAll(wipCounts.keySet());
        List<String> periodKeys = new List<String>(allPeriods);
        periodKeys.sort();

        ChartSeries oppSeries5 = new ChartSeries();
        oppSeries5.label = 'Opportunity';
        oppSeries5.data = new List<Decimal>();

        ChartSeries wipSeries = new ChartSeries();
        wipSeries.label = 'WIP & Concluded';
        wipSeries.data = new List<Decimal>();

        for (String key : periodKeys) {
            oppSeries5.data.add(allCounts.containsKey(key) ? allCounts.get(key) : 0);
            wipSeries.data.add(wipCounts.containsKey(key) ? wipCounts.get(key) : 0);
        }

        ChartData result = new ChartData();
        result.labels = periodKeys;
        result.series = new List<ChartSeries>{ oppSeries5, wipSeries };
        return result;
    }

    private static List<DrillDownRecord> getOverallReportingOppDrillDownRecords(String seriesLabel, String period, String filtersJson) {
        if (seriesLabel != 'Opportunity' && seriesLabel != 'WIP & Concluded') {
            throw new AuraHandledException('Unknown series: ' + seriesLabel);
        }

        List<String> periodParts = period != null ? period.split('-') : new List<String>();
        if (periodParts.size() != 2 || !QUARTER_START_MONTH.containsKey(periodParts[1])) {
            throw new AuraHandledException('Unrecognized period: ' + period);
        }
        Integer year = Integer.valueOf(periodParts[0]);
        String quarter = periodParts[1];

        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);
        if (seriesLabel == 'WIP & Concluded') {
            baseWhere = appendCondition(baseWhere, 'Status__c != null');
        }

        return queryOpportunityPartRecords(baseWhere, baseBinds, year, quarter, seriesLabel);
    }

    private static List<DrillDownRecord> getOverallReportingOppFullDetail(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);
        Integer perPartCap = FULL_DETAIL_SINGLE_QUERY_LIMIT / 2;

        List<DrillDownRecord> results = new List<DrillDownRecord>();
        results.addAll(queryOpportunityFullDetail(baseWhere, baseBinds, 'Opportunity', perPartCap));

        Map<String, Object> wipBinds = baseBinds.clone();
        String wipWhere = appendCondition(baseWhere, 'Status__c != null');
        results.addAll(queryOpportunityFullDetail(wipWhere, wipBinds, 'WIP & Concluded', perPartCap));

        return results;
    }

    private static Map<String, Integer> queryOpportunityCounts(String whereClause, Map<String, Object> binds) {
        Map<String, Integer> counts = new Map<String, Integer>();
        List<AggregateResult> monthCounts = Database.queryWithBinds(
            'SELECT CALENDAR_YEAR(CreatedDate) yr, CALENDAR_MONTH(CreatedDate) mo, COUNT(Id) cnt FROM Opportunity__c' +
                whereClause + ' GROUP BY CALENDAR_YEAR(CreatedDate), CALENDAR_MONTH(CreatedDate)',
            binds,
            AccessLevel.USER_MODE
        );
        for (AggregateResult ar : monthCounts) {
            Object yrObj = ar.get('yr');
            Object moObj = ar.get('mo');
            if (yrObj == null || moObj == null) {
                continue;
            }
            Integer yr = (Integer) yrObj;
            Integer mo = (Integer) moObj;
            String key = yr + '-' + quarterOfMonth(mo);
            Integer cnt = (Integer) ar.get('cnt');
            counts.put(key, (counts.containsKey(key) ? counts.get(key) : 0) + cnt);
        }
        applyIstQuarterBoundaryCorrectionForOpportunity(counts, whereClause, binds);
        return counts;
    }

    // Same reclassification logic/reasoning as applyIstQuarterBoundaryCorrection (see that method's
    // comment for the full explanation), duplicated here only because it targets a different object
    // (Opportunity__c instead of Lead__c) - the platform gives no way to parameterize a SOQL FROM
    // clause, so a literal second copy is the only option short of building a generic query-builder
    // neither chart needs.
    private static void applyIstQuarterBoundaryCorrectionForOpportunity(Map<String, Integer> counts, String whereClause, Map<String, Object> binds) {
        String boundaryWhere = appendCondition(whereClause, QUARTER_END_BOUNDARY_CONDITION);
        List<Opportunity__c> candidates = Database.queryWithBinds(
            'SELECT CreatedDate FROM Opportunity__c' + boundaryWhere,
            binds,
            AccessLevel.USER_MODE
        );
        for (Opportunity__c rec : candidates) {
            Datetime dt = rec.CreatedDate;
            if (dt.monthGmt() == dt.month()) {
                continue;
            }
            String oldKey = dt.yearGmt() + '-' + quarterOfMonth(dt.monthGmt());
            String newKey = dt.year() + '-' + quarterOfMonth(dt.month());
            counts.put(oldKey, (counts.containsKey(oldKey) ? counts.get(oldKey) : 0) - 1);
            counts.put(newKey, (counts.containsKey(newKey) ? counts.get(newKey) : 0) + 1);
        }
    }

    // Record-level visibility scoping (role hierarchy + Lead__Share/Opportunity__Share grants,
    // System Administrator exempt) lives in DashboardVisibilityUtil - shared with
    // HomeSnapshotController so both dashboards resolve visibility identically. See that class for
    // the full explanation of why this exists (OWD is Public Read Only on both objects).
    private static String buildOpportunityWhereClause(FilterRequest filters, Map<String, Object> binds) {
        List<String> conditions = new List<String>();
        if (filters != null) {
            if (filters.zones != null && !filters.zones.isEmpty()) {
                conditions.add('Zone__c IN :oppZones');
                binds.put('oppZones', filters.zones);
            }
            if (filters.countries != null && !filters.countries.isEmpty()) {
                conditions.add('Country__c IN :oppCountries');
                binds.put('oppCountries', filters.countries);
            }
            if (filters.ownerIds != null && !filters.ownerIds.isEmpty()) {
                conditions.add('(OwnerId IN :oppOwnerIds OR RSM__c IN :oppOwnerIds OR ZSM__c IN :oppOwnerIds OR GM_NSM__c IN :oppOwnerIds OR Approval_user__c IN :oppOwnerIds)');
                binds.put('oppOwnerIds', filters.ownerIds);
            }
            // No Sales/Marketing team equivalent on Opportunity__c, so the Team filter simply
            // doesn't narrow this chart - same tolerant approach as any filter with no matching
            // field for a given series.
            String dateCondition = buildOpportunityDateCondition(filters, binds);
            if (String.isNotBlank(dateCondition)) {
                conditions.add(dateCondition);
            }
        }
        String whereClause = conditions.isEmpty() ? '' : ' WHERE ' + String.join(conditions, ' AND ');
        return DashboardVisibilityUtil.applyDashboardVisibility(whereClause, binds, true);
    }

    // Public (not private) so HomeSnapshotController can reuse the exact same date-filtering
    // logic for its own Year/Quarter filters, rather than maintaining a second copy that could
    // drift out of sync.
    public static String buildOpportunityDateCondition(FilterRequest f, Map<String, Object> binds) {
        Boolean hasYears = f.years != null && !f.years.isEmpty();
        Boolean hasWeeks = f.weeks != null && !f.weeks.isEmpty();
        Boolean hasMonths = f.months != null && !f.months.isEmpty();
        Boolean hasQuarters = f.quarters != null && !f.quarters.isEmpty();

        List<Integer> effectiveYears = hasYears
            ? f.years
            : ((hasWeeks || hasMonths || hasQuarters) ? new List<Integer>{ Date.today().year() } : null);

        String yearCondition = null;
        if (effectiveYears != null) {
            binds.put('oppYears', effectiveYears);
            yearCondition = 'CALENDAR_YEAR(CreatedDate) IN :oppYears';
        }

        if (hasWeeks) {
            List<String> weekRanges = new List<String>();
            for (Integer i = 0; i < f.weeks.size(); i++) {
                Integer dayStart = (f.weeks[i] - 1) * 7 + 1;
                Integer dayEnd = f.weeks[i] * 7;
                String startKey = 'oppWeekDayStart' + i;
                String endKey = 'oppWeekDayEnd' + i;
                binds.put(startKey, dayStart);
                binds.put(endKey, dayEnd);
                weekRanges.add('(DAY_IN_YEAR(CreatedDate) >= :' + startKey + ' AND DAY_IN_YEAR(CreatedDate) <= :' + endKey + ')');
            }
            String weekCondition = '(' + String.join(weekRanges, ' OR ') + ')';
            return yearCondition == null ? weekCondition : yearCondition + ' AND ' + weekCondition;
        }

        if (hasMonths) {
            binds.put('oppMonths', f.months);
            String monthCondition = 'CALENDAR_MONTH(CreatedDate) IN :oppMonths';
            return yearCondition == null ? monthCondition : yearCondition + ' AND ' + monthCondition;
        }

        if (hasQuarters) {
            // Opportunity__c has no live quarter formula field, so a quarter label expands to its
            // 3 constituent months and filters on CALENDAR_MONTH directly.
            Set<Integer> quarterMonths = new Set<Integer>();
            for (String q : f.quarters) {
                Integer startMonth = QUARTER_START_MONTH.get(q);
                if (startMonth != null) {
                    quarterMonths.add(startMonth);
                    quarterMonths.add(startMonth + 1);
                    quarterMonths.add(startMonth + 2);
                }
            }
            if (!quarterMonths.isEmpty()) {
                binds.put('oppQuarterMonths', new List<Integer>(quarterMonths));
                String quarterCondition = 'CALENDAR_MONTH(CreatedDate) IN :oppQuarterMonths';
                return yearCondition == null ? quarterCondition : yearCondition + ' AND ' + quarterCondition;
            }
        }

        return yearCondition;
    }

    // Click-through for the Opportunity to Untouch Ratio chart - mirrors getDrillDownRecords/
    // queryPartRecords' nominal+incoming boundary-aware record fetch below (see that method's
    // comment), duplicated in Opportunity__c-specific form for the same reason
    // getOpportunityUntouchRatio's counting logic is: no way to parameterize a SOQL FROM clause.
    // "Opportunity" has no part condition beyond the active filters; "Untouch" adds
    // Status__c = null.
    private static List<DrillDownRecord> getOpportunityDrillDownRecords(String seriesLabel, String period, String filtersJson) {
        if (seriesLabel != 'Opportunity' && seriesLabel != 'Untouch') {
            throw new AuraHandledException('Unknown series: ' + seriesLabel);
        }

        List<String> periodParts = period != null ? period.split('-') : new List<String>();
        if (periodParts.size() != 2 || !QUARTER_START_MONTH.containsKey(periodParts[1])) {
            throw new AuraHandledException('Unrecognized period: ' + period);
        }
        Integer year = Integer.valueOf(periodParts[0]);
        String quarter = periodParts[1];

        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);
        if (seriesLabel == 'Untouch') {
            baseWhere = appendCondition(baseWhere, 'Status__c = null');
        }

        return queryOpportunityPartRecords(baseWhere, baseBinds, year, quarter, seriesLabel);
    }

    private static List<DrillDownRecord> queryOpportunityPartRecords(String baseWhere, Map<String, Object> baseBinds, Integer year, String quarter, String matchedVia) {
        List<DrillDownRecord> matched = new List<DrillDownRecord>();

        Integer startMonth = QUARTER_START_MONTH.get(quarter);
        Map<String, Object> nominalBinds = baseBinds.clone();
        nominalBinds.put('ddYear', year);
        nominalBinds.put('ddMonths', new List<Integer>{ startMonth, startMonth + 1, startMonth + 2 });
        String nominalWhere = appendCondition(
            baseWhere,
            'CALENDAR_YEAR(CreatedDate) = :ddYear AND CALENDAR_MONTH(CreatedDate) IN :ddMonths'
        );
        List<Opportunity__c> nominal = Database.queryWithBinds(
            'SELECT Id, Name, Owner.Name, Zone__c, Country__c, Status__c, CreatedDate FROM Opportunity__c' +
                nominalWhere + ' LIMIT ' + DRILL_DOWN_LIMIT,
            nominalBinds,
            AccessLevel.USER_MODE
        );
        Integer lastMonthOfQuarter = startMonth + 2;
        Integer lastDayOfQuarter = (lastMonthOfQuarter == 6 || lastMonthOfQuarter == 9) ? 30 : 31;
        for (Opportunity__c rec : nominal) {
            Datetime dt = rec.CreatedDate;
            Boolean onOwnBoundaryDay = dt.monthGmt() == lastMonthOfQuarter && dt.dayGmt() == lastDayOfQuarter && dt.hourGmt() >= 18;
            Boolean shiftsToNextQuarter = onOwnBoundaryDay && dt.month() != dt.monthGmt();
            if (!shiftsToNextQuarter) {
                matched.add(toOpportunityDrillDownRecord(rec, matchedVia));
            }
        }

        Integer precedingMonth = startMonth - 1;
        Integer precedingYear = year;
        if (precedingMonth == 0) {
            precedingMonth = 12;
            precedingYear = year - 1;
        }
        Integer precedingLastDay = (precedingMonth == 6 || precedingMonth == 9) ? 30 : 31;
        Map<String, Object> incomingBinds = baseBinds.clone();
        incomingBinds.put('ddPrecedingYear', precedingYear);
        incomingBinds.put('ddPrecedingMonth', precedingMonth);
        incomingBinds.put('ddPrecedingDay', precedingLastDay);
        String incomingWhere = appendCondition(
            baseWhere,
            'CALENDAR_YEAR(CreatedDate) = :ddPrecedingYear AND CALENDAR_MONTH(CreatedDate) = :ddPrecedingMonth ' +
            'AND DAY_IN_MONTH(CreatedDate) = :ddPrecedingDay AND HOUR_IN_DAY(CreatedDate) >= 18'
        );
        List<Opportunity__c> incoming = Database.queryWithBinds(
            'SELECT Id, Name, Owner.Name, Zone__c, Country__c, Status__c, CreatedDate FROM Opportunity__c' +
                incomingWhere + ' LIMIT ' + DRILL_DOWN_LIMIT,
            incomingBinds,
            AccessLevel.USER_MODE
        );
        for (Opportunity__c rec : incoming) {
            if (rec.CreatedDate.month() != rec.CreatedDate.monthGmt()) {
                matched.add(toOpportunityDrillDownRecord(rec, matchedVia));
            }
        }

        return matched;
    }

    private static DrillDownRecord toOpportunityDrillDownRecord(Opportunity__c rec, String matchedVia) {
        DrillDownRecord dr = new DrillDownRecord();
        dr.recordId = rec.Id;
        dr.name = rec.Name;
        dr.ownerName = rec.Owner != null ? rec.Owner.Name : null;
        dr.zone = rec.Zone__c;
        dr.country = rec.Country__c;
        dr.stage = rec.Status__c;
        dr.matchedVia = matchedVia;
        dr.createdDate = rec.CreatedDate == null ? null : rec.CreatedDate.format('dd-MMM-yyyy hh:mm a');
        return dr;
    }

    // Per-chart-part safety cap, matched to the same reasoning as getFilterOptions' LIMIT 49000 -
    // the busiest single quarter/series combination seen on this dashboard is under 4,000, so this
    // is generous headroom rather than an expected ceiling, and keeps a single bar click bounded
    // regardless of future data growth.
    private static final Integer DRILL_DOWN_LIMIT = 10000;

    // Click-through for a single bar: returns every record that fed into it, so a person looking
    // at "3,228" on the chart can see exactly which 3,228 leads that is. Reuses chartDefinitions()
    // and appendPartCondition() - the same series/part logic getChartData sums into that number -
    // rather than re-deriving "what does this bar mean" a second way that could drift out of sync
    // with the chart itself.
    @AuraEnabled
    public static List<DrillDownRecord> getDrillDownRecords(String chartKey, String seriesLabel, String period, String filtersJson) {
        if (chartKey == 'opportunityToUntouchRatio') {
            return getOpportunityDrillDownRecords(seriesLabel, period, filtersJson);
        }
        if (chartKey == 'opportunityEndToEndVisibility') {
            return getOpportunityEndToEndDrillDownRecords(seriesLabel, period, filtersJson);
        }
        if (chartKey == 'opportunityTrend') {
            return getOpportunityTrendDrillDownRecords(seriesLabel, period, filtersJson);
        }
        if (chartKey == 'opportunityToEvaluationRatio') {
            return getOpportunityToEvaluationDrillDownRecords(seriesLabel, period, filtersJson);
        }
        if (chartKey == 'opportunityEvaluationToConversionRatio') {
            return getOpportunityEvaluationToConversionDrillDownRecords(seriesLabel, period, filtersJson);
        }
        if (chartKey == 'expiredOpportunity') {
            return getExpiredOpportunityDrillDownRecords(seriesLabel, period, filtersJson);
        }
        if (chartKey == 'overallReportingOpp') {
            return getOverallReportingOppDrillDownRecords(seriesLabel, period, filtersJson);
        }
        if (chartKey == 'expiredProspects') {
            return getExpiredProspectsDrillDownRecords(seriesLabel, period, filtersJson);
        }
        if (chartKey == 'inClinicTarget') {
            return getInClinicTargetActivitiesDrillDownRecords(seriesLabel, period, filtersJson);
        }
        if (chartKey == 'marketingTarget') {
            return getMarketingTargetCampaignMembersDrillDownRecords(seriesLabel, period, filtersJson);
        }

        FilterRequest filters = parseFilters(filtersJson);
        ChartDef def = chartDefinitions().get(chartKey);
        if (def == null) {
            throw new AuraHandledException('Unknown chart: ' + chartKey);
        }

        SeriesDef series = null;
        for (SeriesDef sd : def.series) {
            if (sd.label == seriesLabel) {
                series = sd;
                break;
            }
        }
        if (series == null) {
            throw new AuraHandledException('Unknown series: ' + seriesLabel);
        }

        List<String> periodParts = period != null ? period.split('-') : new List<String>();
        if (periodParts.size() != 2 || !QUARTER_START_MONTH.containsKey(periodParts[1])) {
            throw new AuraHandledException('Unrecognized period: ' + period);
        }
        Integer year = Integer.valueOf(periodParts[0]);
        String quarter = periodParts[1];

        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildWhereClause(filters, baseBinds);

        // A multi-part series (e.g. Conversion = Commercialization + Upgrade) is a SUM on the
        // chart - a lead with both dates set in the same quarter is counted once per part there -
        // so it's listed once per matching part here too, each tagged with which part it matched
        // via, keeping this list's row count equal to the number shown on the bar.
        List<DrillDownRecord> results = new List<DrillDownRecord>();
        for (SeriesPart part : series.parts) {
            results.addAll(queryPartRecords(part, baseWhere, baseBinds, year, quarter));
        }
        return results;
    }

    private static String appendCondition(String existingClause, String condition) {
        return String.isBlank(existingClause) ? ' WHERE ' + condition : existingClause + ' AND ' + condition;
    }

    private static String partMatchLabel(SeriesPart part) {
        if (part.partType == SeriesPartType.ACTUAL_DATE) {
            if (part.weekNumberField == 'Actual_Commercialization_Week_Dashboard__c') {
                return 'Actual Commercialization';
            }
            if (part.weekNumberField == 'Actual_Upgrade_Week_Dashboard__c') {
                return 'Actual Upgrade';
            }
            if (part.weekNumberField == 'Actual_Evaluation_Week_Dashboard__c') {
                return 'Actual Evaluation';
            }
            return part.weekNumberField;
        }
        if (part.partType == SeriesPartType.STAGE_EQUALS) {
            return 'Stage = ' + part.stageValue;
        }
        if (part.partType == SeriesPartType.STAGE_NOT_EQUALS) {
            return 'Stage != ' + part.stageValue;
        }
        if (part.partType == SeriesPartType.STAGE_IS_BLANK) {
            return 'No Stage';
        }
        if (part.partType == SeriesPartType.STAGE_IS_NOT_BLANK) {
            return 'Has Stage';
        }
        if (part.partType == SeriesPartType.IS_CLOSED) {
            return 'Closed';
        }
        return 'All';
    }

    private static DrillDownRecord toDrillDownRecord(Lead__c rec, String matchedVia) {
        DrillDownRecord dr = new DrillDownRecord();
        dr.recordId = rec.Id;
        dr.name = rec.Name;
        dr.ownerName = rec.Owner != null ? rec.Owner.Name : null;
        dr.zone = rec.Zone__c;
        dr.country = rec.Country__c;
        dr.stage = rec.Lead_Stage__c;
        dr.sapCode = rec.SAP_Code__c;
        dr.matchedVia = matchedVia;
        dr.createdDate = rec.CreatedDate == null ? null : rec.CreatedDate.format('dd-MMM-yyyy hh:mm a');
        dr.ceCisRating = rec.CE_CIS_Rating__c;
        dr.phakicRating = rec.Phakic_Rating__c;
        dr.actualAppointmentsWeek = rec.Actual_Appointments_Week__c == null ? null : rec.Actual_Appointments_Week__c.format();
        dr.convertedDate = rec.Converted_Date__c;
        dr.unqualifiedDate = rec.Unqualified_Date__c;
        return dr;
    }

    // Fetches the actual records behind one SeriesPart for one quarter, applying the same
    // GMT->IST quarter-boundary correction queryPartCounts/applyIstQuarterBoundaryCorrection apply
    // to the counts, so this list's size always matches the number on the bar exactly:
    // - "nominal" candidates are the 3 GMT calendar months of the requested quarter; any of those
    //   created on that quarter's own last day past 6pm GMT actually belong to the NEXT quarter
    //   locally (IST) and are excluded here (they surface when that next quarter is drilled into).
    // - "incoming" candidates are records created on the immediately PRECEDING quarter's last GMT
    //   day past 6pm GMT whose local date lands in THIS quarter - the mirror image, added in.
    // Both boundary checks query only the exact day/hour window that can possibly be affected, not
    // a whole extra month, so this stays cheap no matter how large Lead__c grows.
    private static List<DrillDownRecord> queryPartRecords(SeriesPart part, String baseWhere, Map<String, Object> baseBinds, Integer year, String quarter) {
        String matchedVia = partMatchLabel(part);
        List<DrillDownRecord> matched = new List<DrillDownRecord>();

        Integer startMonth = QUARTER_START_MONTH.get(quarter);
        Map<String, Object> nominalBinds = baseBinds.clone();
        String nominalSeriesWhere = appendPartCondition(baseWhere, part, nominalBinds);
        nominalBinds.put('ddYear', year);
        nominalBinds.put('ddMonths', new List<Integer>{ startMonth, startMonth + 1, startMonth + 2 });
        String nominalWhere = appendCondition(
            nominalSeriesWhere,
            'CALENDAR_YEAR(CreatedDate) = :ddYear AND CALENDAR_MONTH(CreatedDate) IN :ddMonths'
        );
        List<Lead__c> nominal = Database.queryWithBinds(
            'SELECT Id, Name, Owner.Name, Zone__c, Country__c, Lead_Stage__c, SAP_Code__c, CreatedDate, ' +
                'CE_CIS_Rating__c, Phakic_Rating__c, Actual_Appointments_Week__c, Converted_Date__c, Unqualified_Date__c FROM Lead__c' +
                nominalWhere + ' LIMIT ' + DRILL_DOWN_LIMIT,
            nominalBinds,
            AccessLevel.USER_MODE
        );
        // Only exclude a nominal-bucket record if it's actually ON the quarter's own last day
        // (last month of the quarter, last day of that month, 6pm+ GMT) AND its local date lands
        // in a different month than its GMT date - i.e. a real quarter-boundary shift. A record
        // created e.g. July 31st late at night GMT, whose local date rolls into August 1st, is
        // still squarely inside Q3 either way (July and August are both Q3) and must NOT be
        // excluded just because month() != monthGmt() - that earlier, broader check excluded every
        // month-end shift in the quarter, not just the one that actually crosses a quarter
        // boundary, silently dropping legitimate records.
        Integer lastMonthOfQuarter = startMonth + 2;
        Integer lastDayOfQuarter = (lastMonthOfQuarter == 6 || lastMonthOfQuarter == 9) ? 30 : 31;
        for (Lead__c rec : nominal) {
            Datetime dt = rec.CreatedDate;
            Boolean onOwnBoundaryDay = dt.monthGmt() == lastMonthOfQuarter && dt.dayGmt() == lastDayOfQuarter && dt.hourGmt() >= 18;
            Boolean shiftsToNextQuarter = onOwnBoundaryDay && dt.month() != dt.monthGmt();
            if (!shiftsToNextQuarter) {
                matched.add(toDrillDownRecord(rec, matchedVia));
            }
        }

        Integer precedingMonth = startMonth - 1;
        Integer precedingYear = year;
        if (precedingMonth == 0) {
            precedingMonth = 12;
            precedingYear = year - 1;
        }
        Integer precedingLastDay = (precedingMonth == 6 || precedingMonth == 9) ? 30 : 31;
        Map<String, Object> incomingBinds = baseBinds.clone();
        String incomingSeriesWhere = appendPartCondition(baseWhere, part, incomingBinds);
        incomingBinds.put('ddPrecedingYear', precedingYear);
        incomingBinds.put('ddPrecedingMonth', precedingMonth);
        incomingBinds.put('ddPrecedingDay', precedingLastDay);
        String incomingWhere = appendCondition(
            incomingSeriesWhere,
            'CALENDAR_YEAR(CreatedDate) = :ddPrecedingYear AND CALENDAR_MONTH(CreatedDate) = :ddPrecedingMonth ' +
            'AND DAY_IN_MONTH(CreatedDate) = :ddPrecedingDay AND HOUR_IN_DAY(CreatedDate) >= 18'
        );
        List<Lead__c> incoming = Database.queryWithBinds(
            'SELECT Id, Name, Owner.Name, Zone__c, Country__c, Lead_Stage__c, SAP_Code__c, CreatedDate, ' +
                'CE_CIS_Rating__c, Phakic_Rating__c, Actual_Appointments_Week__c, Converted_Date__c, Unqualified_Date__c FROM Lead__c' +
                incomingWhere + ' LIMIT ' + DRILL_DOWN_LIMIT,
            incomingBinds,
            AccessLevel.USER_MODE
        );
        for (Lead__c rec : incoming) {
            if (rec.CreatedDate.month() != rec.CreatedDate.monthGmt()) {
                matched.add(toDrillDownRecord(rec, matchedVia));
            }
        }

        return matched;
    }

    // Total row budget for one getChartFullDetail call, divided across however many parts the
    // requested chart actually has (2 for most charts, up to 5 for End to End Visibility) so
    // every part gets a fair, as-large-as-possible share of the shared 50,000-row-per-transaction
    // governor limit, with headroom left for the COUNT() check each part also runs (see below).
    private static final Integer FULL_DETAIL_BUDGET = 45000;
    private static final Integer FULL_DETAIL_MIN_PER_PART = 5000;
    // getProductFamilyFullDetail runs a single query (not summed across up to 5 parts like the
    // time-series charts' export), so it can safely use a much larger share of the same budget on
    // its own.
    private static final Integer FULL_DETAIL_SINGLE_QUERY_LIMIT = 40000;

    // Whole-chart "deep dive" export: every record behind every bar in the chart, not just one -
    // unlike getDrillDownRecords, this isn't scoped to a single quarter, so the GMT->IST
    // quarter-boundary correction that needs a candidate query per quarter doesn't apply here;
    // each record's own period is simply computed directly from its local (IST) CreatedDate,
    // which is what that correction converges to anyway.
    //
    // A part whose true match count exceeds its share of the budget is NOT silently truncated -
    // each part is counted first (a cheap aggregate query, not counted against the row budget),
    // and if the count exceeds what will be fetched, a synthetic warning row is added ahead of
    // that part's records so whoever opens the export sees it plainly rather than assuming the
    // file is complete when it isn't.
    @AuraEnabled
    public static List<DrillDownRecord> getChartFullDetail(String chartKey, String filtersJson) {
        if (chartKey == 'opportunityToUntouchRatio') {
            return getOpportunityFullDetail(filtersJson);
        }
        if (chartKey == 'opportunityEndToEndVisibility') {
            return getOpportunityEndToEndFullDetail(filtersJson);
        }
        if (chartKey == 'opportunityTrend') {
            return getOpportunityTrendFullDetail(filtersJson);
        }
        if (chartKey == 'opportunityToEvaluationRatio') {
            return getOpportunityToEvaluationFullDetail(filtersJson);
        }
        if (chartKey == 'opportunityEvaluationToConversionRatio') {
            return getOpportunityEvaluationToConversionFullDetail(filtersJson);
        }
        if (chartKey == 'expiredOpportunity') {
            return getExpiredOpportunityFullDetail(filtersJson);
        }
        if (chartKey == 'overallReportingOpp') {
            return getOverallReportingOppFullDetail(filtersJson);
        }
        if (chartKey == 'expiredProspects') {
            return getExpiredProspectsFullDetail(filtersJson);
        }
        if (chartKey == 'inClinicTarget') {
            return getInClinicTargetActivitiesFullDetail(filtersJson);
        }
        if (chartKey == 'marketingTarget') {
            return getMarketingTargetCampaignMembersFullDetail(filtersJson);
        }

        ChartDef def = chartDefinitions().get(chartKey);
        if (def == null) {
            throw new AuraHandledException('Unknown chart: ' + chartKey);
        }

        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildWhereClause(filters, baseBinds);

        Integer totalParts = 0;
        for (SeriesDef series : def.series) {
            totalParts += series.parts.size();
        }
        Integer perPartCap = Math.max(FULL_DETAIL_MIN_PER_PART, FULL_DETAIL_BUDGET / Math.max(1, totalParts));

        List<DrillDownRecord> results = new List<DrillDownRecord>();
        for (SeriesDef series : def.series) {
            for (SeriesPart part : series.parts) {
                results.addAll(queryPartFullDetail(part, baseWhere, baseBinds, series.label, perPartCap));
            }
        }
        return results;
    }

    private static DrillDownRecord truncationWarning(String seriesLabel, String matchedVia, Integer shown, Integer trueCount) {
        DrillDownRecord dr = new DrillDownRecord();
        dr.name =
            'TRUNCATED: showing ' + shown + ' of ' + trueCount + ' matching records for this series - ' +
            'narrow the dashboard filters (e.g. select a Year) and re-download for complete data.';
        dr.seriesLabel = seriesLabel;
        dr.matchedVia = matchedVia;
        return dr;
    }

    private static List<DrillDownRecord> queryPartFullDetail(SeriesPart part, String baseWhere, Map<String, Object> baseBinds, String seriesLabel, Integer cap) {
        Map<String, Object> binds = baseBinds.clone();
        String whereClause = appendPartCondition(baseWhere, part, binds);
        String matchedVia = partMatchLabel(part);

        AggregateResult countResult = (AggregateResult) Database.queryWithBinds(
            'SELECT COUNT(Id) cnt FROM Lead__c' + whereClause,
            binds,
            AccessLevel.USER_MODE
        )[0];
        Integer trueCount = (Integer) countResult.get('cnt');

        List<Lead__c> recs = Database.queryWithBinds(
            'SELECT Id, Name, Owner.Name, Zone__c, Country__c, Lead_Stage__c, SAP_Code__c, CreatedDate, ' +
                'CE_CIS_Rating__c, Phakic_Rating__c, Actual_Appointments_Week__c, Converted_Date__c, Unqualified_Date__c FROM Lead__c' +
                whereClause + ' LIMIT ' + cap,
            binds,
            AccessLevel.USER_MODE
        );

        List<DrillDownRecord> out = new List<DrillDownRecord>();
        if (trueCount > recs.size()) {
            out.add(truncationWarning(seriesLabel, matchedVia, recs.size(), trueCount));
        }
        for (Lead__c rec : recs) {
            DrillDownRecord dr = toDrillDownRecord(rec, matchedVia);
            dr.seriesLabel = seriesLabel;
            dr.period = rec.CreatedDate == null ? null : (rec.CreatedDate.year() + '-' + quarterOfMonth(rec.CreatedDate.month()));
            out.add(dr);
        }
        return out;
    }

    private static List<DrillDownRecord> getOpportunityFullDetail(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> baseBinds = new Map<String, Object>();
        String baseWhere = buildOpportunityWhereClause(filters, baseBinds);

        List<DrillDownRecord> results = new List<DrillDownRecord>();
        results.addAll(queryOpportunityFullDetail(baseWhere, baseBinds, 'Opportunity', FULL_DETAIL_SINGLE_QUERY_LIMIT / 2));

        Map<String, Object> untouchBinds = baseBinds.clone();
        String untouchWhere = appendCondition(baseWhere, 'Status__c = null');
        results.addAll(queryOpportunityFullDetail(untouchWhere, untouchBinds, 'Untouch', FULL_DETAIL_SINGLE_QUERY_LIMIT / 2));

        return results;
    }

    private static List<DrillDownRecord> queryOpportunityFullDetail(String whereClause, Map<String, Object> binds, String seriesLabel, Integer cap) {
        AggregateResult countResult = (AggregateResult) Database.queryWithBinds(
            'SELECT COUNT(Id) cnt FROM Opportunity__c' + whereClause,
            binds,
            AccessLevel.USER_MODE
        )[0];
        Integer trueCount = (Integer) countResult.get('cnt');

        List<Opportunity__c> recs = Database.queryWithBinds(
            'SELECT Id, Name, Owner.Name, Zone__c, Country__c, Status__c, CreatedDate FROM Opportunity__c' +
                whereClause + ' LIMIT ' + cap,
            binds,
            AccessLevel.USER_MODE
        );
        List<DrillDownRecord> out = new List<DrillDownRecord>();
        if (trueCount > recs.size()) {
            out.add(truncationWarning(seriesLabel, seriesLabel, recs.size(), trueCount));
        }
        for (Opportunity__c rec : recs) {
            DrillDownRecord dr = toOpportunityDrillDownRecord(rec, seriesLabel);
            dr.seriesLabel = seriesLabel;
            dr.period = rec.CreatedDate == null ? null : (rec.CreatedDate.year() + '-' + quarterOfMonth(rec.CreatedDate.month()));
            out.add(dr);
        }
        return out;
    }

    // Lead_Created_Quarter_No__c is not groupable in SOQL (platform restriction on this formula
    // field). Grouping by CALENDAR_YEAR/CALENDAR_MONTH instead keeps this an aggregate COUNT()
    // query - at most ~12 rows per year no matter how large Lead__c grows - rather than fetching
    // every matching record, which previously risked (and, once Lead__c grew past 50,000 matching
    // rows, would have hit) the SOQL query-row governor limit. Month-level counts are then bucketed
    // into quarters below, using quarterOfMonth's calendar-quarter convention (matches
    // Lead_Created_Quarter_No__c's production formula: Q1=Jan-Mar ... Q4=Oct-Dec).
    //
    // Every part - STAGE_* and ACTUAL_DATE alike - is bucketed by CreatedDate, not by an
    // ACTUAL_DATE part's own milestone date (2026-09 correction). "Count of actual evaluation week
    // number" means: for the quarter a lead was created in, count it if that part's condition
    // (e.g. its week-number Dashboard field being non-null) holds - not re-bucket it into whatever
    // quarter the milestone itself landed in. Bucketing by the milestone's own date instead put a
    // lead's Evaluation count in a different quarter than its Prospect count, breaking every ratio
    // chart's quarter-to-quarter comparison and disagreeing with the certified reports.
    private static Map<String, Integer> queryPartCounts(SeriesPart part, String baseWhere, Map<String, Object> baseBinds) {
        Map<String, Object> binds = baseBinds.clone();
        String seriesWhere = appendPartCondition(baseWhere, part, binds);

        List<AggregateResult> monthCounts = Database.queryWithBinds(
            'SELECT CALENDAR_YEAR(CreatedDate) yr, CALENDAR_MONTH(CreatedDate) mo, COUNT(Id) cnt FROM Lead__c' +
                seriesWhere + ' GROUP BY CALENDAR_YEAR(CreatedDate), CALENDAR_MONTH(CreatedDate)',
            binds,
            AccessLevel.USER_MODE
        );

        Map<String, Integer> counts = new Map<String, Integer>();
        for (AggregateResult ar : monthCounts) {
            Object yrObj = ar.get('yr');
            Object moObj = ar.get('mo');
            if (yrObj == null || moObj == null) {
                continue;
            }
            Integer yr = (Integer) yrObj;
            Integer mo = (Integer) moObj;
            String key = yr + '-' + quarterOfMonth(mo);
            Integer cnt = (Integer) ar.get('cnt');
            counts.put(key, (counts.containsKey(key) ? counts.get(key) : 0) + cnt);
        }
        applyIstQuarterBoundaryCorrection(counts, seriesWhere, binds);
        return counts;
    }

    // CALENDAR_YEAR/CALENDAR_MONTH evaluate CreatedDate in GMT, but Lead_Created_Quarter_No__c's
    // DATEVALUE(CreatedDate) evaluates in the context user's local time zone (confirmed empirically:
    // Datetime.month()/.day()/.year() with no suffix already return the CONTEXT USER's local time
    // zone value - Asia/Kolkata for this org - while .monthGmt()/.dayGmt()/.yearGmt() return GMT;
    // a record created 2026-06-30 18:36 GMT reads as July 1st locally). A lead created 2026-06-30
    // late evening GMT (past midnight IST, so July 1st locally) is put in Q3 by the formula field
    // but Q2 by the GROUP BY above (2026-09 correction). This only matters for leads created on the
    // LAST day of a quarter-end month (Mar 31/Jun 30/Sep 30/Dec 31) in the evening GMT - the window
    // where a positive local-time offset (like IST's +5:30) can push a lead into the next day, and
    // therefore the next quarter. That window is narrow enough to query directly (a handful of
    // records per quarter-end date per year, not the whole table), so this re-checks just those
    // candidates - comparing each record's local vs. GMT month using the SAME context-user time
    // zone the formula field uses, no hardcoded offset needed - and moves any that actually land on
    // a different local date from whichever GMT-based bucket they landed in above into the correct one.
    private static final String QUARTER_END_BOUNDARY_CONDITION =
        '((CALENDAR_MONTH(CreatedDate) = 3 AND DAY_IN_MONTH(CreatedDate) = 31) OR ' +
        '(CALENDAR_MONTH(CreatedDate) = 6 AND DAY_IN_MONTH(CreatedDate) = 30) OR ' +
        '(CALENDAR_MONTH(CreatedDate) = 9 AND DAY_IN_MONTH(CreatedDate) = 30) OR ' +
        '(CALENDAR_MONTH(CreatedDate) = 12 AND DAY_IN_MONTH(CreatedDate) = 31)) AND HOUR_IN_DAY(CreatedDate) >= 18';

    private static void applyIstQuarterBoundaryCorrection(Map<String, Integer> counts, String seriesWhere, Map<String, Object> binds) {
        String boundaryWhere = String.isBlank(seriesWhere)
            ? ' WHERE ' + QUARTER_END_BOUNDARY_CONDITION
            : seriesWhere + ' AND ' + QUARTER_END_BOUNDARY_CONDITION;
        List<Lead__c> candidates = Database.queryWithBinds(
            'SELECT CreatedDate FROM Lead__c' + boundaryWhere,
            binds,
            AccessLevel.USER_MODE
        );

        for (Lead__c rec : candidates) {
            Datetime dt = rec.CreatedDate;
            if (dt.monthGmt() == dt.month()) {
                continue;
            }

            String oldKey = dt.yearGmt() + '-' + quarterOfMonth(dt.monthGmt());
            String newKey = dt.year() + '-' + quarterOfMonth(dt.month());
            counts.put(oldKey, (counts.containsKey(oldKey) ? counts.get(oldKey) : 0) - 1);
            counts.put(newKey, (counts.containsKey(newKey) ? counts.get(newKey) : 0) + 1);
        }
    }

    private static String appendPartCondition(String baseWhere, SeriesPart part, Map<String, Object> binds) {
        String condition;
        if (part.partType == SeriesPartType.STAGE_ALL) {
            return baseWhere;
        } else if (part.partType == SeriesPartType.STAGE_EQUALS) {
            binds.put('stageVal', part.stageValue);
            condition = 'Lead_Stage__c = :stageVal';
        } else if (part.partType == SeriesPartType.STAGE_NOT_EQUALS) {
            binds.put('stageVal', part.stageValue);
            condition = 'Lead_Stage__c != :stageVal';
        } else if (part.partType == SeriesPartType.STAGE_IS_BLANK) {
            condition = 'Lead_Stage__c = null';
        } else if (part.partType == SeriesPartType.STAGE_IS_NOT_BLANK) {
            condition = 'Lead_Stage__c != null';
        } else if (part.partType == SeriesPartType.IS_CLOSED) {
            condition = 'Lead_Closed__c = true';
        } else {
            // Whether a record counts in this part at all is decided by the Actual_*_Week_Dashboard__c
            // field (see actualDate above) being non-null - kept in sync with the formula field it
            // mirrors by the Lead_Sync_Actual_Week_Numbers flow for every record touched from here
            // on, and populated manually for records that already existed before that field was
            // created.
            condition = part.weekNumberField + ' != null';
        }
        return String.isBlank(baseWhere) ? ' WHERE ' + condition : baseWhere + ' AND ' + condition;
    }

    private static String partCacheKey(SeriesPart part) {
        return part.partType.name() + '|' + part.stageValue + '|' + part.weekNumberField;
    }

    private class DateRange {
        Date startDate;
        Date endDate;
    }

    // Calendar-year quarters (Q1=Jan-Mar, Q2=Apr-Jun, Q3=Jul-Sep, Q4=Oct-Dec) - matches
    // Lead_Created_Quarter_No__c's PRODUCTION formula exactly (confirmed 2026-09; sandbox's copy
    // of that formula field had drifted to a fiscal-year version - Q1=Apr-Jun - which this
    // dashboard briefly matched before the drift was caught. Production is the source of truth,
    // so this reverts to calendar quarters, and sandbox's Lead_Created_Quarter_No__c formula was
    // corrected to match production too (see that field's own history for the sandbox-only fix).
    private static final Map<String, Integer> QUARTER_START_MONTH = new Map<String, Integer>{
        'Q1' => 1, 'Q2' => 4, 'Q3' => 7, 'Q4' => 10
    };

    private static String quarterOfMonth(Integer month) {
        if (month >= 1 && month <= 3) {
            return 'Q1';
        } else if (month >= 4 && month <= 6) {
            return 'Q2';
        } else if (month >= 7 && month <= 9) {
            return 'Q3';
        }
        return 'Q4';
    }

    // Cascading/dynamic filter options: each of Zone, Country, and Owner is narrowed by whichever
    // of the OTHER two (plus Team/Year/Quarter/Month/Week) are currently selected - but never by
    // its own selection, so e.g. picking Country=India narrows the Owner list to India-relevant
    // people without the Owner dropdown collapsing to just whatever is already selected there.
    // Implemented as a single table scan (not one query per dropdown, and not one query per
    // exclusion combination) with the cascading logic done in Apex over that one result set -
    // this is deliberate: separate GROUP BY queries per dropdown were what caused the 50,000-row
    // SOQL limit earlier in this org (see getChartData's comment for the same lesson).
    // Owner options list ONLY literal record owners (OwnerId on Lead__c and Opportunity__c) - per
    // explicit request, RSM__c/ZSM__c/GM_NSM__c/Approval_user__c (Approval Tracker reviewers, not
    // record owners) are deliberately excluded from the dropdown even though the real Owner filter
    // still matches against all five fields (see buildWhereClause/buildOpportunityWhereClause) -
    // so a name picked here can still surface records where that person is a reviewer, not just an
    // owner, but the dropdown itself only advertises actual owners.
    // All filters are now multi-select: each of zones/countries/ownerIds narrows on set
    // membership (IN-style) rather than single-value equality.
    @AuraEnabled
    public static FilterOptions getFilterOptions(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        FilterOptions opts = new FilterOptions();

        // Lead__c and Opportunity__c are now BOTH scanned in this one call (Opportunity__c added
        // so the Owner dropdown can include real Opportunity owners too - see below), so the old
        // single-query LIMIT 49000 would let the two scans total up to 98,000 rows and blow the
        // 50,000-row-per-transaction governor limit. Split the budget across both instead, leaving
        // headroom for the owner Name lookups that run after. Lead__c gets the larger share since
        // it's consistently the higher-volume object in this org.
        Integer leadScanCap = 33000;
        Integer oppScanCap = 15000;

        Map<String, Object> binds = new Map<String, Object>();
        String baseWhere = buildNonCascadingWhereClause(filters, binds);

        List<Lead__c> rows = Database.queryWithBinds(
            'SELECT Zone__c, Country__c, OwnerId, RSM__c, ZSM__c, GM_NSM__c, Approval_user__c FROM Lead__c' + baseWhere + ' LIMIT ' + leadScanCap,
            binds,
            AccessLevel.USER_MODE
        );

        Set<String> zoneFilter = toSet(filters.zones);
        Set<String> countryFilter = toSet(filters.countries);
        Set<String> ownerFilter = toSet(filters.ownerIds);

        Boolean hasZone = !zoneFilter.isEmpty();
        Boolean hasCountry = !countryFilter.isEmpty();
        Boolean hasOwner = !ownerFilter.isEmpty();

        Set<String> zoneSet = new Set<String>();
        Set<String> countrySet = new Set<String>();
        Set<Id> ownerIdSet = new Set<Id>();

        for (Lead__c rec : rows) {
            Boolean matchesZone = !hasZone || zoneFilter.contains(rec.Zone__c);
            Boolean matchesCountry = !hasCountry || countryFilter.contains(rec.Country__c);
            Boolean matchesOwner = !hasOwner || matchesAnyOwnerRoleField(rec, ownerFilter);

            // Zone options narrowed by Country + Owner, not by Zone's own selection.
            if (matchesCountry && matchesOwner && String.isNotBlank(rec.Zone__c)) {
                zoneSet.add(rec.Zone__c);
            }
            // Country options narrowed by Zone + Owner, not by Country's own selection.
            if (matchesZone && matchesOwner && String.isNotBlank(rec.Country__c)) {
                countrySet.add(rec.Country__c);
            }
            // Owner options narrowed by Zone + Country, not by Owner's own selection. Literal
            // OwnerId only - see comment above getFilterOptions for why RSM__c/ZSM__c/GM_NSM__c/
            // Approval_user__c (reviewers, not owners) are excluded here.
            if (matchesZone && matchesCountry && rec.OwnerId != null) {
                ownerIdSet.add(rec.OwnerId);
            }
        }

        Map<String, Object> oppBinds = new Map<String, Object>();
        String oppBaseWhere = buildOpportunityNonCascadingWhereClause(filters, oppBinds);
        List<Opportunity__c> oppRows = Database.queryWithBinds(
            'SELECT Zone__c, Country__c, OwnerId FROM Opportunity__c' + oppBaseWhere + ' LIMIT ' + oppScanCap,
            oppBinds,
            AccessLevel.USER_MODE
        );
        for (Opportunity__c orec : oppRows) {
            Boolean oMatchesZone = !hasZone || zoneFilter.contains(orec.Zone__c);
            Boolean oMatchesCountry = !hasCountry || countryFilter.contains(orec.Country__c);
            Boolean oMatchesOwner = !hasOwner || (orec.OwnerId != null && ownerFilter.contains(orec.OwnerId));

            if (oMatchesCountry && oMatchesOwner && String.isNotBlank(orec.Zone__c)) {
                zoneSet.add(orec.Zone__c);
            }
            if (oMatchesZone && oMatchesOwner && String.isNotBlank(orec.Country__c)) {
                countrySet.add(orec.Country__c);
            }
            if (oMatchesZone && oMatchesCountry && orec.OwnerId != null) {
                ownerIdSet.add(orec.OwnerId);
            }
        }

        opts.zones = new List<String>(zoneSet);
        opts.zones.sort();

        Map<String, String> countryLabelByValue = countryPicklistLabelByValue();
        opts.countries = new List<CountryOption>();
        for (String rawValue : countrySet) {
            CountryOption co = new CountryOption();
            co.value = rawValue;
            co.label = countryLabelByValue.containsKey(rawValue.toUpperCase()) ? countryLabelByValue.get(rawValue.toUpperCase()) : rawValue;
            opts.countries.add(co);
        }
        opts.countries.sort();

        // Year enabled: a fixed range from EARLIEST_YEAR through the current year, newest first -
        // NOT derived from actual Lead__c data. A data-driven "distinct years present" list (the
        // original approach here) only shows years this specific org/sandbox happens to have
        // CreatedDate rows for; a sandbox refreshed/seeded in 2022, for instance, would only ever
        // offer 2022 onward even though production has real history back to 2018. A fixed range
        // guarantees the full expected span shows up everywhere, even where the data doesn't (yet)
        // back it. Not narrowed by the other cascading dropdowns (same as before Year was
        // disabled) - only Zone/Country/Owner cascade against each other above.
        opts.years = new List<Integer>();
        Integer currentYear = Date.today().year();
        for (Integer y = currentYear; y >= EARLIEST_YEAR; y--) {
            opts.years.add(y);
        }

        opts.owners = new List<OwnerOption>();
        if (!ownerIdSet.isEmpty()) {
            Map<Id, String> idToName = new Map<Id, String>();
            for (User u : (List<User>) Database.queryWithBinds(
                'SELECT Id, Name FROM User WHERE Id IN :ownerIdSet',
                new Map<String, Object>{ 'ownerIdSet' => ownerIdSet },
                AccessLevel.USER_MODE
            )) {
                idToName.put(u.Id, u.Name);
            }
            for (Group g : (List<Group>) Database.queryWithBinds(
                'SELECT Id, Name FROM Group WHERE Id IN :ownerIdSet',
                new Map<String, Object>{ 'ownerIdSet' => ownerIdSet },
                AccessLevel.USER_MODE
            )) {
                idToName.put(g.Id, g.Name);
            }
            for (Id ownerId : ownerIdSet) {
                OwnerOption o = new OwnerOption();
                o.id = ownerId;
                o.name = idToName.containsKey(ownerId) ? idToName.get(ownerId) : String.valueOf(ownerId);
                opts.owners.add(o);
            }
            opts.owners.sort();
        }

        return opts;
    }

    private static Boolean matchesAnyOwnerRoleField(Lead__c rec, Set<String> ownerIds) {
        return (rec.OwnerId != null && ownerIds.contains(rec.OwnerId))
            || (rec.RSM__c != null && ownerIds.contains(rec.RSM__c))
            || (rec.ZSM__c != null && ownerIds.contains(rec.ZSM__c))
            || (rec.GM_NSM__c != null && ownerIds.contains(rec.GM_NSM__c))
            || (rec.Approval_user__c != null && ownerIds.contains(rec.Approval_user__c));
    }

    private static Set<String> toSet(List<String> values) {
        return values == null ? new Set<String>() : new Set<String>(values);
    }

    // Lead__c.Country__c is the only picklist-typed Country field in this org (Opportunity__c's
    // Country__c is plain Text, storing the same raw values as Lead__c's) - so its picklist
    // metadata is the single source of truth for API-value -> label mapping used by both objects.
    // Keyed by uppercased API value since picklist API values are case-sensitive as stored but
    // this makes the lookup tolerant of any casing drift between the two objects' raw values.
    private static Map<String, String> countryPicklistLabelByValue() {
        Map<String, String> labelByValue = new Map<String, String>();
        for (Schema.PicklistEntry entry : Lead__c.Country__c.getDescribe().getPicklistValues()) {
            labelByValue.put(entry.getValue().toUpperCase(), entry.getLabel());
        }
        return labelByValue;
    }

    // Team/Year/Quarter/Month/Week narrow the base scan up front for all three cascading
    // dropdowns alike (nobody asked for those to cascade against each other); Zone/Country/Owner
    // are deliberately excluded here since getFilterOptions applies each of those individually,
    // per dropdown, over the resulting rows instead.
    private static String buildNonCascadingWhereClause(FilterRequest filters, Map<String, Object> binds) {
        List<String> conditions = new List<String>();

        if (filters != null) {
            if (filters.teams != null && !filters.teams.isEmpty()) {
                conditions.add('Sales_Marketing_Lead__c IN :teams');
                binds.put('teams', filters.teams);
            }

            String dateCondition = buildDateCondition(filters, binds);
            if (String.isNotBlank(dateCondition)) {
                conditions.add(dateCondition);
            }
        }

        String whereClause = conditions.isEmpty() ? '' : ' WHERE ' + String.join(conditions, ' AND ');
        return DashboardVisibilityUtil.applyDashboardVisibility(whereClause, binds, false);
    }

    // Opportunity__c equivalent of buildNonCascadingWhereClause, used only by getFilterOptions to
    // pull Opportunity owners into the Owner dropdown. No Team condition (Opportunity__c has no
    // Sales_Marketing_Lead__c-equivalent field) - date handling goes through
    // buildOpportunityDateCondition, which is already Quarter-safe for Opportunity__c (expands a
    // quarter to its 3 months via CALENDAR_MONTH rather than the Lead-only
    // Lead_Created_Quarter_No__c formula field).
    private static String buildOpportunityNonCascadingWhereClause(FilterRequest filters, Map<String, Object> binds) {
        List<String> conditions = new List<String>();

        if (filters != null) {
            String dateCondition = buildOpportunityDateCondition(filters, binds);
            if (String.isNotBlank(dateCondition)) {
                conditions.add(dateCondition);
            }
        }

        String whereClause = conditions.isEmpty() ? '' : ' WHERE ' + String.join(conditions, ' AND ');
        return DashboardVisibilityUtil.applyDashboardVisibility(whereClause, binds, true);
    }

    // See getChartData for why filters arrives as a JSON string here instead of FilterRequest directly.
    @AuraEnabled
    public static KpiSummary getKpiSummary(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> binds = new Map<String, Object>();
        String whereClause = buildWhereClause(filters, binds);

        List<AggregateResult> results = Database.queryWithBinds(
            'SELECT Lead_Stage__c stage, COUNT(Id) cnt FROM Lead__c' + whereClause + ' GROUP BY Lead_Stage__c',
            binds,
            AccessLevel.USER_MODE
        );

        Integer total = 0;
        Integer won = 0;
        Integer lost = 0;
        Integer unqualified = 0;
        Integer noFollowUp = 0;
        for (AggregateResult ar : results) {
            String stage = (String) ar.get('stage');
            Integer cnt = (Integer) ar.get('cnt');
            total += cnt;
            if (stage == 'Won') {
                won = cnt;
            } else if (stage == 'Lost') {
                lost = cnt;
            } else if (stage == 'Unqualified') {
                unqualified = cnt;
            } else if (stage == null) {
                noFollowUp = cnt;
            }
        }

        // Prospects Closed means system-closed - Lead_Closed__c = true, the same flag the Expired
        // Prospects chart uses (records the org auto-closes after 180 days of inactivity) - not
        // Won + Lost. A record can be Won or Lost without being auto-closed yet, and vice versa, so
        // this is a separate query against a separate condition rather than derived from the
        // Lead_Stage__c breakdown above (2026-08 review).
        Map<String, Object> closedBinds = binds.clone();
        String closedWhere = String.isBlank(whereClause) ? ' WHERE Lead_Closed__c = true' : whereClause + ' AND Lead_Closed__c = true';
        AggregateResult closedResult = (AggregateResult) Database.queryWithBinds(
            'SELECT COUNT(Id) cnt FROM Lead__c' + closedWhere,
            closedBinds,
            AccessLevel.USER_MODE
        )[0];
        Integer closed = (Integer) closedResult.get('cnt');

        KpiSummary summary = new KpiSummary();
        summary.totalProspects = total;
        summary.wonProspects = won;
        summary.lostProspects = lost;
        summary.unqualifiedProspects = unqualified;
        summary.netProspects = total - unqualified;
        summary.noFollowUpProspects = noFollowUp;
        summary.prospectsClosed = closed;

        Decimal safeTotal = total == 0 ? 1 : total;
        summary.unqualifiedPct = percentOf(unqualified, safeTotal);
        summary.netPct = percentOf(summary.netProspects, safeTotal);
        summary.wonPct = percentOf(won, safeTotal);
        summary.lostPct = percentOf(lost, safeTotal);
        summary.noFollowUpPct = percentOf(noFollowUp, safeTotal);
        summary.closedPct = percentOf(summary.prospectsClosed, safeTotal);

        // Opportunity Untouch - same filters (Zone/Country/Owner/Year/Quarter/Month/Week), same
        // Status__c blank condition as the Opportunity to Untouch Ratio chart (2026-09 correction),
        // kept consistent with that chart's own query builder (buildOpportunityWhereClause) rather
        // than re-deriving the condition a second way.
        Map<String, Object> oppBinds = new Map<String, Object>();
        String oppWhere = buildOpportunityWhereClause(filters, oppBinds);
        AggregateResult oppTotalResult = (AggregateResult) Database.queryWithBinds(
            'SELECT COUNT(Id) cnt FROM Opportunity__c' + oppWhere,
            oppBinds,
            AccessLevel.USER_MODE
        )[0];
        Integer oppTotal = (Integer) oppTotalResult.get('cnt');

        Decimal safeOppTotal = oppTotal == 0 ? 1 : oppTotal;

        Map<String, Object> oppUntouchBinds = oppBinds.clone();
        String oppUntouchWhere = appendCondition(oppWhere, 'Status__c = null');
        AggregateResult oppUntouchResult = (AggregateResult) Database.queryWithBinds(
            'SELECT COUNT(Id) cnt FROM Opportunity__c' + oppUntouchWhere,
            oppUntouchBinds,
            AccessLevel.USER_MODE
        )[0];
        summary.opportunityUntouchCount = (Integer) oppUntouchResult.get('cnt');
        summary.opportunityUntouchPct = percentOf(summary.opportunityUntouchCount, safeOppTotal);

        // Opp Count / Won Opp / Lost Opp / Expired Opp tiles - Won/Lost read off the same
        // Status__c breakdown the Opportunity End to End Visibility chart uses (OPP_STATUS_WON/
        // OPP_STATUS_LOST); Expired reuses the same Opportunity_Closed__c = true condition as the
        // Expired Opportunity chart's "Closed Opportunity" series.
        summary.oppCount = oppTotal;

        List<AggregateResult> oppStatusResults = Database.queryWithBinds(
            'SELECT Status__c st, COUNT(Id) cnt FROM Opportunity__c' + oppWhere + ' GROUP BY Status__c',
            oppBinds,
            AccessLevel.USER_MODE
        );
        Integer wonOpp = 0;
        Integer lostOpp = 0;
        for (AggregateResult ar : oppStatusResults) {
            String st = (String) ar.get('st');
            Integer cnt = (Integer) ar.get('cnt');
            if (st == OPP_STATUS_WON) {
                wonOpp = cnt;
            } else if (st == OPP_STATUS_LOST) {
                lostOpp = cnt;
            }
        }
        summary.wonOpp = wonOpp;
        summary.lostOpp = lostOpp;
        summary.wonOppPct = percentOf(wonOpp, safeOppTotal);
        summary.lostOppPct = percentOf(lostOpp, safeOppTotal);

        Map<String, Object> oppExpiredBinds = oppBinds.clone();
        String oppExpiredWhere = appendCondition(oppWhere, 'Opportunity_Closed__c = true');
        AggregateResult oppExpiredResult = (AggregateResult) Database.queryWithBinds(
            'SELECT COUNT(Id) cnt FROM Opportunity__c' + oppExpiredWhere,
            oppExpiredBinds,
            AccessLevel.USER_MODE
        )[0];
        summary.expiredOpp = (Integer) oppExpiredResult.get('cnt');
        summary.expiredOppPct = percentOf(summary.expiredOpp, safeOppTotal);

        summary.uniqueFamilyProspects = uniqueLeadsByNameAndFamily(filters).size();

        return summary;
    }

    // ============================================================================================
    //  Product Family x Stage breakdown - a fundamentally different chart shape from every other
    //  chart on this dashboard: categorized by Product_Family__c (not bucketed by time), with one
    //  series per Lead_Stage__c value rather than 1-3 fixed series. Reuses ChartData/ChartSeries
    //  purely as a convenient, already-defined {labels, series} wire shape - not because this
    //  chart shares any of getChartData's time-bucketing/part-summing logic, which doesn't apply
    //  to a categorical axis.
    //
    //  Families are sorted by total record count, descending, with "(No Product Family)" always
    //  forced to the END regardless of its own total - in this org the overwhelming majority of
    //  leads (roughly 96% in sandbox) have no Product Family set, so sorting it purely by volume
    //  would put that catch-all bucket first and bury every real product family after it. Stages
    //  are alphabetical, with the blank-stage bucket ("No Stage") likewise forced last - it's a
    //  catch-all too, not a real pipeline stage.
    // ============================================================================================
    private static final String NO_PRODUCT_FAMILY_LABEL = '(No Product Family)';
    private static final String NO_STAGE_LABEL = 'No Stage';

    // Only currently-active Lead_Stage__c picklist values should ever appear on this chart -
    // records still carrying a stage value that's since been deactivated (leftover from before the
    // picklist was trimmed down to Appointments/Unqualified/Converted) are excluded entirely rather
    // than showing up as a stale bar nobody recognizes. Read live from the picklist metadata
    // (not hardcoded) so this stays correct if the active stage set changes again later.
    private static List<String> activeLeadStageValues() {
        List<String> values = new List<String>();
        for (Schema.PicklistEntry entry : Lead__c.Lead_Stage__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                values.add(entry.getValue());
            }
        }
        return values;
    }

    private class FamilyTotal implements Comparable {
        String family;
        Integer total;
        FamilyTotal(String family, Integer total) {
            this.family = family;
            this.total = total;
        }
        // Descending by total, so List.sort() (ascending by compareTo) puts the largest first.
        public Integer compareTo(Object other) {
            FamilyTotal o = (FamilyTotal) other;
            return total == o.total ? 0 : (total < o.total ? 1 : -1);
        }
    }

    // Shared by the Product Family chart and the "Unique Family Prospects" KPI tile - collapses to
    // one Lead__c per distinct (Name, Product Family) pair (blank family folds into the same
    // "(No Product Family)" bucket the chart displays) rather than counting every record, so two
    // leads both named "A" under the same product family count once, not twice. Whichever of a
    // duplicate pair the query returns first is kept (its Lead_Stage__c decides which stage bucket
    // the pair's one count lands in) - stage is deliberately NOT part of the dedup key, since a
    // prospect only ever carries one current stage, so this is a simplicity/safety choice, not a
    // meaningful behavioral one. Restricted to active Lead_Stage__c picklist values, same as the
    // chart's own filter, for consistency between the two.
    private static Map<String, Lead__c> uniqueLeadsByNameAndFamily(FilterRequest filters) {
        Map<String, Object> binds = new Map<String, Object>();
        String whereClause = buildWhereClause(filters, binds);
        whereClause = appendCondition(whereClause, '(Lead_Stage__c IN :activeStages OR Lead_Stage__c = null)');
        binds.put('activeStages', activeLeadStageValues());

        List<Lead__c> recs = Database.queryWithBinds(
            'SELECT Name, Product_Family__c, Lead_Stage__c FROM Lead__c' +
                whereClause + ' LIMIT ' + FULL_DETAIL_SINGLE_QUERY_LIMIT,
            binds,
            AccessLevel.USER_MODE
        );

        Map<String, Lead__c> uniqueRecs = new Map<String, Lead__c>();
        for (Lead__c rec : recs) {
            String familyKey = String.isBlank(rec.Product_Family__c) ? NO_PRODUCT_FAMILY_LABEL : rec.Product_Family__c;
            String dedupKey = (rec.Name == null ? '' : rec.Name) + ' ' + familyKey;
            if (!uniqueRecs.containsKey(dedupKey)) {
                uniqueRecs.put(dedupKey, rec);
            }
        }
        return uniqueRecs;
    }

    @AuraEnabled
    public static ChartData getProductFamilyStageBreakdown(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Lead__c> uniqueRecs = uniqueLeadsByNameAndFamily(filters);

        Map<String, Integer> familyTotals = new Map<String, Integer>();
        Map<String, Map<String, Integer>> countsByFamilyStage = new Map<String, Map<String, Integer>>();
        Set<String> stageSet = new Set<String>();

        for (Lead__c rec : uniqueRecs.values()) {
            String familyKey = String.isBlank(rec.Product_Family__c) ? NO_PRODUCT_FAMILY_LABEL : rec.Product_Family__c;
            String stageKey = String.isBlank(rec.Lead_Stage__c) ? NO_STAGE_LABEL : rec.Lead_Stage__c;

            stageSet.add(stageKey);
            familyTotals.put(familyKey, (familyTotals.containsKey(familyKey) ? familyTotals.get(familyKey) : 0) + 1);

            Map<String, Integer> byStage = countsByFamilyStage.get(familyKey);
            if (byStage == null) {
                byStage = new Map<String, Integer>();
                countsByFamilyStage.put(familyKey, byStage);
            }
            byStage.put(stageKey, (byStage.containsKey(stageKey) ? byStage.get(stageKey) : 0) + 1);
        }

        List<FamilyTotal> sortableFamilies = new List<FamilyTotal>();
        for (String family : familyTotals.keySet()) {
            if (family != NO_PRODUCT_FAMILY_LABEL) {
                sortableFamilies.add(new FamilyTotal(family, familyTotals.get(family)));
            }
        }
        sortableFamilies.sort();
        List<String> families = new List<String>();
        for (FamilyTotal ft : sortableFamilies) {
            families.add(ft.family);
        }
        if (familyTotals.containsKey(NO_PRODUCT_FAMILY_LABEL)) {
            families.add(NO_PRODUCT_FAMILY_LABEL);
        }

        List<String> stages = new List<String>(stageSet);
        stages.sort();
        Integer noStageIndex = stages.indexOf(NO_STAGE_LABEL);
        if (noStageIndex >= 0) {
            stages.remove(noStageIndex);
            stages.add(NO_STAGE_LABEL);
        }

        ChartData result = new ChartData();
        result.labels = families;
        result.series = new List<ChartSeries>();
        for (String stage : stages) {
            ChartSeries cs = new ChartSeries();
            cs.label = stage;
            cs.data = new List<Decimal>();
            for (String family : families) {
                Map<String, Integer> byStage = countsByFamilyStage.get(family);
                Integer cnt = (byStage != null && byStage.containsKey(stage)) ? byStage.get(stage) : 0;
                cs.data.add(cnt);
            }
            result.series.add(cs);
        }
        return result;
    }

    // "Deep dive" export for the Product Family chart - every matching record, with its own
    // Product Family and Stage visible as plain columns (seriesLabel/matchedVia aren't a natural
    // fit here, since this chart isn't built from chartDefinitions() parts - period is included
    // anyway, for consistency with the other charts' detail export and because "when was this
    // lead created" is still useful context on a categorical chart).
    @AuraEnabled
    public static List<DrillDownRecord> getProductFamilyFullDetail(String filtersJson) {
        FilterRequest filters = parseFilters(filtersJson);
        Map<String, Object> binds = new Map<String, Object>();
        String whereClause = buildWhereClause(filters, binds);
        whereClause = appendCondition(whereClause, '(Lead_Stage__c IN :activeStages OR Lead_Stage__c = null)');
        binds.put('activeStages', activeLeadStageValues());

        List<Lead__c> recs = Database.queryWithBinds(
            'SELECT Id, Name, Owner.Name, Zone__c, Country__c, Product_Family__c, Lead_Stage__c, SAP_Code__c, CreatedDate, ' +
                'CE_CIS_Rating__c, Phakic_Rating__c, Actual_Appointments_Week__c, Converted_Date__c, Unqualified_Date__c FROM Lead__c' +
                whereClause + ' LIMIT ' + FULL_DETAIL_SINGLE_QUERY_LIMIT,
            binds,
            AccessLevel.USER_MODE
        );

        List<DrillDownRecord> out = new List<DrillDownRecord>();
        for (Lead__c rec : recs) {
            DrillDownRecord dr = toDrillDownRecord(rec, String.isBlank(rec.Product_Family__c) ? NO_PRODUCT_FAMILY_LABEL : rec.Product_Family__c);
            dr.seriesLabel = String.isBlank(rec.Lead_Stage__c) ? NO_STAGE_LABEL : rec.Lead_Stage__c;
            dr.period = rec.CreatedDate == null ? null : (rec.CreatedDate.year() + '-' + quarterOfMonth(rec.CreatedDate.month()));
            out.add(dr);
        }
        return out;
    }

    private static FilterRequest parseFilters(String filtersJson) {
        if (String.isBlank(filtersJson)) {
            return new FilterRequest();
        }
        return (FilterRequest) JSON.deserialize(filtersJson, FilterRequest.class);
    }

    private static Decimal percentOf(Integer part, Decimal total) {
        return (Decimal.valueOf(part) * 100 / total).setScale(2);
    }

    private static String buildWhereClause(FilterRequest filters, Map<String, Object> binds) {
        List<String> conditions = new List<String>();

        if (filters != null) {
            if (filters.zones != null && !filters.zones.isEmpty()) {
                conditions.add('Zone__c IN :zones');
                binds.put('zones', filters.zones);
            }
            if (filters.countries != null && !filters.countries.isEmpty()) {
                conditions.add('Country__c IN :countries');
                binds.put('countries', filters.countries);
            }
            if (filters.ownerIds != null && !filters.ownerIds.isEmpty()) {
                // Matches every role any of the selected users plays on a lead, not just literal
                // ownership: the Approval Tracker (RSM -> ZSM -> GM/NSM) stores each stage's
                // assigned reviewer directly on the record via these four User lookups, which is
                // the real mechanism behind "this lead is assigned to a higher-level employee who
                // isn't the owner" - not Salesforce's sharing tables, which route through
                // GuestUserGroup records tied to an external-facing approval site rather than real
                // internal employees.
                conditions.add('(OwnerId IN :ownerIds OR RSM__c IN :ownerIds OR ZSM__c IN :ownerIds OR GM_NSM__c IN :ownerIds OR Approval_user__c IN :ownerIds)');
                binds.put('ownerIds', filters.ownerIds);
            }
            if (filters.teams != null && !filters.teams.isEmpty()) {
                conditions.add('Sales_Marketing_Lead__c IN :teams');
                binds.put('teams', filters.teams);
            }

            String dateCondition = buildDateCondition(filters, binds);
            if (String.isNotBlank(dateCondition)) {
                conditions.add(dateCondition);
            }
        }

        String whereClause = conditions.isEmpty() ? '' : ' WHERE ' + String.join(conditions, ' AND ');
        return DashboardVisibilityUtil.applyDashboardVisibility(whereClause, binds, false);
    }

    // Earliest year offered in the Year filter's fixed range (see getFilterOptions above).
    private static final Integer EARLIEST_YEAR = 2018;

    // Year combines with Quarter/Month/Week (AND) rather than being overridden by it: Year
    // narrows which year(s) to include, Quarter/Month/Week narrows within those years - same
    // "combine" relationship Period used to have with Quarter/Month/Week (see the commented-out
    // resolveDateRange below). If Quarter/Month/Week is selected without an explicit Year, this
    // defaults to the current year only, mirroring the old default of "current year when Period
    // isn't set", rather than matching that Quarter/Month/Week across every year the org has data
    // for. Whichever of Week/Month/Quarter is most granular wins if more than one is selected
    // (Week > Month > Quarter > Year-only > no filter) - the same precedence the old single-select
    // logic used, now evaluated over sets of values instead of one value each.
    //
    // Returns a SOQL condition string (using CALENDAR_YEAR/CALENDAR_MONTH/DAY_IN_YEAR date
    // functions, which SOQL allows in WHERE clauses) rather than a single contiguous DateRange,
    // because a multi-select Week list needs an OR of non-contiguous day-of-year ranges - a shape
    // a single start/end pair can't express.
    // Public (not private) - see buildOpportunityDateCondition's comment above.
    public static String buildDateCondition(FilterRequest f, Map<String, Object> binds) {
        Boolean hasYears = f.years != null && !f.years.isEmpty();
        Boolean hasWeeks = f.weeks != null && !f.weeks.isEmpty();
        Boolean hasMonths = f.months != null && !f.months.isEmpty();
        Boolean hasQuarters = f.quarters != null && !f.quarters.isEmpty();

        List<Integer> effectiveYears = hasYears
            ? f.years
            : ((hasWeeks || hasMonths || hasQuarters) ? new List<Integer>{ Date.today().year() } : null);

        String yearCondition = null;
        if (effectiveYears != null) {
            binds.put('years', effectiveYears);
            yearCondition = 'CALENDAR_YEAR(CreatedDate) IN :years';
        }

        if (hasWeeks) {
            // Same week definition as the old single-select logic: week N covers day-of-year
            // ((N-1)*7 + 1) through (N*7), anchored to Jan 1 - not ISO/locale week numbering.
            List<String> weekRanges = new List<String>();
            for (Integer i = 0; i < f.weeks.size(); i++) {
                Integer dayStart = (f.weeks[i] - 1) * 7 + 1;
                Integer dayEnd = f.weeks[i] * 7;
                String startKey = 'weekDayStart' + i;
                String endKey = 'weekDayEnd' + i;
                binds.put(startKey, dayStart);
                binds.put(endKey, dayEnd);
                weekRanges.add('(DAY_IN_YEAR(CreatedDate) >= :' + startKey + ' AND DAY_IN_YEAR(CreatedDate) <= :' + endKey + ')');
            }
            String weekCondition = '(' + String.join(weekRanges, ' OR ') + ')';
            return yearCondition == null ? weekCondition : yearCondition + ' AND ' + weekCondition;
        }

        if (hasMonths) {
            binds.put('months', f.months);
            String monthCondition = 'CALENDAR_MONTH(CreatedDate) IN :months';
            return yearCondition == null ? monthCondition : yearCondition + ' AND ' + monthCondition;
        }

        if (hasQuarters) {
            // Filters directly on the Lead_Created_Quarter_No__c FORMULA field, not the
            // Lead_Created_Quarter_Dashboard__c stored copy (2026-09 correction). Formula fields
            // are only restricted from GROUP BY, not from WHERE/IN filtering - so there was never a
            // platform reason to go through the stored copy here, and the stored copy can silently
            // go stale (it did). The formula field's DATEVALUE(CreatedDate) evaluates in the org's
            // local time zone (IST), which is also now what queryPartCounts' quarter bucketing
            // corrects itself to match (see IST_OFFSET_MINUTES below) - both sides agree on IST,
            // not GMT, so a lead created late at night IST near a quarter boundary lands in the
            // same quarter whether you filter by it or just look at which bar it's drawn under.
            binds.put('quarters', f.quarters);
            String quarterCondition = 'Lead_Created_Quarter_No__c IN :quarters';
            return yearCondition == null ? quarterCondition : yearCondition + ' AND ' + quarterCondition;
        }

        // Period disabled per request - previously contributed a preset date range (This/Last
        // Year/Quarter/Month, Last 7/30 Days) when no Quarter/Month/Week was selected, and
        // determined which year Quarter/Month/Week combined with otherwise. Kept here, commented
        // out, so it can be restored later if Period returns to the UI.
        // if (String.isNotBlank(f.period) && f.period != 'All') {
        //     DateRange range = resolvePeriodPreset(f.period, Date.today());
        //     if (range != null) {
        //         binds.put('rangeStart', range.startDate);
        //         binds.put('rangeEnd', range.endDate);
        //         return 'CreatedDate >= :rangeStart AND CreatedDate < :rangeEnd';
        //     }
        // }

        return yearCondition;
    }

    // --- Period filter logic (disabled per request, kept for future re-use) ---------------------
    // This trio (resolveDateRange, resolveEffectiveYear, resolvePeriodPreset) was the active
    // single-select date-resolution logic before Year became multi-select and took over as the
    // primary time filter. buildDateCondition above is the active replacement. Uncomment and wire
    // resolveDateRange back into buildWhereClause/buildNonCascadingWhereClause (in place of
    // buildDateCondition) if Period needs to return to the UI.
    //
    // private static DateRange resolveDateRange(FilterRequest f) {
    //     Date today = Date.today();
    //     Boolean hasQuarterMonthWeek = f.week != null
    //         || f.month != null
    //         || (String.isNotBlank(f.quarter) && f.quarter != 'All' && QUARTER_START_MONTH.containsKey(f.quarter));
    //
    //     // Period alone (no Quarter/Month/Week refinement) uses its own preset range directly.
    //     if (String.isNotBlank(f.period) && f.period != 'All' && !hasQuarterMonthWeek) {
    //         return resolvePeriodPreset(f.period, today);
    //     }
    //
    //     // Period combines with Quarter/Month/Week rather than being overridden by it: Period
    //     // contributes which YEAR to use (e.g. "Last Year" + "Q2" means Q2 of last year, not this
    //     // year), and Quarter/Month/Week narrows to the specific slice within that year. Year
    //     // filter itself is disabled for now, so with no Period set this defaults to the current
    //     // year (see resolveEffectiveYear).
    //     Integer y = resolveEffectiveYear(f.period, today);
    //
    //     if (f.week != null) {
    //         Date jan1 = Date.newInstance(y, 1, 1);
    //         Date weekStart = jan1.addDays((f.week - 1) * 7);
    //         DateRange r = new DateRange();
    //         r.startDate = weekStart;
    //         r.endDate = weekStart.addDays(7);
    //         return r;
    //     }
    //
    //     if (f.month != null) {
    //         DateRange r = new DateRange();
    //         r.startDate = Date.newInstance(y, f.month, 1);
    //         r.endDate = r.startDate.addMonths(1);
    //         return r;
    //     }
    //
    //     if (String.isNotBlank(f.quarter) && f.quarter != 'All' && QUARTER_START_MONTH.containsKey(f.quarter)) {
    //         DateRange r = new DateRange();
    //         r.startDate = Date.newInstance(y, QUARTER_START_MONTH.get(f.quarter), 1);
    //         r.endDate = r.startDate.addMonths(3);
    //         return r;
    //     }
    //
    //     return null;
    // }
    //
    // // Determines which calendar year a Period preset implies, so Quarter/Month/Week can be
    // // narrowed within the correct year when combined with Period (e.g. "Last Quarter" selected in
    // // January means a quarter that falls in the previous year).
    // private static Integer resolveEffectiveYear(String period, Date today) {
    //     if (String.isBlank(period) || period == 'All') {
    //         return today.year();
    //     }
    //     if (period == 'LastYear') {
    //         return today.year() - 1;
    //     }
    //     if (period == 'LastQuarter') {
    //         Integer qStartMonth = ((today.month() - 1) / 3) * 3 + 1;
    //         Date thisQStart = Date.newInstance(today.year(), qStartMonth, 1);
    //         return thisQStart.addMonths(-3).year();
    //     }
    //     if (period == 'LastMonth') {
    //         Date thisMonthStart = Date.newInstance(today.year(), today.month(), 1);
    //         return thisMonthStart.addMonths(-1).year();
    //     }
    //     // ThisYear, ThisQuarter, ThisMonth, Last7Days, Last30Days all anchor to the current year.
    //     return today.year();
    // }
    //
    // private static DateRange resolvePeriodPreset(String period, Date today) {
    //     DateRange r = new DateRange();
    //     if (period == 'ThisYear') {
    //         r.startDate = Date.newInstance(today.year(), 1, 1);
    //         r.endDate = r.startDate.addYears(1);
    //     } else if (period == 'LastYear') {
    //         r.startDate = Date.newInstance(today.year() - 1, 1, 1);
    //         r.endDate = Date.newInstance(today.year(), 1, 1);
    //     } else if (period == 'ThisQuarter') {
    //         Integer qStartMonth = ((today.month() - 1) / 3) * 3 + 1;
    //         r.startDate = Date.newInstance(today.year(), qStartMonth, 1);
    //         r.endDate = r.startDate.addMonths(3);
    //     } else if (period == 'LastQuarter') {
    //         Integer qStartMonth = ((today.month() - 1) / 3) * 3 + 1;
    //         Date thisQStart = Date.newInstance(today.year(), qStartMonth, 1);
    //         r.endDate = thisQStart;
    //         r.startDate = thisQStart.addMonths(-3);
    //     } else if (period == 'ThisMonth') {
    //         r.startDate = Date.newInstance(today.year(), today.month(), 1);
    //         r.endDate = r.startDate.addMonths(1);
    //     } else if (period == 'LastMonth') {
    //         Date thisMonthStart = Date.newInstance(today.year(), today.month(), 1);
    //         r.endDate = thisMonthStart;
    //         r.startDate = thisMonthStart.addMonths(-1);
    //     } else if (period == 'Last7Days') {
    //         r.endDate = today.addDays(1);
    //         r.startDate = today.addDays(-7);
    //     } else if (period == 'Last30Days') {
    //         r.endDate = today.addDays(1);
    //         r.startDate = today.addDays(-30);
    //     } else {
    //         return null;
    //     }
    //     return r;
    // }
}