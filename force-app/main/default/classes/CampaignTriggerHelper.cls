public class CampaignTriggerHelper {
    Public static Boolean isUpdated = false;
    
    public static void beforeInsert(List<Campaign__c> newList) {
        Set<String> cityNameSet = new Set<String>();
        for(Campaign__c cmp : newList) {
            if(cmp.City__c != null) {
                cityNameSet.add(cmp.City__c);
            }
        }
    }
     public static void updateCampaignName(List<Campaign__c> campaignList){
        // Date todayDate = Date.today();
        // String currentYear = String.valueOf(todayDate.year());
        // String currentQuarter = 'Q' + String.valueOf(((todayDate.month() - 1) / 3) + 1);
        for(Campaign__c record:campaignList){
             Datetime baseDate = record.CreatedDate != null ? record.CreatedDate : Datetime.now();

        String currentYear    = String.valueOf(baseDate.year());
        String currentQuarter = 'Q' + String.valueOf(((baseDate.month() - 1) / 3) + 1);
            String activities = record.List_Of_Activities__c != null ? record.List_Of_Activities__c : '';
            String zone       = record.Zone__c != null ? record.Zone__c : '';
            String city       = record.City__c != null ? record.City__c : '';
            String country    = record.Country__c != null ? record.Country__c : '';
            
            // Construct the final name
            record.Name = currentYear + ' - ' + 
                          currentQuarter + ' - ' + 
                          activities + ' - ' + 
                          zone + ' - ' + 
                          city + ' - ' + 
                          country;
        }
        }

    public static void afterInsert(List<Campaign__c> newList) {
        Map<string, Campaign__c> campaignMap = new Map<string, Campaign__c>();
        Map<string, string> campaignTargetMap = new Map<string, string>();
        Map<string, string> quarterMap = new Map<string, string>{
            'January'=>'Q1','February'=>'Q1','March'=>'Q1','April'=>'Q2','May'=>'Q2','June'=>'Q2','July'=>'Q3','August'=>'Q3','September'=>'Q3','October'=>'Q4','November'=>'Q4','December'=>'Q4'
        };
        List<Campaign__c> campaignDMLList = new List<Campaign__c>();
        List<Campaign__c> campaignList = [SELECT id, Target__c, Target__r.Activity_Type__c, Executer__c, Executer__r.EmployeeNumber, Start_Date__c, Activity_Type__c, Region__c, Zone__c, Three_x_Three__c, Operation__c FROM Campaign__c WHERE Id IN :newList AND Target__r.Activity_Type__c = 'CONFERENCES'];
        
       /* for(Campaign__c cmp : campaignList){
            string dateStr = string.valueOf(cmp.Start_Date__c.year());
            DateTime dt = DateTime.newInstance(cmp.Start_Date__c, system.now().time());
            String externalId = dateStr + '-' + quarterMap.get(dt.format('MMMM')) + '-W' + dt.format('w') + '-' + cmp.Activity_Type__c + '-' + cmp.Executer__c;
            campaignMap.put(externalId, cmp);
        }*/
        
        for(Target__c target : [SELECT id, Year__c, User__c, User__r.EmployeeNumber, Week_No__c, Quater_No__c, Activity_Type__c FROM Target__c WHERE Name IN :campaignMap.KeySet()]){
            String externalId = target.Year__c + '-' + target.Quater_No__c + '-W' + target.Week_No__c + '-' + target.Activity_Type__c + '-' + target.User__c;
            if(campaignMap.containsKey(externalId)){
                campaignTargetMap.put(campaignMap.get(externalId).Id, target.Id);
                campaignMap.remove(externalId);
            }
        }
        if(campaignMap.size() > 0){
            List<Target__c> targetList = new List<Target__c>();
            for(string str : campaignMap.keySet()){
                DateTime dt = DateTime.newInstance(campaignMap.get(str).Start_Date__c, system.now().time());
                Target__c tarObj = new Target__c();
                tarObj.Activity_Type__c = campaignMap.get(str).Activity_Type__c;
                tarObj.Name = str;
                tarObj.Year__c = string.valueOf(dt.year());
                tarObj.User__c = campaignMap.get(str).Executer__c;
                tarObj.Week_No__c = integer.valueOf(dt.format('w'));
                tarObj.Quater_No__c = quarterMap.get(dt.format('MMMM'));
                tarObj.Month__c = dt.format('MMMM');
               // tarObj.Region__c = campaignMap.get(str).Region__c;
                tarObj.Zone__c = campaignMap.get(str).Zone__c;
                tarObj.Quantity__c = 0;
                tarObj.Three_x_Three__c = campaignMap.get(str).Three_x_Three__c;
                tarObj.Operation__c = campaignMap.get(str).Operation__c;
                targetList.add(tarObj);
            }
            if(targetList.size() > 0){
                insert targetList;
            }
            for(Target__c target : targetList){
                String externalId = target.Year__c + '-' + target.Quater_No__c + '-W' + target.Week_No__c + '-' + target.Activity_Type__c + '-' + target.User__c;
                
                if(campaignMap.containsKey(externalId)){
                    campaignTargetMap.put(campaignMap.get(externalId).Id, target.Id);
                }
            }
        }
        for(Campaign__c cmpObj : campaignList){
            if(campaignTargetMap.containsKey(cmpObj.Id)){
                cmpObj.target__c = campaignTargetMap.get(cmpObj.Id);
                campaignDMLList.add(cmpObj);
            }
        }
        if(campaignDMLList.size() > 0){
            update campaignDMLList;
        }
    }

    public static void updateOpportunityCount(List<Campaign__c> newList, Map<Id, Campaign__c> oldMap) {
        Set<String> citySet = new Set<String>();
        List<Campaign_Member__c> cmmpUpdateList = new List<Campaign_Member__c>();
        Set<String> cmpIdSet = new Set<String>();

        for(Campaign__c cmp : newList) {
            if(cmp.City__c != null && cmp.City__c != oldMap.get(cmp.id).City__c) {
                citySet.add(cmp.City__c);
                cmpIdSet.add(cmp.Id);
            }
        }

        Map<String, List<Map<String, Double>>> countDataMap = new Map<String, List<Map<String, Double>>>();
        if(citySet.size() > 0){
            countDataMap = getCisHeaderList(citySet, new Set<String>());
        }


        for(Campaign__c cmp : newList) {
            if(cmp.City__c != null && cmp.City__c != oldMap.get(cmp.id).City__c) {
                if(countDataMap.size() > 0 && countDataMap.containsKey(cmp.City__c)) {
                    List<Map<String, double>> dataList = countDataMap.get(cmp.City__c);
                    Map<String, double> paramMap = getUniqueCountMap(dataList);
                    if(cmp.Product_1_Name__c != null) { ProductMapping__c mc = ProductMapping__c.getValues(cmp.Product_1_Name__c); if(mc != null && paramMap.containsKey(mc.Product_Category__c)) { cmp.Product_1_Opportunity__c = paramMap.get(mc.Product_Category__c); }}
                    if(cmp.Product_2_Name__c != null) { ProductMapping__c mc = ProductMapping__c.getValues(cmp.Product_2_Name__c); if(mc != null && paramMap.containsKey(mc.Product_Category__c)) { cmp.Product_2_Opportunity__c = paramMap.get(mc.Product_Category__c); }}
                    if(cmp.Product_3_Name__c != null) { ProductMapping__c mc = ProductMapping__c.getValues(cmp.Product_3_Name__c); if(mc != null && paramMap.containsKey(mc.Product_Category__c)) { cmp.Product_3_Opportunity__c = paramMap.get(mc.Product_Category__c); }}
                    if(cmp.Product_4_Name__c != null) { ProductMapping__c mc = ProductMapping__c.getValues(cmp.Product_4_Name__c); if(mc != null && paramMap.containsKey(mc.Product_Category__c)) { cmp.Product_4_Opportunity__c = paramMap.get(mc.Product_Category__c); }}
                } else {
                    cmp.Product_1_Opportunity__c = 0;
                    cmp.Product_2_Opportunity__c = 0;
                    cmp.Product_3_Opportunity__c = 0;
                    cmp.Product_4_Opportunity__c = 0;
                }
            }
        }
    }

    public static Map<String, List<Map<String, Double>>> getCisHeaderList(Set<String> citySet, Set<String> accId) {
        Map<String, List<Map<String, Double>>> countDataMap = new Map<String, List<Map<String, Double>>>();
        Map<String, List<CIS_Header__c>> cisHeaderMap = new Map<String, List<CIS_Header__c>>();
        for(Account acc : [SELECT Id, BillingCity, (SELECT Id, Phakic__c, Hydrophilics__c, Hydrophobic_Monofocal__c, Popular_Hydrophobic_Monofocal_Dropdown__c, EDOF_Family__c, MF_Family__c, Trifocal_Family__c, TORIC__c, Account__r.BillingCity FROM CIS_Headers__r WHERE IsPrimary__c = :true ORDER BY createddate DESC LIMIT 1) FROM Account WHERE BillingCity IN :citySet]) {
            if(acc.CIS_Headers__r.size() > 0) {
                for(CIS_Header__c cis : acc.CIS_Headers__r) {
                    if(cisHeaderMap.containsKey(acc.BillingCity)) {
                        cisHeaderMap.get(acc.BillingCity).add(cis);
                    } else {
                        cisHeaderMap.put(acc.BillingCity.toUpperCase(), new List<CIS_Header__c>{cis});
                    }
                }
            }
        }
        if(cisHeaderMap.size() > 0) {
            for(String city : cisHeaderMap.keySet()) {
                List<Map<String, Double>> cisHeaderCountList = new List<Map<String, Double>>();
                for(CIS_Header__c cis : cisHeaderMap.get(city)) {
                    Map<String, Double> uniqueMap = new Map<String, Double>();
                    uniqueMap.put('Phakic', cis.Phakic__c); uniqueMap.put('Hydrophilics', cis.Hydrophilics__c); uniqueMap.put('Hydrophobic Monofocal', cis.Hydrophobic_Monofocal__c); uniqueMap.put('Popular Hydrophobic Monofocal', cis.Popular_Hydrophobic_Monofocal_Dropdown__c); uniqueMap.put('MF Family', cis.MF_Family__c); uniqueMap.put('Trifocal Family', cis.Trifocal_Family__c); uniqueMap.put('EDOF Family', cis.EDOF_Family__c); uniqueMap.put('Toric', cis.TORIC__c);
                    cisHeaderCountList.add(uniqueMap);
                }
                countDataMap.put(city, cisHeaderCountList);
            }
        }
        return countDataMap;
    }

    public static Map<String, double> getUniqueCountMap(List<Map<String, double>> dataList) {
        Map<String, double> paramMap = new Map<String, Double>();
        Integer i = 1;
        for(Map<String, Double> dataMap : dataList) {
            if(i == 1) {
                paramMap.put('Phakic', dataMap.get('Phakic'));
                paramMap.put('Hydrophilics', dataMap.get('Hydrophilics'));
                paramMap.put('Hydrophobic Monofocal', dataMap.get('Hydrophobic Monofocal'));
                paramMap.put('Popular Hydrophobic Monofocal', dataMap.get('Popular Hydrophobic Monofocal'));
                paramMap.put('MF Family', dataMap.get('MF Family'));
                paramMap.put('Trifocal Family', dataMap.get('Trifocal Family'));
                paramMap.put('EDOF Family', dataMap.get('EDOF Family'));
                paramMap.put('Toric', dataMap.get('Toric'));
            } else {
                paramMap.put('Phakic', paramMap.get('Phakic') + dataMap.get('Phakic'));
                paramMap.put('Hydrophilics', paramMap.get('Hydrophilics') + dataMap.get('Hydrophilics'));
                paramMap.put('Hydrophobic Monofocal', paramMap.get('Hydrophobic Monofocal') + dataMap.get('Hydrophobic Monofocal'));
                paramMap.put('Popular Hydrophobic Monofocal', paramMap.get('Popular Hydrophobic Monofocal') + dataMap.get('Popular Hydrophobic Monofocal'));
                paramMap.put('MF Family', paramMap.get('MF Family') + dataMap.get('MF Family'));
                paramMap.put('Trifocal Family', paramMap.get('Trifocal Family') + dataMap.get('Trifocal Family'));
                paramMap.put('EDOF Family', paramMap.get('EDOF Family') + dataMap.get('EDOF Family'));
                paramMap.put('Toric', paramMap.get('Toric') + dataMap.get('Toric'));
            }
            i++;
        }
        return paramMap;
    }

    public static void afterUpdate(List<Campaign__c> newList, Map<Id, Campaign__c> oldMap) {
        if(!isUpdated){
            isUpdated = true;
            Set<String> citySet = new Set<String>();
            Map<String, Map<String, List<Map<String, Double>>>> accountUniqueMap = new Map<String, Map<String, List<Map<String, Double>>>>();
            List<Campaign_Member__c> cmmpUpdateList = new List<Campaign_Member__c>();
            Set<String> cmpIdSet = new Set<String>();
            Set<String> accIdSet = new Set<String>();
            Map<String, String> accIdMap = new Map<String, String>();

            for(Campaign__c cmp : newList) {
                if(cmp.City__c != null && cmp.City__c != oldMap.get(cmp.id).City__c || test.isRunningTest()) {
                    citySet.add(cmp.City__c);
                    cmpIdSet.add(cmp.Id);
                }
            }

            if(cmpIdSet.size() > 0) {
                List<Campaign_Member__c> cmpMemList = [SELECT Id, Campaign1__r.City__c, Account__c, Product_1Opportunity__c, Product_2_Opportunity__c, Product_3_Opportunity__c, Product_4_Opportunity__c, Campaign1__r.Product_1_Name__c, Campaign1__r.Product_2_Name__c, Campaign1__r.Product_3_Name__c, Campaign1__r.Product_4_Name__c FROM Campaign_Member__c WHERE Campaign1__c IN :cmpIdSet];
                
                if(cmpMemList.size() > 0) {
                    for(Campaign_Member__c cmpMem : cmpMemList) {
                        if(cmpMem.Campaign1__r.City__c != null) {
                            citySet.add(cmpMem.Campaign1__r.City__c);
                        }
                        if(cmpMem.Account__c != null) {
                            accIdSet.add(cmpMem.Account__c);
                        }
                    }
                    for(Account acc : [SELECT Id, BillingCity, (SELECT Id, Phakic__c, Hydrophilics__c, Hydrophobic_Monofocal__c, Popular_Hydrophobic_Monofocal_Dropdown__c, Account__c, EDOF_Family__c, MF_Family__c, Trifocal_Family__c, TORIC__c, Account__r.BillingCity FROM CIS_Headers__r WHERE IsPrimary__c = :true ORDER BY createddate DESC LIMIT 1) FROM Account WHERE Id IN :accIdSet AND BillingCity IN :citySet]) {
                        List<Map<String, Double>> cisHeaderCountList = new List<Map<String, Double>>();
                        Map<String, List<Map<String, Double>>> countDataMap = new Map<String, List<Map<String, Double>>>();
                        if(acc.CIS_Headers__r.size() > 0) {
                            for(CIS_Header__c cis : acc.CIS_Headers__r) {
                                Map<String, Double> uniqueMap = new Map<String, Double>();
                                uniqueMap.put('Phakic', cis.Phakic__c); uniqueMap.put('Hydrophilics', cis.Hydrophilics__c); uniqueMap.put('Hydrophobic Monofocal', cis.Hydrophobic_Monofocal__c); uniqueMap.put('Popular Hydrophobic Monofocal', cis.Popular_Hydrophobic_Monofocal_Dropdown__c); uniqueMap.put('MF Family', cis.MF_Family__c); uniqueMap.put('Trifocal Family', cis.Trifocal_Family__c); uniqueMap.put('EDOF Family', cis.EDOF_Family__c); uniqueMap.put('Toric', cis.TORIC__c);
                                cisHeaderCountList.add(uniqueMap);
                            }
                            countDataMap.put(acc.BillingCity, cisHeaderCountList);
                            accountUniqueMap.put(acc.Id, countDataMap);
                        }
                    }

                    for(Campaign_Member__c cmpMemb : cmpMemList) {
                        if(cmpMemb.Account__c != null && cmpMemb.Campaign1__c != null) {
                            if(accountUniqueMap.size() > 0 && accountUniqueMap.containskey(cmpMemb.Account__c)) {
                                if(accountUniqueMap.get(cmpMemb.Account__c).containsKey(cmpMemb.Campaign1__r.City__c)) {
                                    List<Map<String, double>> dataList = accountUniqueMap.get(cmpMemb.Account__c).get(cmpMemb.Campaign1__r.City__c);
                                    Map<String, double> paramMap = getUniqueCountMap(dataList);
                                    if(cmpMemb.Campaign1__r.Product_1_Name__c != null) { ProductMapping__c mc = ProductMapping__c.getValues(cmpMemb.Campaign1__r.Product_1_Name__c); System.debug('mc' + mc.Product_Category__c); if(mc != null && paramMap.containsKey(mc.Product_Category__c)) { cmpMemb.Product_1Opportunity__c = paramMap.get(mc.Product_Category__c); }}
                                    if(cmpMemb.Campaign1__r.Product_2_Name__c != null) { ProductMapping__c mc = ProductMapping__c.getValues(cmpMemb.Campaign1__r.Product_2_Name__c); if(mc != null && paramMap.containsKey(mc.Product_Category__c)) { cmpMemb.Product_2_Opportunity__c = paramMap.get(mc.Product_Category__c); }}
                                    if(cmpMemb.Campaign1__r.Product_3_Name__c != null) { ProductMapping__c mc = ProductMapping__c.getValues(cmpMemb.Campaign1__r.Product_3_Name__c); if(mc != null && paramMap.containsKey(mc.Product_Category__c)) { cmpMemb.Product_3_Opportunity__c = paramMap.get(mc.Product_Category__c); }}
                                    if(cmpMemb.Campaign1__r.Product_4_Name__c != null) { ProductMapping__c mc = ProductMapping__c.getValues(cmpMemb.Campaign1__r.Product_4_Name__c); if(mc != null && paramMap.containsKey(mc.Product_Category__c)) { cmpMemb.Product_4_Opportunity__c = paramMap.get(mc.Product_Category__c); }}
                                }
                            } else {
                                cmpMemb.Product_1Opportunity__c = 0;
                                cmpMemb.Product_2_Opportunity__c = 0;
                                cmpMemb.Product_3_Opportunity__c = 0;
                                cmpMemb.Product_4_Opportunity__c = 0;
                            }
                            cmmpUpdateList.add(cmpMemb);
                        }
                    }

                    if(cmmpUpdateList.size() > 0) {
                        update cmmpUpdateList;
                    }
                }
            }
        }
    }
}