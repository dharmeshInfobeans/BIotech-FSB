trigger MonthlyAOP_Trigger on Monthly_AOP__c (before insert,before Update) {
    MonthlyAOP_TriggerHandler mopTriggerHandler = new MonthlyAOP_TriggerHandler();
    
    if(trigger.isbefore){
        if(trigger.isInsert){
         //   mopTriggerHandler.updateNoOfproducts(trigger.new);
           map<String,CIty__c>mapRegionbyCode = new map<String, CIty__c>();
            Set<String>regionCodeSet = new Set<String>();
            for(Monthly_AOP__c monthlyAOP : trigger.New){
                if(monthlyAOP.Region_Code__c != null){
                    regionCodeSet.add(monthlyAOP.Region_Code__c);
                }
            }
                map<String,CIty__c>mapRegionCode = new map<String, CIty__c>();
                for(CIty__c RegionCode : [SELECT Id,Region_Code__c FROM CIty__c WHERE Region_Code__c in:regionCodeSet]){
                    mapRegionCode.put(RegionCode.Region_Code__c ,RegionCode);
                }

            mopTriggerHandler.updateRegion(trigger.New, mapRegionCode);
        }
        if(trigger.isUpdate){
            List<Monthly_AOP__c> mopLst = new List<Monthly_AOP__c>();
            List<Monthly_AOP__c> mopRegionCodeChanged = new List<Monthly_AOP__c>();
            Set<String> regionCodeSet = new Set<String>();
            for(Monthly_AOP__c mop : trigger.new){
                Monthly_AOP__c oldMOP = Trigger.oldMap.get(mop.id);
          /*      if(mop.Product_Codes_Text__c != oldMOP.Product_Codes_Text__c && String.isNotBlank(mop.Product_Codes_Text__c)){
                    mopLst.add(mop);
                }
          */
                system.debug('mop.Region_Code__c:: '+mop.Region_Code__c);
                system.debug(' oldMOP.Region_Code__c:: '+ oldMOP.Region_Code__c);
                
                if(mop.Region_Code__c != oldMOP.Region_Code__c){
                    mopRegionCodeChanged.add(mop);
                    regionCodeSet.add(mop.Region_Code__c);
                }
            }
            /*
            if(!mopLst.isEmpty()){
                 mopTriggerHandler.updateNoOfproducts(mopLst);
            }*/
            if(!mopRegionCodeChanged.isEmpty() && regionCodeSet.size()>0){
                
                map<String,CIty__c>mapRegionbyCode = new map<String, CIty__c>();
                for(CIty__c RegionCode : [SELECT Id,Region_Code__c FROM CIty__c WHERE Region_Code__c in:regionCodeSet]){
                    mapRegionbyCode.put(RegionCode.Region_Code__c ,RegionCode);
                }
                mopTriggerHandler.updateRegion(mopRegionCodeChanged, mapRegionbyCode);
            }
        }
    }
}