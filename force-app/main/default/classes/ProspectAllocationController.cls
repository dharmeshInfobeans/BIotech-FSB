public with sharing class ProspectAllocationController {

    private static final Integer PAGE_SIZE = 50;
    private static final String PROSPECT_FIELDS =
        'Id, Name, Company__c, Product_Family__c, Billing_City__c, Billing_state__c, ' +
        'RSM_New__c, RSM_New__r.Name, ZoneNew__c, ZSM_New__c, ZSM_New__r.Name, ' +
        'Country__c, NSM_New__c, NSM_New__r.Name, Vertical_Code__c, GSRO_New__c, GSRO_New__r.Name, ' +
        'Division_New__c, Assignment_Stage__c, OwnerId, Owner.Name, Campaign__c, Campaign__r.Name';

    public class ProspectPage {
        @AuraEnabled public List<Lead__c> records;
        @AuraEnabled public Integer totalCount;
    }

    public class FilterOptions {
        @AuraEnabled public List<String> cities;
        @AuraEnabled public List<String> states;
        @AuraEnabled public List<String> zones;
        @AuraEnabled public List<PicklistOption> countryOptions;
        @AuraEnabled public List<String> verticals;
        @AuraEnabled public List<String> assignmentStages;
        @AuraEnabled public List<CityLocation> cityLocations;
        @AuraEnabled public List<CampaignOption> campaigns;
    }

    public class PicklistOption {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
    }

    public class CampaignOption {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
    }

    // One row per distinct City/State/Country combination actually in use,
    // so the client can auto-fill State+Country from a picked City, Country
    // from a picked State, and narrow the City list to the picked State.
    public class CityLocation {
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String country;
    }

    @AuraEnabled
    public static ProspectPage getProspects(String afterId, String city, String state, String zone, String country, String vertical, String assignmentStage, List<String> campaignIds) {
        String cityVal = String.isNotBlank(city) ? city : null;
        String stateVal = String.isNotBlank(state) ? state : null;
        String zoneVal = String.isNotBlank(zone) ? zone : null;
        String countryVal = String.isNotBlank(country) ? country : null;
        String verticalVal = String.isNotBlank(vertical) ? vertical : null;
        String assignmentStageVal = String.isNotBlank(assignmentStage) ? assignmentStage : null;
        // Campaign names aren't unique (CampaignTriggerHelper auto-generates
        // them from date/zone/city/country, so several distinct Campaign__c
        // records can share one visible name) - the client resolves a picked
        // name to every Id that shares it, so this always matches with IN.
        List<String> campaignIdsVal = (campaignIds != null && !campaignIds.isEmpty()) ? campaignIds : null;

        List<String> conditions = new List<String>{
    'RecordType.DeveloperName IN (\'Prospect\', \'Marketing\')'
};
        if (cityVal != null) {
            conditions.add('Billing_City__c = :cityVal');
        }
        if (stateVal != null) {
            conditions.add('Billing_state__c = :stateVal');
        }
        if (zoneVal != null) {
            conditions.add('ZoneNew__c = :zoneVal');
        }
        if (countryVal != null) {
            conditions.add('Country__c = :countryVal');
        }
        if (verticalVal != null) {
            conditions.add('Vertical_Code__c = :verticalVal');
        }
        if (assignmentStageVal != null) {
            conditions.add('Assignment_Stage__c = :assignmentStageVal');
        }
        if (campaignIdsVal != null) {
            conditions.add('Campaign__c IN :campaignIdsVal');
        }
        String baseWhere = String.join(conditions, ' AND ');

        List<String> pageConditions = new List<String>(conditions);
        if (String.isNotBlank(afterId)) {
            pageConditions.add('Id > :afterId');
        }
        String pageWhere = String.join(pageConditions, ' AND ');

        ProspectPage page = new ProspectPage();
        page.records = Database.query(
            'SELECT ' + PROSPECT_FIELDS + ' FROM Lead__c WHERE ' + pageWhere + ' ORDER BY Id ASC LIMIT :PAGE_SIZE'
        );
        page.totalCount = Database.countQuery('SELECT COUNT() FROM Lead__c WHERE ' + baseWhere);
        return page;
    }

    // Built from a single pass over Lead__c instead of separate GROUP BY
    // queries per field - each aggregate query is charged against the "total
    // query rows" governor limit for the full set of records it scans (not
    // just the small number of distinct rows it returns), so 7 separate
    // near-full-table aggregate queries here was blowing past 50,000 rows
    // once the org had enough Prospect/Marketing Lead__c records. One scan
    // keeps the cost proportional to the record count exactly once.
    @AuraEnabled(cacheable=true)
    public static FilterOptions getFilterOptions() {
        FilterOptions options = new FilterOptions();

        Set<String> citySet = new Set<String>();
        Set<String> stateSet = new Set<String>();
        Set<String> zoneSet = new Set<String>();
        Set<String> verticalSet = new Set<String>();
        Set<String> stageSet = new Set<String>();
        // Some cities have inconsistent/bad State or Country data on a
        // handful of Lead__c records (e.g. a batch of "AHMEDABAD" rows
        // mistakenly carrying Country__c = BRAZIL) - tracking a count per
        // distinct City/State/Country combo and sorting by it descending
        // means the client's first-match-wins map building (see
        // loadFilterOptions in the LWC) lands on the dominant, correct
        // combination for each city rather than an arbitrary one.
        Map<String, Integer> comboCounts = new Map<String, Integer>();
        Map<String, CityLocation> comboByKey = new Map<String, CityLocation>();
        Map<Id, String> campaignNameById = new Map<Id, String>();

        for (Lead__c lead : [
            SELECT Billing_City__c, Billing_state__c, Country__c, ZoneNew__c,
                   Vertical_Code__c, Assignment_Stage__c, Campaign__c, Campaign__r.Name
            FROM Lead__c
            WHERE RecordType.DeveloperName IN ('Prospect', 'Marketing')
        ]) {
            if (lead.Billing_City__c != null) {
                citySet.add(lead.Billing_City__c);
                String comboKey = lead.Billing_City__c + '|' + lead.Billing_state__c + '|' + lead.Country__c;
                comboCounts.put(comboKey, (comboCounts.get(comboKey) == null ? 0 : comboCounts.get(comboKey)) + 1);
                if (!comboByKey.containsKey(comboKey)) {
                    CityLocation loc = new CityLocation();
                    loc.city = lead.Billing_City__c;
                    loc.state = lead.Billing_state__c;
                    loc.country = lead.Country__c;
                    comboByKey.put(comboKey, loc);
                }
            }
            if (lead.Billing_state__c != null) {
                stateSet.add(lead.Billing_state__c);
            }
            if (lead.ZoneNew__c != null) {
                zoneSet.add(lead.ZoneNew__c);
            }
            if (lead.Vertical_Code__c != null) {
                verticalSet.add(lead.Vertical_Code__c);
            }
            if (lead.Assignment_Stage__c != null) {
                stageSet.add(lead.Assignment_Stage__c);
            }
            if (lead.Campaign__c != null) {
                campaignNameById.put(lead.Campaign__c, lead.Campaign__r.Name);
            }
        }

        options.cities = sortedList(citySet);
        options.states = sortedList(stateSet);
        options.zones = sortedList(zoneSet);
        options.verticals = sortedList(verticalSet);
        options.assignmentStages = sortedList(stageSet);
        options.countryOptions = getCountryPicklistValues();

        List<String> comboKeys = new List<String>(comboCounts.keySet());
        comboKeys.sort(new ComboCountDescComparator(comboCounts));
        List<CityLocation> cityLocations = new List<CityLocation>();
        for (String comboKey : comboKeys) {
            cityLocations.add(comboByKey.get(comboKey));
        }
        options.cityLocations = cityLocations;

        List<CampaignOption> campaigns = new List<CampaignOption>();
        for (Id campaignId : campaignNameById.keySet()) {
            CampaignOption opt = new CampaignOption();
            opt.id = campaignId;
            opt.name = campaignNameById.get(campaignId);
            campaigns.add(opt);
        }
        campaigns.sort(new CampaignNameAscComparator());
        options.campaigns = campaigns;

        return options;
    }

    private static List<String> sortedList(Set<String> values) {
        List<String> result = new List<String>(values);
        result.sort();
        return result;
    }

    private class ComboCountDescComparator implements Comparator<String> {
        private Map<String, Integer> counts;
        ComboCountDescComparator(Map<String, Integer> counts) {
            this.counts = counts;
        }
        public Integer compare(String a, String b) {
            return counts.get(b) - counts.get(a);
        }
    }

    private class CampaignNameAscComparator implements Comparator<CampaignOption> {
        public Integer compare(CampaignOption a, CampaignOption b) {
            String nameA = a.name == null ? '' : a.name;
            String nameB = b.name == null ? '' : b.name;
            return nameA.compareTo(nameB);
        }
    }

    // The Country filter uses the field's defined picklist values (so every
    // country shows up, not just ones a current Prospect happens to have),
    // with the friendly label shown and the picklist API value used to filter.
    private static List<PicklistOption> getCountryPicklistValues() {
        List<PicklistOption> result = new List<PicklistOption>();
        for (Schema.PicklistEntry entry : Lead__c.Country__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                PicklistOption opt = new PicklistOption();
                opt.value = entry.getValue();
                opt.label = entry.getLabel();
                result.add(opt);
            }
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<CityWise__c> getCityWiseMappings() {
        return [
            SELECT City__c, Division__c, State__c, RSM__c, RSM__r.Name,
                   Zone__c, ZSM__c, ZSM__r.Name,
                   Country__c, NSM__c, NSM__r.Name,
                   Vertical_Code__c, GSRO__c, GSRO__r.Name,
                   District_Level__c, District_Level__r.Name
            FROM CityWise__c
            WHERE External_ID__c != null
        ];
    }

    @AuraEnabled
    public static void saveAllocations(List<Lead__c> updatedRecords) {
        try {
            update updatedRecords;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class EditPermissions {
        @AuraEnabled public Boolean canEditOwner = false;
        @AuraEnabled public Boolean canEditRsm = false;
        @AuraEnabled public Boolean canEditZsm = false;
        @AuraEnabled public Boolean canEditNsm = false;
        @AuraEnabled public Boolean canEditGsro = false;
    }

    // Which of the 5 role fields the logged-in user may edit, based on their
    // Role Hierarchy (UserRole.Name). Tiers are checked in this exact order -
    // MKT/Marketing can edit everything; each tier below that can edit
    // everything BELOW it in the Owner -> RSM -> ZSM -> NSM -> GSRO hierarchy,
    // but never its own level or above. No match = no edit access at all.
    @AuraEnabled(cacheable=true)
    public static EditPermissions getCurrentUserEditPermissions() {
        User me = [SELECT UserRole.Name, Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        String role = (me.UserRole != null) ? me.UserRole.Name : '';

        EditPermissions perms = new EditPermissions();
        // System Administrators always get full access, regardless of their
        // UserRole (or lack of one) - they shouldn't be locked out just
        // because they aren't assigned a sales-hierarchy role.
        if (me.Profile != null && me.Profile.Name == 'System Administrator') {
            perms.canEditOwner = true;
            perms.canEditRsm = true;
            perms.canEditZsm = true;
            perms.canEditNsm = true;
            perms.canEditGsro = true;
        } else if (roleMatches(role, new List<String>{ 'Marketing' }, new List<String>{ 'MKT' })) {
            perms.canEditOwner = true;
            perms.canEditRsm = true;
            perms.canEditZsm = true;
            perms.canEditNsm = true;
            perms.canEditGsro = true;
        } else if (roleMatches(role,
            new List<String>{ 'Regional Sales Manager', 'Refractive Manager', 'Tender Manager', 'KEY ACCOUNT MANAGER' },
            new List<String>{ 'RSM', 'RM', 'TM', 'KAM' }
        )) {
            perms.canEditOwner = true;
        } else if (roleMatches(role, new List<String>{ 'Zonal Sales Manager' }, new List<String>{ 'ZSM' })) {
            perms.canEditOwner = true;
            perms.canEditRsm = true;
        } else if (roleMatches(role,
            new List<String>{ 'National Sales Manager', 'General Manager' },
            new List<String>{ 'NSM', 'GM' }
        )) {
            perms.canEditOwner = true;
            perms.canEditRsm = true;
            perms.canEditZsm = true;
        } else if (roleMatches(role,
            new List<String>{ 'Domestic', 'Global Sales Revenue Officer' },
            new List<String>{ 'DM', 'GSRO' }
        )) {
            perms.canEditOwner = true;
            perms.canEditRsm = true;
            perms.canEditZsm = true;
            perms.canEditNsm = true;
        }
        return perms;
    }

    // phrases match anywhere (case-insensitive substring); abbreviations only
    // match as a whole word, so e.g. "RM" doesn't false-positive inside a
    // longer word like "PHARMA".
    private static Boolean roleMatches(String role, List<String> phrases, List<String> abbreviations) {
        if (String.isBlank(role)) {
            return false;
        }
        String upperRole = role.toUpperCase();
        for (String phrase : phrases) {
            if (upperRole.contains(phrase.toUpperCase())) {
                return true;
            }
        }
        for (String abbr : abbreviations) {
            if (Pattern.compile('(?i)\\b' + Pattern.quote(abbr) + '\\b').matcher(role).find()) {
                return true;
            }
        }
        return false;
    }
}