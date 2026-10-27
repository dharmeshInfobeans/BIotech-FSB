//Created by shakib khan
public without sharing class LeadsProductGroupHandler {
    
    public static void populateProspectFieldsFromCitywise1(List<Lead_Product__c> leadProductList){
        // Map<Id,User> mapOfIdWithMarketingUser = new Map<Id,User>([SELECT Id,profile.Name FROM User WHERE IsActive =true AND (profile.Name Like '%Marketing%' OR (UserRole.Name LIKE '%SSE%'  OR UserRole.Name LIKE '%BDM%'  OR UserRole.Name LIKE '%Sales%' OR UserRole.Name Like 'Domestic'))]);
        // Map<Id,User> mapOfIdWithMarketingUser = new Map<Id,User>([SELECT Id FROM User WHERE IsActive =true]);
        String query = 'SELECT Id,Name, Profile.Name,UserRole.Name FROM User ' +
            'WHERE IsActive = true ' +
            'AND (Profile.Name LIKE \'%Marketing%\' ' +
            'OR (UserRole.Name LIKE \'%SSE%\' ' +
            'OR UserRole.Name LIKE \'%BDM%\' ' +
            'OR UserRole.Name LIKE \'%Sales%\' ' +
            'OR UserRole.Name LIKE \'Domestic Admin\'))';
        
        Map<Id, User> mapOfIdWithMarketingUser =  new Map<Id, User>(  (List<User>) Database.query(query, AccessLevel.SYSTEM_MODE) );
        Map<Id,Boolean> mapOfProspectIdWithBoolean = new Map<Id,Boolean>();
        //System.debug('mapOfIdWithMarketingUser'+json.serialize(mapOfIdWithMarketingUser));
        if(mapOfIdWithMarketingUser == Null || mapOfIdWithMarketingUser.isEmpty()) return;
        Set<String> leadIds = new Set<String>();
        Set<String> productGroupIds = new Set<String>();
        Map<Id,Product_Group__c> leadIdWithProductGroup = new Map<Id,Product_Group__c>();
        Set<String> productGroupSet = new Set<String>{'COH','GT','ORTHO'}; //
            for(Lead_Product__c leadProduct:leadProductList){
                
                if(!leadIds.contains(leadProduct.Leads__c)){  leadIds.add(leadProduct.Leads__c); }
                if(!productGroupIds.contains(leadProduct.Product_Group__c)){productGroupIds.add(leadProduct.Product_Group__c); }
            }
        System.debug('leadIds'+leadIds);
        if(leadIds.isEmpty()) return;
        Map<Id, Product_Group__c> productGroupMap = new Map<Id, Product_Group__c>([SELECT Id, Sub_Division__c, Vertical__c FROM Product_Group__c WHERE Id IN :productGroupIds]);
        System.debug('productGroupMap'+productGroupMap);
        for(Lead_Product__c leadProd:leadProductList){
            if(!leadIdWithProductGroup.containsKey(leadProd.Leads__c)){
                System.debug('inside -36');
                leadIdWithProductGroup.put(leadProd.Leads__c,productGroupMap.get(leadProd.Product_Group__c));
            }
        }
        //Map<Id,Lead__c> mapOfIdWithLead = new Map<Id,Lead__c>([SELECT Id,Zone__c,Country__c,Division_New__c,Vertical_Code__c FROM Lead__c WHERE Id IN:leadIds]);
        List<Lead__c> newLeadList = new List<Lead__c>();
      //  System.debug('Lead on line 42'+[SELECT Id,Zone__c,Country__c,Division_New__c,Vertical_Code__c,Billing_state__c,OwnerId,Billing_City__c   FROM Lead__c WHERE Id IN:leadIds]);
        for(Lead__c lead:[SELECT Id,Zone__c,Country__c,Division_New__c,Vertical_Code__c,Billing_state__c,OwnerId,Billing_City__c,campaign__c   FROM Lead__c WHERE Id IN:leadIds]){
            if(mapOfIdWithMarketingUser.containsKey(lead.OwnerId)){
                System.debug('inside 44');
               
                lead.Vertical_Code__c=leadIdWithProductGroup.get(lead.Id).Vertical__c ?? Null;
                lead.Division_New__c = leadIdWithProductGroup.get(lead.Id).Sub_Division__c ?? Null;
                lead.Zone__c = lead.isSet('Zone__c') ? lead.Zone__c : null;
                  lead.Country__c       = lead.isSet('Country__c')       ? (String) lead.get('Country__c')       : null;
        lead.Billing_state__c = lead.isSet('Billing_state__c') ? (String) lead.get('Billing_state__c') : null;
        lead.Billing_City__c  = lead.isSet('Billing_City__c')  ? (String) lead.get('Billing_City__c')  : null;
         lead.campaign__c = lead.isSet('campaign__c')  ? (String) lead.get('campaign__c')  : null;
         lead.RSM_New__c =null;
             lead.ZSM_New__c =null;
             lead.NSM_New__c =null;
             lead.GSRO_New__c =null;
             lead.Divisional_Manager__c =null;
                newLeadList.add(lead);
            }
        }
        
        System.debug('newLeadList======================57'+newLeadList);
        Set<String> countrySet = new Set<String>();
        Set<String> stateSet = new Set<String>();
        Set<String> zoneSet = new Set<String>();
        Set<String> verticalSet = new Set<String>();
        Set<String> billingCitySet = new Set<String>();
        Set<String> divisionSet = new Set<String>();
        for(Lead__c lead:newLeadList){
            if (lead.Country__c != null) { countrySet.add(lead.Country__c); }
            if (lead.Billing_state__c != null) { stateSet.add(lead.Billing_state__c);  }
            if (lead.Zone__c != null) { zoneSet.add(lead.Zone__c);  }
            if (lead.Vertical_Code__c != null) {  verticalSet.add(lead.Vertical_Code__c); }
            if(lead.Billing_City__c != Null){  billingCitySet.add(lead.Billing_City__c); }
            if(lead.Division_New__c != Null){  divisionSet.add(lead.Division_New__c); }  }
      //  (Country__c IN :countrySet OR State__c IN :stateSet OR Zone__c IN :zoneSet OR Vertical_Code__c IN :verticalSet OR City__c IN:billingCitySet)  
      //  List<CityWise__c> citywiseRecords = [ SELECT Id,  Country__c,  State__c,  Zone__c,  Vertical_Code__c, GSRO__c, NSM__c, ZSM__c,RSM__c,Divisional_Manager__c,City__c,District_Level__c,Division__c       FROM CityWise__c  WHERE External_Id__c != null /*AND GSRO__c!= Null AND NSM__c != Null AND ZSM__c != NUll AND RSM__c != Null*/ AND Division__c IN:divisionSet AND (Country__c IN :countrySet OR State__c IN :stateSet OR Zone__c IN :zoneSet OR Vertical_Code__c IN :verticalSet OR City__c IN:billingCitySet) ];
      List<CityWise__c> citywiseRecords = [ SELECT Id,  Country__c,  State__c,  Zone__c,  Vertical_Code__c, GSRO__c, NSM__c, ZSM__c,RSM__c,Divisional_Manager__c,City__c,District_Level__c,Division__c       FROM CityWise__c  WHERE External_Id__c != null /*AND GSRO__c!= Null AND NSM__c != Null AND ZSM__c != NUll AND RSM__c != Null*/ AND Division__c IN:divisionSet AND 
                                          ( ( Vertical_Code__c IN :verticalSet AND Country__c IN :countrySet AND Zone__c IN :zoneSet AND State__c IN :stateSet AND City__c IN:billingCitySet) OR
                                           ( Vertical_Code__c IN :verticalSet AND Country__c IN :countrySet AND Zone__c IN :zoneSet AND State__c IN :stateSet) OR
                                           ( Vertical_Code__c IN :verticalSet AND Country__c IN :countrySet AND Zone__c IN :zoneSet) OR
                                           ( Vertical_Code__c IN :verticalSet AND Country__c IN :countrySet) OR
                                           ( Vertical_Code__c IN :verticalSet)
                                           
                                          ) ];
        Map<String, CityWise__c> countryMap = new Map<String, CityWise__c>();
        Map<String, CityWise__c> stateMap = new Map<String, CityWise__c>();
        Map<String, CityWise__c> zoneMap = new Map<String, CityWise__c>();
        Map<String, CityWise__c> verticalMap = new Map<String, CityWise__c>();
        Map<String, CityWise__c> cityMap = new Map<String, CityWise__c>();
        
        Set<String> userIds = new Set<String>();
        System.debug('citywiseRecords'+json.serialize(citywiseRecords));
      /*  for (CityWise__c city : citywiseRecords) {
            
            
            if(city.City__c != Null && !cityMap.containsKey(city.City__c)){
                cityMap.put(city.City__c.toUpperCase(), city); 
                  stateMap.put(city.State__c.toUpperCase(), city);
                 zoneMap.put(city.Zone__c.toUpperCase(), city);  
                  countryMap.put(city.Country__c.toUpperCase(), city); 
                  verticalMap.put(city.Vertical_Code__c.toUpperCase(), city);
                
            }
              else if (city.State__c != null && !stateMap.containsKey(city.State__c)) {
                  stateMap.put(city.State__c.toUpperCase(), city);  
                    zoneMap.put(city.Zone__c.toUpperCase(), city);  
                  countryMap.put(city.Country__c.toUpperCase(), city); 
                  verticalMap.put(city.Vertical_Code__c.toUpperCase(), city);
              }
              else if (city.Zone__c != null && !zoneMap.containsKey(city.Zone__c)) {  
                  zoneMap.put(city.Zone__c.toUpperCase(), city);  
                   countryMap.put(city.Country__c.toUpperCase(), city); 
                  verticalMap.put(city.Vertical_Code__c.toUpperCase(), city);
              }
            else if (city.Country__c != null && !countryMap.containsKey(city.Country__c)) {  
                countryMap.put(city.Country__c.toUpperCase(), city); 
                  verticalMap.put(city.Vertical_Code__c.toUpperCase(), city);
            }
            else if (city.Vertical_Code__c != null && !verticalMap.containsKey(city.Vertical_Code__c)) {  
                verticalMap.put(city.Vertical_Code__c.toUpperCase(), city);
            }
           /*  if(city.City__c != Null && !cityMap.containsKey(city.City__c)){  cityMap.put(city.City__c.toUpperCase(), city); }
           
              if (city.State__c != null && !stateMap.containsKey(city.State__c) && city.City__c == Null) { stateMap.put(city.State__c.toUpperCase(), city);}
              if (city.Zone__c != null && !zoneMap.containsKey(city.Zone__c)  && city.City__c == Null && city.State__c == null) {  zoneMap.put(city.Zone__c.toUpperCase(), city);  }
            if (city.Country__c != null && !countryMap.containsKey(city.Country__c) && city.City__c == Null && city.State__c == null && city.Zone__c == Null) {  countryMap.put(city.Country__c.toUpperCase(), city); }
            if (city.Vertical_Code__c != null && !verticalMap.containsKey(city.Vertical_Code__c) && city.City__c == Null && city.State__c == null && city.Zone__c == Null && city.Country__c== Null) {  verticalMap.put(city.Vertical_Code__c.toUpperCase(), city);}
          
        }*/
        for (CityWise__c cw : citywiseRecords) {
    String div = cw.Division__c != null ? cw.Division__c.toUpperCase() : '';

    if (String.isNotBlank(cw.City__c)) {
        cityMap.put(div + '_' + cw.City__c.trim().toUpperCase(), cw);
    }
    if (String.isNotBlank(cw.State__c)) {
        stateMap.put(div + '_' + cw.State__c.trim().toUpperCase(), cw);
    }
    if (String.isNotBlank(cw.Zone__c)) {
        zoneMap.put(div + '_' + cw.Zone__c.trim().toUpperCase(), cw);
    }
    if (String.isNotBlank(cw.Country__c)) {
        countryMap.put(div + '_' + cw.Country__c.trim().toUpperCase(), cw);
    }
    if (String.isNotBlank(cw.Vertical_Code__c)) {
        verticalMap.put(div + '_' + cw.Vertical_Code__c.trim().toUpperCase(), cw);
    }
}
        System.debug('countryMap'+countryMap);
        System.debug('zoneMap'+zoneMap);
        System.debug('verticalMap'+verticalMap);
        System.debug('stateMap'+stateMap);
        System.debug('cityMap'+cityMap);
        
        for(Lead__c lead:newLeadList){
           /*   System.debug('127------- billing city'+cityMap.get(lead.Billing_City__c)??Null);
              System.debug('128----------billing state'+stateMap.get(lead.Billing_state__c)??NULL);
             System.debug('129--------------- zone map'+zoneMap.get(lead.Zone__c)??NULL);
              System.debug('130------------------ country map'+countryMap.get(lead.Country__c)??NULL);
              System.debug('131---------------------- vertical map'+verticalMap.get(lead.Vertical_Code__c)??NULL);
            System.debug('lead inside forloop -----------------'+lead);
            mapOfProspectIdWithBoolean.put(lead.Id,false);
            if(lead.Billing_City__c != Null && cityMap.containsKey(lead?.Billing_City__c.toUpperCase()) && cityMap.get(lead?.Billing_City__c.toUpperCase())?.Division__c ==lead.Division_New__c){
                System.debug('inside city condition'+cityMap.get(lead.Billing_City__c));
                System.debug(lead.Billing_City__c);
                System.debug(cityMap.get(lead.Billing_City__c.toUpperCase())?.District_Level__c 
                             
                             != Null?'City wise district' :'lead owner');
                if(lead.campaign__c != Null){
                     lead.OwnerId = cityMap.get(lead.Billing_City__c.toUpperCase())?.District_Level__c  != Null?cityMap.get(lead.Billing_City__c.toUpperCase())?.District_Level__c :lead.OwnerId;
                }
               
                lead.RSM_New__c=cityMap.get(lead.Billing_City__c.toUpperCase()).RSM__c??NULL;
                lead.ZSM_New__c=cityMap.get(lead.Billing_City__c.toUpperCase()).ZSM__c??NULL;
                lead.NSM_New__c=cityMap.get(lead.Billing_City__c.toUpperCase()).NSM__c??NULL;
                lead.GSRO_New__c=cityMap.get(lead.Billing_City__c.toUpperCase()).GSRO__c??NULL;
                lead.Divisional_Manager__c=cityMap.get(lead.Billing_City__c.toUpperCase()).Divisional_Manager__c??NULL;
                  mapOfProspectIdWithBoolean.put(lead.Id,true);
                System.debug('mapOfProspectIdWithBoolean'+mapOfProspectIdWithBoolean);
            }
            else if(lead?.Billing_state__c != Null && productGroupSet.contains(lead?.Division_New__c) && stateMap.containsKey(lead?.Billing_state__c.toUpperCase()) && stateMap.get(lead?.Billing_state__c.toUpperCase())?.Division__c == lead?.Division_New__c){
                System.debug('inside state condition'+stateMap.get(lead.Billing_state__c));
                userIds.add(stateMap.get(lead.Billing_state__c.toUpperCase())?.RSM__c);
                lead.RSM_New__c=stateMap.get(lead.Billing_state__c.toUpperCase())?.RSM__c??NULL;
                lead.ZSM_New__c=stateMap.get(lead.Billing_state__c.toUpperCase())?.ZSM__c??NULL;
                lead.NSM_New__c=stateMap.get(lead.Billing_state__c.toUpperCase())?.NSM__c??NULL;
                lead.GSRO_New__c=stateMap.get(lead.Billing_state__c.toUpperCase())?.GSRO__c??NULL;
                 lead.Divisional_Manager__c=stateMap.get(lead.Billing_state__c.toUpperCase())?.Divisional_Manager__c??NULL;
            }else if(lead?.Zone__c != NULL && zoneMap.containsKey(lead?.Zone__c.toUpperCase()) && zoneMap.get(lead?.Zone__c.toUpperCase())?.Division__c == lead?.Division_New__c){
                System.debug('inside zone condtions'+zoneMap.get(lead.Zone__c));
                userIds.add(zoneMap.get(lead.Zone__c.toUpperCase())?.ZSM__c);
                lead.ZSM_New__c=zoneMap.get(lead.Zone__c.toUpperCase())?.ZSM__c??NULL;
                lead.NSM_New__c=zoneMap.get(lead.Zone__c.toUpperCase())?.NSM__c??NULL;
                lead.GSRO_New__c=zoneMap.get(lead.Zone__c.toUpperCase())?.GSRO__c??NULL;
                 lead.Divisional_Manager__c=zoneMap.get(lead.Zone__c.toUpperCase())?.Divisional_Manager__c??NULL;
            } else if(lead?.Country__c != NULL && countryMap.containsKey(lead?.Country__c.toUpperCase()) && countryMap.get(lead?.Country__c.toUpperCase())?.Division__c == lead?.Division_New__c){
                System.debug('inside country condition'+countryMap.get(lead.Country__c));
                userIds.add(countryMap.get(lead.Country__c.toUpperCase())?.NSM__c);
                lead.NSM_New__c=countryMap.get(lead.Country__c.toUpperCase())?.NSM__c??NULL;
                lead.GSRO_New__c=countryMap.get(lead.Country__c.toUpperCase())?.GSRO__c??NULL;
                 lead.Divisional_Manager__c=countryMap.get(lead.Country__c.toUpperCase())?.Divisional_Manager__c??NULL;
            } else if(lead?.Vertical_Code__c != NULL &&  verticalMap.containsKey(lead?.Vertical_Code__c.toUpperCase()) && verticalMap.get(lead?.Vertical_Code__c.toUpperCase())?.Division__c == lead?.Division_New__c){
                System.debug('inside vertical condition'+verticalMap.get(lead.Vertical_Code__c));
                userIds.add(verticalMap.get(lead.Vertical_Code__c.toUpperCase())?.GSRO__c);
                lead.GSRO_New__c=verticalMap.get(lead.Vertical_Code__c.toUpperCase())?.GSRO__c??NULL;
                lead.Divisional_Manager__c = verticalMap.get(lead.Vertical_Code__c.toUpperCase())?.Divisional_Manager__c??NULL;
                
            } */
            mapOfProspectIdWithBoolean.put(lead.Id, false);
    String div = lead.Division_New__c != null ? lead.Division_New__c.toUpperCase() : '';

    String cityKey     = String.isNotBlank(lead.Billing_City__c)   ? div + '_' + lead.Billing_City__c.trim().toUpperCase() : null;
    String stateKey    = String.isNotBlank(lead.Billing_state__c)  ? div + '_' + lead.Billing_state__c.trim().toUpperCase() : null;
    String zoneKey     = String.isNotBlank(lead.Zone__c)           ? div + '_' + lead.Zone__c.trim().toUpperCase() : null;
    String countryKey  = String.isNotBlank(lead.Country__c)        ? div + '_' + lead.Country__c.trim().toUpperCase() : null;
    String verticalKey = String.isNotBlank(lead.Vertical_Code__c) ? div + '_' + lead.Vertical_Code__c.trim().toUpperCase() : null;

    CityWise__c matchedRule = null;

    if (cityKey != null && cityMap.containsKey(cityKey)) {
        
        matchedRule = cityMap.get(cityKey);
        System.debug('condition 1'+matchedRule);
          lead.RSM_New__c            = matchedRule.RSM__c;
        lead.ZSM_New__c            = matchedRule.ZSM__c;
        lead.NSM_New__c            = matchedRule.NSM__c;
        lead.GSRO_New__c           = matchedRule.GSRO__c;
        lead.Divisional_Manager__c = matchedRule.Divisional_Manager__c;
        
        if (lead.campaign__c != null && matchedRule.District_Level__c != null) {
            lead.OwnerId = matchedRule.District_Level__c;
        }
        mapOfProspectIdWithBoolean.put(lead.Id, true);
    } else if (stateKey != null && productGroupSet.contains(lead.Division_New__c) && stateMap.containsKey(stateKey)) {
         
        
        matchedRule = stateMap.get(stateKey);
        
         lead.RSM_New__c            = matchedRule.RSM__c;
        lead.ZSM_New__c            = matchedRule.ZSM__c;
        lead.NSM_New__c            = matchedRule.NSM__c;
        lead.GSRO_New__c           = matchedRule.GSRO__c;
        lead.Divisional_Manager__c = matchedRule.Divisional_Manager__c;
         System.debug('condition 2'+matchedRule);
    } else if (zoneKey != null && zoneMap.containsKey(zoneKey)) {
        matchedRule = zoneMap.get(zoneKey);
          lead.ZSM_New__c            = matchedRule.ZSM__c;
        lead.NSM_New__c            = matchedRule.NSM__c;
        lead.GSRO_New__c           = matchedRule.GSRO__c;
        lead.Divisional_Manager__c = matchedRule.Divisional_Manager__c;
         System.debug('condition 3'+matchedRule);
    } else if (countryKey != null && countryMap.containsKey(countryKey)) {
        matchedRule = countryMap.get(countryKey);
         lead.NSM_New__c            = matchedRule.NSM__c;
        lead.GSRO_New__c           = matchedRule.GSRO__c;
        lead.Divisional_Manager__c = matchedRule.Divisional_Manager__c;
         System.debug('condition 4'+matchedRule);
    } else if (verticalKey != null && verticalMap.containsKey(verticalKey)) {
        matchedRule = verticalMap.get(verticalKey);
          lead.GSRO_New__c           = matchedRule.GSRO__c;
        lead.Divisional_Manager__c = matchedRule.Divisional_Manager__c;
         System.debug('condition5'+matchedRule);
    }

  /* if (matchedRule != null) {
        lead.RSM_New__c            = matchedRule.RSM__c;
        lead.ZSM_New__c            = matchedRule.ZSM__c;
        lead.NSM_New__c            = matchedRule.NSM__c;
        lead.GSRO_New__c           = matchedRule.GSRO__c;
        lead.Divisional_Manager__c = matchedRule.Divisional_Manager__c;
        
        if (matchedRule.RSM__c != null) userIds.add(matchedRule.RSM__c);
        if (matchedRule.ZSM__c != null) userIds.add(matchedRule.ZSM__c);
        if (matchedRule.NSM__c != null) userIds.add(matchedRule.NSM__c);
        System.debug('lead after and before'+lead);
    }*/
        }
       
        System.debug('after adding all the allocation'+newLeadList);
        for(Lead__c lead:newLeadList){
            if(!mapOfProspectIdWithBoolean.get(lead.Id) && lead.RSM_New__c != Null && lead.campaign__c != Null){
                lead.OwnerId=lead.RSM_New__c;
            }else if(!mapOfProspectIdWithBoolean.get(lead.Id) && lead.ZSM_New__c != Null && lead.campaign__c != Null){
                 lead.OwnerId=lead.ZSM_New__c;
            }else if(!mapOfProspectIdWithBoolean.get(lead.Id) && lead.NSM_New__c != Null && lead.campaign__c != Null){
                 lead.OwnerId=lead.NSM_New__c;
            }else if(!mapOfProspectIdWithBoolean.get(lead.Id) && lead.Divisional_Manager__c != Null && lead.campaign__c != Null){
                 lead.OwnerId=lead.Divisional_Manager__c;
            }else if(!mapOfProspectIdWithBoolean.get(lead.Id) && lead.GSRO_New__c != Null && lead.campaign__c != Null){
                 lead.OwnerId=lead.GSRO_New__c;
            }
            
        }
         System.debug('after owner change====================> 163'+newLeadList);
        if(!newLeadList.isEmpty()){  Database.update(newLeadList,false); }
        if(!userIds.isEmpty()){ 
            System.debug('User notification Id'+userIds);
           // sendNotificaitonToUsers(new Set<String>{UserInfo.getUserId()});
           // sendNotificaitonToUsers(userIds); 
        }
        
    }
    public static void sendNotificaitonToUsers(Set<String> userIds){
        if(userIds.isEmpty()) {return;}
        try{
            String baseUrl = URL.getOrgDomainUrl().toExternalForm();
            String dynamicUrl = baseUrl + '/lightning/n/Prospect_Allocation';
            String pageRefJson = '{' + '"type": "standard__webPage",' + '"attributes": {' +'"url": "' + dynamicUrl + '"' + '}' +'}';
            CustomNotificationType notificationType = [ SELECT Id  FROM CustomNotificationType  WHERE DeveloperName = 'Send_Prospect_Assignment_Notification' LIMIT 1 ];
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('New Prospect Assigned');
            notification.setBody('A new prospect has been assigned to you. Click here for Prospect Allocation');
            notification.setNotificationTypeId(notificationType.Id);
            notification.setTargetPageRef(pageRefJson);
            notification.send(userIds);
        }
        catch(Exception e){
            System.debug('Error sending custom notification: ' + e.getMessage());
        }
        
        
        
        
        
    }
}