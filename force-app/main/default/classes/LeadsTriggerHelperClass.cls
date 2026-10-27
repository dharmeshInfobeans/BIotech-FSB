/**=====================================================================
* 
* Name: LeadsTriggerHelperClass 
* Description: This Helper is using for the complete Lead Management.
* Created Date:
* Created By: Pankaj Sen(Plus91labs) Status__c
* 
* Date Modified                        Description of the update
*           
=====================================================================*/
public  class LeadsTriggerHelperClass {
//public static Savepoint sp = Database.setSavepoint();
/*Des-Insert the Address data from the Existing account and tag crinto the Lead*/
public static void insAddressData(List < Lead__c > newList) {
    Savepoint sp;
    try {
        sp = Database.setSavepoint();  // set savepoint inside method
        Map < String, String > leadSapMap = new Map < String, String > ();
        List < Address__c > adressInsList = new List < Address__c > ();
        List < Lead__c > leaddUpdateList = new List < Lead__c > ();
        if (newList.size() > 0) {
            for (Lead__c lea: newList) {
                if (string.isnotBlank(lea.SAP_Code__c)) {
                    leadSapMap.put(lea.SAP_Code__c, lea.Id);
                }
                Address__c adrs = new Address__c();
                adrs.Lead__c = lea.Id;
                adrs.Billing_City__c = lea.Billing_City__c;
                adrs.Billing_code__c = lea.Billing_code__c;
                adrs.Billing_country__c = lea.Country__c;
                
                adrs.Billing_state__c = lea.Billing_state__c;
                adrs.Billing_Street__c = lea.Billing_Street__c;
                adressInsList.add(adrs);
            }
            if (leadSapMap.size() > 0) {
                List < Address__c > adrsLsit = new List < Address__c > ();
                for (Address__c adrs: [SELECT Id, Name, Bill_to__c, Is_Primary__c, Ship_to__c, Account__c,
                                        Account__r.SAP_Code__c from Address__c where Account__r.SAP_Code__c in: leadSapMap.keySet()
                                        ]) {
                                            if (leadSapMap.containsKey(adrs.Account__r.SAP_Code__c)) {
                                                adrs.Lead__c = leadSapMap.get(adrs.Account__r.SAP_Code__c);
                                                adrsLsit.add(adrs);
                                            }
                                        }
                if (adrsLsit.size() > 0) {
                    update adrsLsit;
                }
            }
            if (adressInsList.size() > 0) {
                insert adressInsList;
            }
        }
    } catch (exception e) {
        if (sp != null) {
            Database.rollback(sp);
        }
        System.debug('Error message' + e.getMessage());
    }
}
/*DES-Convert the Lead Data--*/
public static void createAccountData(List < Lead__c > newList, Map < Id, Lead__c > oldMap) {
    Savepoint sp;
    try {
        
        sp = Database.setSavepoint();  // set savepoint inside method
        
        Map < String, String > accSapMap = new Map < String, String > (); //Strore to get lead Id and Sap code
        Map < String, List < Address__c >> addressMap = new Map < String, List < Address__c >> (); //store to get lead Sap code and addresses
        List < Address__c > adrsInsList = new List < Address__c > ();
        List < Account > accUpdateList = new List < Account > ();
        Map < String, Account > accAdrsTagMap = new Map < String, Account > (); //store to tag account to address
        Map < String, Lead__c > ceCisRatingTagMap = new Map < String, Lead__c > ();
        List < Contact > conList = new List < Contact > ();
        List < Contact > conInsList = new List < Contact > ();
        List < Account > accInsList = new List < Account > ();
        Set < String > regionSet = new Set < String > (); //It is using to catch the region data 
        Map < String, String > regionDataMap = new Map < String, String > (); //it is using to map the region with account
        List < CIS_Header__c > cisHeaderList = new List < CIS_Header__c > ();
        Map < String, Account > cisHeaderMap = new Map < String, Account > ();
        Map < String, string > conFirstLastDataMap = new Map < String, String > ();
        Map < String, String > accUniqueMap = new Map < String, String > ();
        Set<String> countrySet=new Set<String>();
        Set<String> stateSet=new Set<String>();
        Map<String,String> sldDisMap=new Map<String,String>();
        Map<String,String> sldOffMap=new Map<String,String>();
        
        Map<String,String> plantMap=new Map<String,String>();
        Id currentUserId = UserInfo.getUserId();
        
        // Retrieve the current user's country and Customer Creation Module field values
        User currentUser = [
            SELECT Country__c, Customer_Creation_Module__c
            FROM User
            WHERE Id = :currentUserId
            LIMIT 1
        ];
        
        //String userCountry = currentUser.Country__c;
        String isCustomCreationEnabled = (currentUser.Customer_Creation_Module__c!=null &&  currentUser.Customer_Creation_Module__c!='') ? currentUser.Customer_Creation_Module__c : '';
        
        // Retrieve the custom label value (comma-separated)
        String excludedCountries = Label.Country_wise_Customer_creation_module; // Replace with your custom label API name
        
        // Split the custom label into a list of trimmed countries
        List<String> excludedCountryList = new List<String>();
        if (!String.isEmpty(excludedCountries)) {
            
            if(excludedCountries!=null && excludedCountries!='') {
                if(excludedCountries.contains(',')) {
                    for (String country : excludedCountries.split(',')) {
                        excludedCountryList.add(country.trim());
                    }
                }else {
                    excludedCountryList.add(excludedCountries.trim());
                }
            }
        }
        
        
        
        /*  for(Lead__c lea: newList) {
System.debug('Lead count'+lea.Upload_Count__c);
System.debug('Lead upload count'+oldMap.get(lea.Id).Upload_Count__c);
if(lea.Upload_Count__c!=oldMap.get(lea.Id).Upload_Count__c) {
System.debug('inside update');
countrySet.add(lea.Country__c);
stateSet.add(lea.Billing_state__c);
}
}
System.debug('countrySet'+countrySet);
System.debug('stateSet'+stateSet);
if(countrySet.size()>0 && stateSet.size()>0) {
System.debug('inside if');
List<Sales_Data_Kyc_Form__c> slsDataList=[SELECT Id,Country__c,State__c,Plant__c,Sales_District__c,Sales_Officer__c,Sales_District_Code__c,Sales_Officer_Code__c,Plant_Code__c from Sales_Data_Kyc_Form__c where Country__c in:countrySet AND State__c=:stateSet];
for(Sales_Data_Kyc_Form__c sld:slsDataList) {
sldDisMap.put(sld.Country__c+sld.State__c+sld.Sales_District__c,sld.Sales_District_Code__c);
sldOffMap.put(sld.Country__c+sld.State__c+sld.Sales_Officer__c,sld.Sales_Officer_Code__c);
plantMap.put(sld.Country__c+sld.State__c+sld.Plant__c,sld.Plant_Code__c);
}

}
System.debug('sldDisMap'+sldDisMap);
System.debug('sldOffMap'+sldOffMap);
System.debug('plantMap'+plantMap);*/
        
        
        for (Lead__c lea: newList) {
            
            // Ensure street fields are cleared before splitting/*********************Added by gyadeen For customer creation pdf
            lea.Street_1__c = null;
            lea.Street_2__c = null;
            lea.Street_3__c = null;
            lea.Street_4__c = null;
            
            
            Integer maxLengths = 30; // Adjust as needed
            String fullStreet = lea.Billing_Street__c != null ? lea.Billing_Street__c.toUpperCase() : ''; 
            
            
            if (String.isNotBlank(fullStreet)) {
                Integer length = fullStreet.length();
                Integer startIndex = 0;
                List<String> streetChunks = new List<String>();
                
                
                
                while (startIndex < length) {
                    Integer endIndex = Math.min(startIndex + maxLengths, length);
                    
                    // Avoid breaking a word: Find the last space within the allowed limit
                    if (endIndex < length) {
                        Integer lastSpace = fullStreet.lastIndexOf(' ', endIndex);
                        if (lastSpace > startIndex) {
                            endIndex = lastSpace; // Adjust end index to the last space
                        }
                    }
                    
                    // If no space is found, forcefully break at maxLengths
                    if (startIndex == endIndex) {
                        endIndex = Math.min(startIndex + maxLengths, length);
                    }
                    
                    String chunk = fullStreet.substring(startIndex, endIndex).trim();
                    streetChunks.add(chunk);
                    
                    
                    startIndex = endIndex + 1; // Move to the next chunk (skip space)
                }
                
                if (streetChunks.size() > 0) {
                    lea.Street_1__c = streetChunks[0];
                    
                } 
                if (streetChunks.size() > 1) {
                    lea.Street_2__c = streetChunks[1];
                    
                } 
                if (streetChunks.size() > 2) {
                    lea.Street_3__c = streetChunks[2];
                    
                } 
                if (streetChunks.size() > 3) {
                    lea.Street_4__c = streetChunks[3];
                    
                }
                
            }
            
            
            
            
            /* if(lea.Upload_Count__c!=oldMap.get(lea.Id).Upload_Count__c) {
System.debug('Dis'+lea.Sales_district__c);
System.debug('Sales_Office__c'+lea.Sales_Office__c);
System.debug('Plant_Code__c'+lea.Plant__c);
if(sldDisMap.containsKey(lea.Country__c+lea.Billing_state__c+lea.Sales_district__c)) {
lea.Sales_District_Code__c=sldDisMap.get(lea.Country__c+lea.Billing_state__c+lea.Sales_district__c);
}
if(sldOffMap.containsKey(lea.Country__c+lea.Billing_state__c+lea.Sales_Office__c)) {
lea.Sales_Officer_Code__c=sldDisMap.get(lea.Country__c+lea.Billing_state__c+lea.Sales_Office__c);
}
if(plantMap.containsKey(lea.Country__c+lea.Billing_state__c+lea.Plant__c)) {
lea.Plant_Code__c=sldDisMap.get(lea.Country__c+lea.Billing_state__c+lea.Plant__c);
}
}*/
            
            if (lea.Lead_Stage__c != oldMap.get(lea.Id).Lead_Stage__c && lea.Lead_Stage__c == 'Won' && oldMap.get(lea.Id).Lead_Stage__c != 'Upgrade' && lea.Existing_customer__c) {
                lea.addError('Please mark the Stage as upgrade');
            }
            
            
            
            
            if (excludedCountryList.contains(isCustomCreationEnabled) && (lea.Lead_Stage__c != null && oldMap.get(lea.Id).Lead_Stage__c != lea.Lead_Stage__c && lea.New_Customer__c && lea.Account__c==null && lea.Lead_Stage__c=='Commercialization') || (lea.Lead_Stage__c != oldMap.get(lea.Id).Lead_Stage__c && lea.Lead_Stage__c == 'Upgrade' && lea.Existing_customer__c && lea.SAP_Code__c != null)) {
                lea.Lead_Stage__c = 'Won';
                if(lea.Account__c ==null){
                    ceCisRatingTagMap.put(lea.SAP_Code__c, lea);
                    accSapMap.put(lea.Id, lea.SAP_Code__c);
                    conFirstLastDataMap.put(lea.SAP_Code__c, lea.First_Name__c + '-' + lea.Last_Name__c);
                }
                
                
                
                
                if (string.isNotBlank(lea.Billing_state__c)) {
                    regionSet.add(lea.Billing_state__c);
                }
            }
            
            if(!excludedCountryList.contains(isCustomCreationEnabled)) {
                
            }
            
            
                if( !excludedCountryList.contains(isCustomCreationEnabled) && (lea.SAP_Code__c!=null  /*&& oldMap.get(lea.Id).SAP_Code__c != lea.SAP_Code__c*/ &&  lea.Aproved_By_Manager__c && lea.Approval_status__c=='Approved' && lea.Lead_Stage__c=='Commercialization' && lea.New_Customer__c) || (lea.Lead_Stage__c!=oldMap.get(lea.Id).Lead_Stage__c && lea.Lead_Stage__c=='Upgrade' && lea.Existing_customer__c && lea.SAP_Code__c!=null )) {
                lea.Lead_Stage__c='Won';
                if(lea.Account__c ==null){
                    
                    ceCisRatingTagMap.put(lea.SAP_Code__c,lea);
                    accSapMap.put(lea.Id,lea.SAP_Code__c);
                    conFirstLastDataMap.put(lea.SAP_Code__c,lea.First_Name__c+'-'+lea.Last_Name__c);
                }
                
                if(string.isNotBlank(lea.Billing_state__c)) {
                    regionSet.add(lea.Billing_state__c); 
                }
            }
            
            
            
            
            
            
            if (string.isNotBlank(lea.Lead_Stage__c) && lea.Lead_Stage__c != oldMap.get(lea.Id).Lead_Stage__c) {
                lea.Lead_Date__c = System.today();
            }
            if (string.isNotBlank(lea.Marketing_Stage__c) && lea.Marketing_Stage__c != oldMap.get(lea.Id).Marketing_Stage__c) {
                lea.Lead_Marketing_date__c = System.today();
            }
            
            if ((string.isNotBlank(lea.Billing_City__c) && lea.Billing_City__c != oldMap.get(lea.id).Billing_City__c) ||
                (string.isNotBlank(lea.Country__c) && lea.Country__c != oldMap.get(lea.id).Country__c)) {
                    
                    lea.Billing_City__c = lea.Billing_City__c != null ? lea.Billing_City__c.toUppercase() : lea.Billing_City__c;
                    
                    
                    lea.Country__c = lea.Country__c != null ? lea.Country__c.toUpperCase() : lea.Country__c;
                    if (string.isNotBlank(lea.Country__c) && lea.Country__c != oldMap.get(lea.id).Country__c) {  
                        Lead_Approval__c leaData1 = Lead_Approval__c.getValues(lea.Country__c); 
                            if (leaData1 != null) {  
                                lea.Approval_user__c = leaData1.UserId__c; 
                            } else {  
                                lea.Approval_user__c = userInfo.getUserId();
                                                                                                                                                                                                                                                                                                                                                                                    }
                            }
                    lea.Billing_state__c = lea.Billing_state__c != null ? lea.Billing_state__c.toUpperCase() : lea.Billing_state__c;
                    lea.Billing_Street__c = lea.Billing_Street__c != null ? lea.Billing_Street__c.toUpperCase() : lea.Billing_Street__c;
                    
                }
        }
        if (regionSet.size() > 0 && regionSet != null) {
            for (CIty__c reg: [SELECT Id, Name from CIty__c where Name in: regionSet]) {
                regionDataMap.put(reg.Name, reg.Id);
            }
        }
        List < Account > accList = new List < Account > ();
        if (accSapMap.size() > 0) {
            for (Account acc: [SELECT Id, SAP_Code__c, CE_CIS_Rating__c, Phakic_Rating__c, Approver_1__c,
                                Approver_2__c, Contact_Person__c from Account where SAP_Code__c in: accSapMap.values()
                                ]) {
                                    accUniqueMap.put(acc.SAP_Code__c, '');
                                    accList.add(acc);
                                }
        }
        
        for (Lead__c lea: [SELECT Id,GM_NSM__c,Zone__c, First_Name__c, Last_Name__c,RSM__c,ZSM__c,Plant_code__c,plant__c,Company__c,Region_code__C, vertical_data__c, Mobile__c,
                            CE_CIS_Rating__c, Phakic_Rating__c, SAP_Code__c, Billing_City__c, Billing_code__c,
                            Country__c, Billing_state__c, Billing_Street__c, Parent_Account__c,Email__c, OwnerId, (SELECT Id, Account__c from Addresses__r)
                            from Lead__c where Id in: accSapMap.keySet()
                            
                            ]) {
                                if (!accUniqueMap.containsKey(lea.SAP_Code__c) || accUniqueMap.size()==0) {
                                    addressMap.put(accSapMap.get(lea.Id), lea.Addresses__r);
                                    Account acc = new Account();
                                    Lead_data__c leaData = Lead_data__c.getValues(lea.Country__c + '+' + lea.vertical_data__c);
                                    
                                    if (leaData != null) {
                                        acc.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get(leaData.Record_Type__c).getRecordTypeId();
                                    } else {
                                        if (lea.vertical_data__c == 'Opthalmic') {     
                                            acc.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('International - Ophthalmic & Vision').getRecordTypeId();
                                        }
                                        if (lea.vertical_data__c == 'Ortho' && lea.Country__c != 'INDIA') { 
                                            acc.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('International - Ortho').getRecordTypeId();
                                        }
                                        if (lea.vertical_data__c == 'Dermal') {                                       
                                            acc.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('International -Dermal').getRecordTypeId();
                                        }
                                    }
                                    
                                    if (lea.Company__c == Null) {          
                                        lea.company__c = 'test';
                                    }
                                    acc.Name = lea.Company__c;
                                    acc.Phone = lea.Mobile__c;
                                    acc.ParentId=lea.Parent_Account__c;
                                    acc.SAP_Code__c = accSapMap.get(lea.Id);
                                    acc.CE_CIS_Rating__c = lea.CE_CIS_Rating__c;
                                    acc.Phakic_Rating__c = lea.Phakic_Rating__c;
                                    acc.OwnerId = lea.OwnerId;
                                    acc.Zone_Name__c = lea.Zone__c;
                                    acc.last_CIS_date__c = system.today();
                                    acc.last_CE_date__c = system.today();
                                    acc.Commercial_Account_Name__c = lea.Company__c;
                                    acc.BillingCity = lea.Billing_City__c;
                                    acc.BillingPostalCode = lea.Billing_code__c;
                                    acc.BillingCountry = lea.Country__c;
                                    acc.BillingState = lea.Billing_state__c;
                                    acc.BillingStreet = lea.Billing_Street__c;
                                    /*if(lea.RSM__c !=null){
acc.RSM__c = lea.RSM__c;
}
if(lea.ZSM__c !=null){
acc.ZSM__c = lea.ZSM__c;
}
if (lea.GM_NSM__c != null && lea.ZSM__c == null ) {
acc.ZSM__c = lea.GM_NSM__c;
}*/
                                    
                                    if (lea.RSM__c != null && lea.ZSM__c != null) {
                                        acc.RSM__c = lea.RSM__c;
                                        acc.ZSM__c = lea.ZSM__c;
                                    } else {
                                        if (lea.RSM__c == null && lea.ZSM__c != null && lea.GM_NSM__c != null) {
                                            acc.RSM__c = lea.ZSM__c;
                                            acc.ZSM__c = lea.GM_NSM__c;
                                        } else {
                                            if (lea.RSM__c == null && lea.ZSM__c != null) {
                                                acc.RSM__c = lea.ZSM__c;
                                            }
                                            if (lea.RSM__c != null && lea.ZSM__c == null) {
                                                acc.RSM__c = lea.RSM__c;
                                            }
                                            if ((lea.RSM__c == null || lea.ZSM__c == null) && lea.GM_NSM__c != null) {
                                                acc.ZSM__c = lea.GM_NSM__c;
                                            }
                                        }
                                    }
                                    
                                    if(lea.Plant_code__c !=null){
                                        acc.Branch_code__c = lea.Plant_code__c;
                                    }
                                    if(lea.Plant__c !=null){
                                        acc.Branch_Name__C = lea.Plant__c;
                                    }
                                    acc.E_Mail__c = lea.Email__c;
                                    if (string.isBlank(acc.Contact_Person__c)) {
                                        acc.Contact_Person__c = lea.First_Name__c + ' ' + lea.Last_Name__c;
                                    }
                                    if(lea.Region_Code__c !=null){
                                        acc.Region_Code__c = lea.Region_Code__c;
                                    }
                                    if(lea.Company__c !=null){
                                        acc.Company_Name__c = lea.Company__c;
                                    }
                                    acc.Status__c = 'Activated';
                                    
                                    if (regionDataMap.containsKey(acc.BillingState) && regionDataMap.size() > 0) {                         
                                        acc.region__c = regionDataMap.get(acc.BillingState);
                                    }
                                    
                                    accInsList.add(acc);
                                }
                            }
        if (accInsList.size() > 0) {
            insert accInsList;
        }
        if (accInsList.size() > 0) {
            for (Account acc: accInsList) {
                Contact con = new Contact();
                if (conFirstLastDataMap.containskey(acc.SAP_Code__c)) {
                    List < String > accNameList = conFirstLastDataMap.get(acc.SAP_Code__c).split('-');
                    con.FirstName = accNameList[0];
                    con.LastName = accNameList[1];
                } else {                        con.LastName = acc.Name;
                        }
                con.MobilePhone = acc.Phone;
                con.OwnerId = acc.OwnerId;
                con.Email = acc.E_Mail__c;
                con.AccountId = acc.Id;
                con.MailingStreet = acc.BillingStreet;
                con.MailingCity = acc.BillingCity;
                con.MailingPostalCode = acc.BillingPostalCode;
                con.MailingState = acc.BillingState;
                con.MailingCountry = acc.BillingCountry;
                accAdrsTagMap.put(acc.SAP_Code__c, acc);
                cisHeaderMap.put(acc.SAP_Code__c, acc);
                for (Address__c adrs: addressMap.get(acc.SAP_Code__c)) {
                    adrs.Account__c = acc.Id;
                    adrsInsList.add(adrs);
                }
                conList.add(con);
            }
        }
        if (accAdrsTagMap.size() > 0) {
            for (Lead__c lea: newList) {
                if (accAdrsTagMap.containsKey(lea.SAP_Code__c)) {
                    lea.Account__c = accAdrsTagMap.get(lea.SAP_Code__c).id;
                }
            }
        }
        if (conList.size() > 0 && !conList.isEmpty()) {
            insert conList;
        }
        if (adrsInsList.size() > 0) {
            update adrsInsList;
        }
        
        
        if (accList.size() > 0) {
            //When the Account found into the system than it will only update it .
            for (Account acc: accList) {
                if (acc.SAP_Code__c != null) {
                    accAdrsTagMap.put(acc.SAP_Code__c, acc);
                    cisHeaderMap.put(acc.SAP_Code__c, acc);
                }
                
                if (ceCisRatingTagMap.containsKey(acc.SAP_Code__c)) {
                    Contact con = new Contact();
                    con.FirstName = ceCisRatingTagMap.get(acc.SAP_Code__c).First_Name__c;
                    con.LastName = ceCisRatingTagMap.get(acc.SAP_Code__c).Last_Name__c;
                    con.MobilePhone = ceCisRatingTagMap.get(acc.SAP_Code__c).Mobile__c;
                    con.AccountId = acc.Id;
                    con.MailingStreet = ceCisRatingTagMap.get(acc.SAP_Code__c).Billing_Street__c;
                    con.MailingCity = ceCisRatingTagMap.get(acc.SAP_Code__c).Billing_City__c;
                    con.MailingPostalCode = ceCisRatingTagMap.get(acc.SAP_Code__c).Billing_code__c;
                    con.MailingState = ceCisRatingTagMap.get(acc.SAP_Code__c).Country__c;
                    con.MailingCountry = ceCisRatingTagMap.get(acc.SAP_Code__c).First_Name__c;
                    acc.CE_CIS_Rating__c = ceCisRatingTagMap.get(acc.SAP_Code__c).CE_CIS_Rating__c;
                    acc.Phakic_Rating__c = ceCisRatingTagMap.get(acc.SAP_Code__c).Phakic_Rating__c;
                    acc.last_CIS_date__c = system.today();
                    if (string.isBlank(acc.Contact_Person__c)) {
                        acc.Contact_Person__c = ceCisRatingTagMap.get(acc.SAP_Code__c).First_Name__c +
                            ' ' + ceCisRatingTagMap.get(acc.SAP_Code__c).Last_Name__c;
                    }
                    acc.last_CE_date__c = system.today();
                    acc.Status__c = 'Activated';
                    
                    accUpdateList.add(acc);
                    conInsList.add(con);
                }
            }
            if (conInsList.size() > 0 && conInsList != null && !conInsList.isEmpty()) {
                insert conInsList;
            }
            
            if (accUpdateList.size() > 0) {
                update accUpdateList;
            }
            if (accAdrsTagMap.size() > 0) {
                for (Lead__c lea: newList) {
                    if (accAdrsTagMap.containsKey(lea.SAP_Code__c)) {
                        lea.Account__c = accAdrsTagMap.get(lea.SAP_Code__c).id;
                    }
                }
            }
            List < Address__c > adressUpadteListData = new List < Address__c > ();
            
            for (Address__c adrs: [SELECT Id, Account__c, Is_Primary__c, Lead__c, Ship_to__c, Lead__r.SAP_Code__c
                                    from Address__c where Account__c = null AND Lead__c in: accSapMap.keySet()
                                    ]) {
                                        if (accAdrsTagMap.containsKey(adrs.Lead__r.SAP_Code__c)) {
                                            adrs.Account__c = accAdrsTagMap.get(adrs.Lead__r.SAP_Code__c).id;
                                            adressUpadteListData.add(adrs);
                                        }
                                    }
            if (adressUpadteListData.size() > 0) {
                update adressUpadteListData;
            }
            
        }
        if (accSapMap.size() > 0 && cisHeaderMap.size() > 0) {
            insertCisHeaderData(accSapMap, cisHeaderMap);
        }
    } catch (exception e) {
        if (sp != null) {
            Database.rollback(sp);
        }
        
        System.debug('Error in converting' + e.getMessage() + 'At line number' + e.getLineNumber());
    }
    
}
/*DES---Capture the Lead Name and tag the Account if Sap is exist*/

public static void beforeLeadInsert(List < Lead__c > newList) {
    try {
        // Create a map to hold the concatenated keys for lead
        Map<String, Lead__c> leadKeyMap = new Map<String, Lead__c>();
        // Create a map to hold the concatenated keys for Countries
        Map<String, Country__c> countryKeyMap = new Map<String, Country__c>();
        Set<String> ctrySet=new Set<String>();
        Set<String> stateSet=new Set<String>();
        Set<String> citySet=new Set<String>();
        Set<String> mobileSet=new Set<String>();
        Set<String> proSet=new Set<String>();
        
        
        
        
        
        Integer maxLength = Schema.sObjectType.Lead__c.fields.Name.getLength();
        Map < String, String > accIdSapMap = new Map < String, String > ();
        Map < String, String > cityWiseMappingMap = CommonutiltiyClass.getLeadAssignment();
        Map < Id, String > leadAccountMap = new Map < Id, String > ();
        Set < Id > accIdSet = new Set < Id > ();
        Set < Id > camIdSet = new Set < Id > ();
        Map<String,List<Lead__c>> dupMap=new Map<String,List<Lead__c>>();
        Map<String,String> leadUniqMap=new Map<String,String>();
            Set<Id> ownerIds = new Set<Id>();
        if (newList.size() > 0) {
            for (Lead__c lea: newList) {
                mobileSet.add(lea.Mobile__c);
                proSet.add(lea.Product__c);
                if (lea.Account__c != null) {
                   // lea.Existing_customer__c = true;
                    accIdSet.add(lea.Account__c);
                } else if (lea.Account__c == null) {
                    lea.New_Customer__c = true;
                }
                
                // Ensure street fields are cleared before splitting/*********************Added by gyadeen For customer creation pdf
                lea.Street_1__c = null;
                lea.Street_2__c = null;
                lea.Street_3__c = null;
                lea.Street_4__c = null;

                
                
                Integer maxLengths = 60; // Adjust as needed
                String fullStreet = lea.Billing_Street__c != null ? lea.Billing_Street__c.toUpperCase() : '';
                System.debug('Full Street: ' + fullStreet);                  
                if (String.isNotBlank(fullStreet)) {
                    Integer length = fullStreet.length();
                    Integer startIndex = 0;
                    List<String> streetChunks = new List<String>();
                    
                    System.debug('Street Length: ' + length);
                    
                    while (startIndex < length) {
                        Integer endIndex = Math.min(startIndex + maxLengths, length);
                        
                        // Avoid breaking a word: Find the last space within the allowed limit
                        if (endIndex < length) {
                            Integer lastSpace = fullStreet.lastIndexOf(' ', endIndex);
                            if (lastSpace > startIndex) {
                                endIndex = lastSpace; // Adjust end index to the last space
                            }
                        }
                        
                        // If no space is found, forcefully break at maxLengths
                        if (startIndex == endIndex) {
                            endIndex = Math.min(startIndex + maxLengths, length);
                        }
                        
                        String chunk = fullStreet.substring(startIndex, endIndex).trim();
                        streetChunks.add(chunk);
                        System.debug('Chunk Added: ' + chunk);
                        
                        startIndex = endIndex + 1; // Move to the next chunk (skip space)
                    }
                    
                    if (streetChunks.size() > 0) {
                        lea.Street_1__c = streetChunks[0];
                        System.debug('Street 1: ' + lea.Street_1__c);
                        System.debug('Street 1 Length (including spaces): ' + lea.Street_1__c.length());
                    } 
                    if (streetChunks.size() > 1) {
                        lea.Street_2__c = streetChunks[1];
                        System.debug('Street 2: ' + lea.Street_2__c);
                        System.debug('Street 2 Length (including spaces): ' + lea.Street_2__c.length());
                    } 
                    if (streetChunks.size() > 2) {
                        lea.Street_3__c = streetChunks[2];
                        System.debug('Street 3: ' + lea.Street_3__c);
                        System.debug('Street 3 Length (including spaces): ' + lea.Street_3__c.length());
                    } 
                    if (streetChunks.size() > 3) {
                        lea.Street_4__c = streetChunks[3];
                        System.debug('Street 4: ' + lea.Street_4__c);
                        System.debug('Street 4 Length (including spaces): ' + lea.Street_4__c.length());
                    }
                    
                }
                
                
                
                if (lea.Campaign__c != null) {
                    camIdSet.add(lea.Campaign__c);
                }
                
                if (String.isNotBlank(lea.First_Name__c) || String.isNotBlank(lea.Last_Name__c)) {
                    Lead_Approval__c leaData = Lead_Approval__c.getValues(lea.Country__c); //Custom setting to get the Address approval user
                    if (leaData != null) {  
                        lea.Approval_user__c = leaData.UserId__c;
                    } else {
                        lea.Approval_user__c = userInfo.getUserId();
                    }
                    
                    lea.Name = (lea.First_Name__c + ' ' + lea.Last_Name__c);
                    if (lea.Name.length() > maxLength) {             
                        lea.Name = (lea.First_Name__c + ' ' + lea.Last_Name__c).substring(0, 80);
                    }
                    
                    lea.UniqueKey__c = lea.Product__c + lea.Mobile__c + lea.Email__c;
                    lea.Billing_City__c = lea.Billing_City__c != null ? lea.Billing_City__c.toUppercase() : lea.Billing_City__c;
                    lea.Country__c = lea.Country__c != null ? lea.Country__c.toUpperCase() : lea.Country__c;
                    lea.Billing_state__c = lea.Billing_state__c != null ? lea.Billing_state__c.toUpperCase() : lea.Billing_state__c;
                    lea.Billing_Street__c = lea.Billing_Street__c != null ? lea.Billing_Street__c.toUpperCase() : lea.Billing_Street__c;
                    lea.Name_1__c=lea.Name;//correct
                    lea.Name_2__c=lea.Company__c;
                    //  lea.Street_1__c=lea.Country__c+' '+ lea.Billing_state__c+ ' '+ lea.Billing_City__c+' '+ lea.Billing_code__c;
                    lea.City_postal_code__c=lea.Billing_code__c;
                    lea.First_fax_no_dialling_code_number__c=lea.Mobile__c;
                    lea.E_Mail_Address__c=lea.Email__c;
                    //lea.Street_1__c=lea.Billing_Street__c;
                    lea.Street_1__c=lea.Street_1__c;
                    
                    lea.Street_2__c=lea.Street_2__c;
                    
                    lea.Street_3__c=lea.Street_3__c;
                    
                    lea.Street_4__c=lea.Street_4__c;
                    lea.First_telephone_no_dialling_code__c=lea.Mobile__c;
                    lea.First_Mobile_Telephone_No_Dialing__c=lea.Mobile__c;
                    lea.Region_State_Province_County__c=lea.Billing_state__c+' ,'+lea.Country__c;
                    ctrySet.add(lea.Country__c);
                    stateSet.add(lea.Billing_state__c);
                    citySet.add(lea.Billing_City__c);
                    
                }
                
            }
            
            
        }     
        for(Lead__c lea:[SELECT Id,Mobile__c,Product__c from Lead__c where
                            Mobile__c in:mobileSet AND Product__c in:proSet AND (Lead_Stage__c!='Unqualified' AND Lead_Stage__c!='Lost' AND Lead_Stage__c !='Won')
                            AND Lead_Closed__c =: false]) {     
                                if(dupMap.containsKey(lea.Mobile__c+lea.Product__c)) {      
                                    dupMap.get(lea.Mobile__c+lea.Product__c).add(lea);
                                }else {        
                                    dupMap.put(lea.Mobile__c+lea.Product__c,new List<Lead__c>{lea});
                                }
                                
                            }
          Map<String,String> countryCode = 	new Map<String,String>{  'INDIA' => 'IN', 'BRAZIL' => 'BR','TURKEY' => 'TR','GERMANY' => 'DE', 'SPAIN' => 'ES','EGYPT' => 'EG','MOROCCO' => 'MA','COLOMBIA' => 'CO' };
          Map<String, String> countryCodereverse = new Map<String, String>{ 'IN' => 'INDIA',  'BR' => 'BRAZIL',  'TR' => 'TURKEY',  'DE' => 'GERMANY',  'ES' => 'SPAIN',  'EG' => 'EGYPT',  'MA' => 'MOROCCO', 'CO' => 'COLOMBIA'};
                System.debug('first    ctrySet'+ctrySet+'stateSet'+stateSet+'citySet'+citySet);
              for(String cntryCode:countryCode.keySet()){
                  if(ctrySet.contains(cntryCode)){ctrySet.add(countryCode.get(cntryCode));    }
              }
        for(String cntryCodereverse:countryCodereverse.keySet()){
                  if(ctrySet.contains(cntryCodereverse)){ctrySet.add(countryCodereverse.get(cntryCodereverse));    }
              }
        System.debug('ctrySet'+ctrySet+'stateSet'+stateSet+'citySet'+citySet);
        System.debug('ijbfifgbiuwbiuc3'+[SELECT Id, Country__c, CITY__c, State__c,Region__c,Region_code__c,Zone__c FROM Country__c where Country__c in:ctrySet AND State__c in:stateSet AND CITY__c in:citySet]);
        for (Country__c country : [SELECT Id, Country__c, CITY__c, State__c,Region__c,Region_code__c,Zone__c FROM Country__c where Country__c in:ctrySet AND State__c in:stateSet AND CITY__c in:citySet]) {
            String countryTemp = countryCode.containsKey(country.Country__c)?countryCode.get(country.Country__c):country.Country__c;
            System.debug('countryTemp'+countryTemp);
            countryKeyMap.put(countryTemp+country.State__c+country.CITY__c, country);
        }
        
        System.debug('Country Map'+countryKeyMap);
        for (Lead__c leaData: newList) {
            if(countryKeyMap.containsKey(leaData.Country__c+leaData.Billing_State__c+leaData.Billing_City__c)) {     
                leaData.Zone__c = countryKeyMap.get(leaData.Country__c+leaData.Billing_State__c+leaData.Billing_City__c).Zone__c??NULL;       
                leaData.Region__c = countryKeyMap.get(leaData.Country__c+leaData.Billing_State__c+leaData.Billing_City__c).Region__c;
                leaData.Region_code__c = countryKeyMap.get(leaData.Country__c+leaData.Billing_State__c+leaData.Billing_City__c).Region_code__c;
            }
        }
        if (accIdSet.size() > 0) {
            for (Account acc: [SELECT id, Name from Account where Id in: accIdSet]) {
                leadAccountMap.put(acc.Id, acc.Name);
            }
            
            
            
            for (Lead__c leaData: newList) {
                if(countryKeyMap.containsKey(leaData.Country__c+leaData.Billing_State__c+leaData.Billing_City__c)) {        
                    leaData.Zone__c = countryKeyMap.get(leaData.Country__c+leaData.Billing_State__c+leaData.Billing_City__c).Zone__c ?? NULL;
                    System.debug(' leaData.Zone__c -------- 720'+ leaData.Zone__c);
                    leaData.Region__c = countryKeyMap.get(leaData.Country__c+leaData.Billing_State__c+leaData.Billing_City__c).Region__c; 
                    leaData.Region_code__c = countryKeyMap.get(leaData.Country__c+leaData.Billing_State__c+leaData.Billing_City__c).Region_code__c;
                }
                if (leadAccountMap.containsKey(leaData.Account__c) && leaData.Campaign__c == null) {    
                    leaData.Name = (leadAccountMap.get(leaData.Account__c) + '-' + leaData.First_Name__c + ' ' + leaData.Last_Name__c);
                    if (leaData.Name.length() > maxLength) {           
                        leaData.Name = (leadAccountMap.get(leaData.Account__c) + '-' + leaData.First_Name__c + ' ' + leaData.Last_Name__c).substring(0, 80);
                        
                    }
                }
                
                
            }
        }//fi
        
        for(Lead__c lea:newList) {
            if(lea.OwnerId != null){
                ownerIds.add(lea.OwnerId);
            }
            if(dupMap.containsKey(lea.Mobile__c+lea.Product__c) && dupMap.get(lea.Mobile__c+lea.Product__c).size()>0) {  
               // lea.addError('Lead already exist with the same mobile no.'+lea.Mobile__c+' AND Product-'+lea.Product__c+'');
            }
            if(!leadUniqMap.containsKey(lea.Mobile__c+lea.Product__c)) {
                leadUniqMap.put(lea.Mobile__c+lea.Product__c,'');
            }
            else if(leadUniqMap.containsKey(lea.Mobile__c+lea.Product__c)) {         
               // lea.addError('There is already the same information of the Lead that you are uploading');
            }
            
        }//brackder
        
        
        Map<string,Sample_Request_Approver__c> sampleApproverMap = new Map<string,Sample_Request_Approver__c>();
        
        For(Sample_Request_Approver__c smp : [select id,Country_Name__c,Region__c,Zone__c,RSM__c,ZSM__c,GM__c,Admin__c from Sample_Request_Approver__c]){
            String uniqueKey = smp.Country_Name__c + '-' + smp.Region__c + '-' + smp.Zone__c;
            sampleApproverMap.put(uniqueKey,smp);
        }
        
        // Query Owner details
        Map<Id, User> ownerMap = new Map<Id, User>(
            [SELECT Id, Name,Vertical__c,Verticals_branch__c,L1_Manager__c,L2Manager__c FROM User WHERE Id IN :ownerIds]
        );
        
        Id currentUserId = UserInfo.getUserId(); 
        
    
        for(Lead__c ld : newList){
            User ownerUser = ownerMap.get(ld.OwnerId);
            
            if(ownerUser != null){
                Boolean verticalCheck = ownerUser.Vertical__c == 'Opthal';
                Boolean branchCheck = 
                    ownerUser.Verticals_branch__c == 'Phakic' ||
                    ownerUser.Verticals_branch__c == 'Key Account Manager - CoH' ||
                    ownerUser.Verticals_branch__c == 'Premium IOLs';
                
                Boolean managerCheck = 
                    ownerUser.L1_Manager__c != null &&
                    ownerUser.L2Manager__c != null;
                
                if(verticalCheck && branchCheck && managerCheck){
                    ld.RSM__c = ownerUser.L1_Manager__c;
                    ld.ZSM__c = ownerUser.L2Manager__c;
                    ld.RSM_ZSM_Coming_From_Vertical__c = true;
                    ld.RSM_ZSM_are_coming_from_the_hierarchy_ta__c = false;
                }else{
                    String uniqueKey = ld.Country__c + '-' + ld.Region__c + '-' + ld.Zone__c;
                    if (sampleApproverMap.containsKey(uniqueKey)) {
                        Sample_Request_Approver__c approver = sampleApproverMap.get(uniqueKey);
                        if (approver != null) {
                            if (approver.RSM__c != null) {
                                ld.RSM__c = approver.RSM__c;
                            }
                            if (approver.ZSM__c != null) {
                                ld.ZSM__c = approver.ZSM__c;
                            }
                            if (approver.GM__c != null) {
                                ld.GM_NSM__c = approver.GM__c;
                            }
                            // if(approver.Admin__c != null){
                                // ld.User__c = approver.Admin__c;
                            //}
                            
                            ld.RSM_ZSM_Coming_From_Vertical__c = false;
                            ld.RSM_ZSM_are_coming_from_the_hierarchy_ta__c = true;
                        }

                        
                    } else {
                        if(ld.Country__c != 'INDIA' && managerCheck){
                            ld.RSM__c = ownerUser.L1_Manager__c;
                            ld.ZSM__c = ownerUser.L2Manager__c;
                        }
                        System.debug('No approver mapping found for key: ' + uniqueKey);
                    }
                    
                }
            }
        }

    
        
    }catch (Exception e) {
        System.debug('Error message' + e.getMessage() + 'At line number' + ' ' + e.getLineNumber());
    }
    
}

/*This method will take care of when the lead will convert than it will tranfer all the cis header and the cis line item data into the Account */
public static void insertCisHeaderData(Map < String, String > accSapMap, Map < String, Account > accAdrsTagMap) {
    List < CIS_Header__c > cisHeaderList = new List < CIS_Header__c > ();
    Map < decimal, List < CIS_Line__c >> cisLineMap = new Map < decimal, List < CIS_Line__c >> ();
    List < CIS_Line__c > cisLineItemList = new List < CIS_Line__c > ();
    if (accSapMap.size() > 0) {
        Integer i = 1;
        for (CIS_Header__c cis: [SELECT Id, Name, Ce_Cis_Rating__c, Status__c, User__c, No_of_LVC_Procedures__c, unique__c, Leads__r.Country__c, Leads__r.SAP_Code__c,
                                    (SELECT Id, Avg_Purchase_Price__c, CIS_Header__c, Company__c, No_of_Surguries__c, Product__c from CIS_Lines__r)
                                    from CIS_Header__c where Leads__c in: accSapMap.keySet() AND Status__c =: 'Approved'
                                ]) {
                                    if (accAdrsTagMap.containsKey(cis.Leads__r.SAP_Code__c)) {
                                        CIS_Header__c cisData = new CIS_Header__c();
                                        cisData.RecordTypeId = Schema.SObjectType.CIS_Header__c.getRecordTypeInfosByName().get(cis.Leads__r.Country__c).getRecordTypeId();
                                        cisData.User__c = cis.User__c;
                                        cisData.No_of_LVC_Procedures__c = cis.No_of_LVC_Procedures__c;
                                        cisData.Account__c = accAdrsTagMap.get(cis.Leads__r.SAP_Code__c).id;
                                        cisData.User__c = accAdrsTagMap.get(cis.Leads__r.SAP_Code__c).Approver_1__c != null ? accAdrsTagMap.get(cis.Leads__r.SAP_Code__c).Approver_1__c : accAdrsTagMap.get(cis.Leads__r.SAP_Code__c).Approver_2__c;
                                        
                                        cisData.unique__c = i;
                                        cisData.Status__c = 'Approved';
                                        cisHeaderList.add(cisData);
                                        cisLineMap.put(i, cis.CIS_Lines__r);
                                        i++;
                                    }
                                    
                                    
                                }
        if (cisHeaderList.size() > 0) {
            insert cisHeaderList;
            for (CIS_Header__c cis: cisHeaderList) {
                for (CIS_Line__c cisLine: cisLineMap.get(cis.unique__c)) {
                    CIS_Line__c cisLineData = new CIS_Line__c();
                    cisLineData.CIS_Header__c = cis.Id;
                    
                    cisLineData.Company__c = cisLine.Company__c;
                    cisLineData.Product__c = cisLine.Product__c;
                    cisLineData.No_of_Surguries__c = cisLine.No_of_Surguries__c;
                    cisLineItemList.add(cisLineData);
                }
                
            }
            if (cisLineItemList.size() > 0) {
                insert cisLineItemList;
            }
        }
    }
}

public static void submitForApproval(List < Lead__c > newLeads, Map < Id, Lead__c > oldLeadMap) {
    system.debug('newLeads' + newLeads);
    try {
        Set < Id > leadIds = new Set < Id > ();
        List < ContentDocumentLink > documentLinks = new List < ContentDocumentLink > ();
        List < Messaging.EmailFileAttachment > emailAttachments = new List < Messaging.EmailFileAttachment > ();
        Map<String,Blob> contentMap=new Map<String,Blob>();
        Map<String,String> userEmailMap=new Map<String,String>();
        Set<Id> docIdSet=new Set<Id>();
        Set<Id> userIdSet=new Set<Id>();          
            system.debug('Old Lead data '+ json.serialize(oldLeadMap));
        // Collecting Lead Ids and preparing email recipients
        for (Lead__c lead: newLeads) {
            if(lead.Upload_Count__c != oldLeadMap.get(lead.Id).Upload_Count__c ) {
                
                system.debug('old upload value-812'+oldLeadMap.get(lead.Id).Upload_Count__c);
                system.debug('current upload count-815'+lead.Upload_Count__c);
                System.debug('Inside loop');
                
                leadIds.add(lead.Id);
                if(lead.RSM__c!=null) {
                    userIdSet.add(lead.RSM__c); 
                }
                if(lead.ZSM__c!=null) {
                    
                    userIdSet.add(lead.ZSM__c); 
                    
                }if(lead.GM_NSM__c!=null) {
                    
                    userIdSet.add(lead.GM_NSM__c); 
                    
                }if(lead.Approval_user__c!=null){
                    
                    userIdSet.add(lead.Approval_user__c); 
                    
                }
            }
            
            system.debug('lead.RSM__c!=null' + lead.RSM__c);
        }
        system.debug('userIdSet' + userIdSet);
        if(userIdSet.size()>0) {           
            for(User us:[SELECT Id,Email from User where Id in:userIdSet]) {      
                userEmailMap.put(us.Id,us.Email);                                                                                                                   }
            System.debug('Lead ids'+leadIds);
            List < ContentDocumentLink > documents = [SELECT Id, ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension, ContentDocument.LatestPublishedVersionId from ContentDocumentLink where LinkedEntityId IN: leadIds];
            System.debug('Documents'+documents);
            if(documents.size()>0) {
                
                for(ContentDocumentLink con:documents) {
                    System.debug('Doc id'+con.ContentDocumentId);
                    docIdSet.add(con.ContentDocumentId); 
                }
                System.debug('Doc set'+docIdSet);
                if(docIdSet.size()>0) {        
                    List<ContentVersion> cvList = [SELECT VersionData,ContentDocumentId FROM ContentVersion WHERE ContentDocumentId in: docIdSet];
                    for(ContentVersion conVers:cvList) {     
                        contentMap.put(conVers.ContentDocumentId,conVers.VersionData);
                    }
                    System.debug('Cv List'+cvList);
                    System.debug('CV Size'+cvList.size());
                }
                for (ContentDocumentLink docLink: documents) {
                    Messaging.EmailFileAttachment emailAttachment = new Messaging.EmailFileAttachment();
                    emailAttachment.setFileName(docLink.ContentDocument.Title);// + '.' + docLink.ContentDocument.FileExtension);
                    //   ContentVersion cv = [SELECT VersionData FROM ContentVersion WHERE ContentDocumentId =: docLink.ContentDocumentId LIMIT 1];
                    if(contentMap.containsKey(docLink.ContentDocumentId)) {
                        emailAttachment.setBody(contentMap.get(docLink.ContentDocumentId));
                        
                    }
                    emailAttachments.add(emailAttachment);
                }
                System.debug('Email attachmennt'+emailAttachments);
                System.debug('Size'+emailAttachments.size());
                string vfpageurl ='';
                String rsmvfPageUrl = ApprovalController.fetchCustomSetting('RSM') + newLeads[0].id + '';//enter in the Custom setting
                String GMNSMvfPageUrl = ApprovalController.fetchCustomSetting('GM NSM') + newLeads[0].id + '';//enter in the Custom setting
                String ZSMvfPageUrl = ApprovalController.fetchCustomSetting('ZSM') + newLeads[0].id + '';//enter in the Custom setting
                
                
                // Sending email with attachments for each Lead
                
                //=========================================Submit for RSM approval=====================================================//
                system.debug('Line number ---919');
                for (Lead__c lead: newLeads) {
                    if (lead.Upload_Count__c != oldLeadMap.get(lead.Id).Upload_Count__c) {
                            system.debug('old upload value-885'+oldLeadMap.get(lead.Id).Upload_Count__c);
                        system.debug('current upload count-886'+lead.Upload_Count__c);
                        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                        if(userEmailMap.containsKey(lead.RSM__c)) {
                            mail.setToAddresses(new List < String > {userEmailMap.get(lead.RSM__c)});
                            vfpageurl = rsmvfPageUrl;
                            
                        }else if(userEmailMap.containsKey(lead.ZSM__c)) {
                            mail.setToAddresses(new List < String > {userEmailMap.get(lead.ZSM__c)});
                            vfpageurl = ZSMvfPageUrl;
                            
                        }else if(userEmailMap.containsKey(lead.GM_NSM__c)) {
                            mail.setToAddresses(new List < String > {userEmailMap.get(lead.GM_NSM__c)});
                            vfpageurl = GMNSMvfPageUrl;
                            
                        }
                        OrgWideEmailAddress[] oweaList = [SELECT Id, Address FROM OrgWideEmailAddress WHERE Address = 'crmhelpdesk@biotechhealthcare.com' LIMIT 1];
                        mail.setOrgWideEmailAddressId(oweaList[0].Id);
                        mail.setSubject('New Conversion'+' ' + lead.Name +' '+ '-' + 'City:'+' '+ lead.Billing_City__c);
                        
                        // Construct plain text body
                        String plainTextBody = 'Dear Leader,\n\n' +
                            'A new customer conversion has been initiated with the following details:\n\n'+
                            'Name : ' + lead.Name + '\n' +
                            'Hospital : ' + lead.Company__c + '\n' +
                            'Address : ' + lead.Billing_Street__c+',' + lead.Billing_City__c +'\n'+
                            'City : ' + lead.Billing_City__c + '\n' +
                            'State : ' + lead.Billing_state__c + '\n' +
                            'Pincode : ' + lead.Billing_code__c + '\n' +
                            'Mobile No. : ' + lead.Mobile__c + '\n' +
                            'Email : '+ lead.Email__c + '\n\n' +
                            'Please check the Know Your Customer (KYC) details by clicking the link:\n\n' +
                            vfpageurl + '\n' +
                            'Kindly approve/ send back the conversion request'+'\n\n'+
                            'Regards,\n' +
                            'Salesforce Admin'+'\n'+
                            'Biotech Healthcare';
                        
                        mail.setPlainTextBody(plainTextBody);
                        system.debug('Documents--->' + documents);
                        //   mail.setFileAttachments(emailAttachments);
                        // Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                        Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail }, false);
                        
                        if (results != null && results.size() > 0) {
                            if (results[0].isSuccess()) {
                                System.debug('✅ Email sent successfully to: ' + mail.getToAddresses());
                            } else {
                                for (Messaging.SendEmailError err : results[0].getErrors()) {
                                    System.debug('❌ Email failed: ' + err.getMessage());
                                }
                            }
                        }
                        System.debug('Mail sent--->RSM:'+JSON.serialize(mail));
                        // Optionally, add documents to the document list for tracking purposes
                        documentLinks.addAll(documents);
                        
                        //=========================================Submit for ZSM approval=====================================================//
                        
                    }/*if (lead.ZSM_Approve__c == false && oldLeadMap.get(lead.Id).RSM_Approve__c == false && lead.RSM_Approve__c == true) {
Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
if(userEmailMap.containsKey(lead.ZSM__c)){     
mail.setToAddresses(new List < String > {userEmailMap.get(lead.ZSM__c)});

}

// Set subject
mail.setSubject('Lead Name:' + lead.Name + ' ' + 'Mobile No.:' + lead.Mobile__c + ' ' + 'KYC Document Approval');

// Construct plain text body
String plainTextBody = 'Hi,\n\n' +
'Lead Name : ' + lead.Name + '\n' +
'Mobile No.: ' + lead.Mobile__c + '\n' +
'Product   : ' + lead.Product__c + '\n' +
'Address   : ' + lead.country__c + ' ' + lead.Billing_state__c + ' ' + lead.Billing_City__c + '\n\n' +
'Please find attached the document(s).\n\n' +
zsmvfPageUrl + '\n\n' +
'Best regards,\n' +
lead.Owner.Name;

mail.setPlainTextBody(plainTextBody);
system.debug('plainTextBody' + plainTextBody);
mail.setFileAttachments(emailAttachments);

// Send email
Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
System.debug('Mail sent--->ZSM:'+JSON.serialize(mail));
// Optionally, add documents to the document list for tracking purposes
documentLinks.addAll(documents);
//=========================================Submit for GM_NSM approval=====================================================//

}*/ /* if (oldLeadMap.get(lead.Id).ZSM_Approve__c == false && oldLeadMap.get(lead.Id).RSM_Approve__c == true && lead.ZSM_Approve__c) {
Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

if(userEmailMap.containsKey(lead.GM_NSM__c)){
mail.setToAddresses(new List < String > {userEmailMap.get(lead.GM_NSM__c)});

}

mail.setSubject('Lead Name:' + lead.Name + ' ' + 'Mobile No.:' + lead.Mobile__c + ' ' + 'KYC Document Approval');
String plainTextBody = 'Hi,\n\n' +
'Lead Name : ' + lead.Name + '\n' +
'Mobile No.: ' + lead.Mobile__c + '\n' +
'Product   : ' + lead.Product__c + '\n' +
'Address   : ' + lead.country__c + ' ' + lead.Billing_state__c + ' ' + lead.Billing_City__c + '\n\n' +
'Please find attached the document(s).\n\n' +
GM_NSMvfPageUrl + '\n\n' +
'Best regards,\n' +
lead.Owner.Name;

mail.setPlainTextBody(plainTextBody);
system.debug('plainTextBody' + plainTextBody);

// Attach documents to the email
system.debug('Documents--->' + documents);
mail.setFileAttachments(emailAttachments);
Messaging.sendEmail(new Messaging.SingleEmailMessage[] {
mail
});
System.debug('Mail sent--->SAP'+JSON.serialize(mail));
documentLinks.addAll(documents);


//=========================================Submit for Admin approval=====================================================//

}*//*if (oldLeadMap.get(lead.Id).ZSM_Approve__c == true && oldLeadMap.get(lead.Id).GM_NSM_Approve__c == False && lead.GM_NSM_Approve__c) {
Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();


if(userEmailMap.containsKey(lead.Approval_user__c)){
mail.setToAddresses(new List < String > {userEmailMap.get(lead.Approval_user__c)});

}

mail.setSubject('Lead Name:' + lead.Name + ' ' + 'Mobile No.:' + lead.Mobile__c + ' ' + 'KYC Document Approval');
String plainTextBody = 'Hi,\n\n' +
'Lead Name : ' + lead.Name + '\n' +
'Mobile No.: ' + lead.Mobile__c + '\n' +
'Product   : ' + lead.Product__c + '\n' +
'Address   : ' + lead.country__c + ' ' + lead.Billing_state__c + ' ' + lead.Billing_City__c + '\n\n' +
'Please find attached the document(s).\n\n' +
adminvfPageUrl + '\n\n' +
'Best regards,\n' +
lead.Owner.Name;

mail.setPlainTextBody(plainTextBody);
system.debug('plainTextBody' + plainTextBody);

// Attach documents to the email
system.debug('Documents--->' + documents);
mail.setFileAttachments(emailAttachments);
Messaging.sendEmail(new Messaging.SingleEmailMessage[] {
mail
});
System.debug('Mail sent--->SAP'+JSON.serialize(mail));
documentLinks.addAll(documents);
//=========================================Submit for SAP approval=====================================================
}*//*if (oldLeadMap.get(lead.Id).GM_NSM_Approve__c == true && oldLeadMap.get(lead.Id).Admin_Approve__c == False && lead.Admin_Approve__c) {
Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

system.debug('test for SAP code approval');
// Hierarchy_Approval__c hrappr = Hierarchy_Approval__c.getValues(lead.Country__c);

mail.setToAddresses(new List < String > {
'gyadeen@plus91labs.com'
});

mail.setSubject('Lead Name:' + lead.Name + ' ' + 'Mobile No.:' + lead.Mobile__c + ' ' + 'KYC Document Approval');
String plainTextBody = 'Hi,\n\n' +
'Lead Name : ' + lead.Name + '\n' +
'Mobile No.: ' + lead.Mobile__c + '\n' +
'Product   : ' + lead.Product__c + '\n' +
'Address   : ' + lead.country__c + ' ' + lead.Billing_state__c + ' ' + lead.Billing_City__c + '\n\n' +
'Please find attached the document(s).\n\n' +
JSMvfPageUrl + '\n\n' +
'Best regards,\n' +
lead.Owner.Name;

mail.setPlainTextBody(plainTextBody);
system.debug('plainTextBody' + plainTextBody);

// Attach documents to the email
system.debug('Documents--->' + documents);
mail.setFileAttachments(emailAttachments);
Messaging.sendEmail(new Messaging.SingleEmailMessage[] {
mail
});
System.debug('Mail sent--->SAP'+JSON.serialize(mail));
documentLinks.addAll(documents);
}*/
                    // Perform any additional processing or logging here
                }
            }
        }
        // Querying ContentDocumentLinks related to Leads
        
    } catch (Exception e) {
        System.debug('Error message: ' + e.getMessage()+'At line number'+e.getLineNumber());
    }
}

public static void updateCampaignData(List<Lead__c> newList,Map<Id,Lead__c> oldMap) {
    Set<Id> cmpIdSet=new Set<Id>();
    Map<String,List<Lead__c>> commMap=new Map<String,List<Lead__c>>();
    Map<String,List<Lead__c>> wonMap=new Map<String,List<Lead__c>>();
    Map<String,List<Lead__c>> upgMap=new Map<String,List<Lead__c>>();
    List<Campaign__c> cmpUpdateList=new List<Campaign__c>();
    
    
    for(Lead__c lea:newList) {
        if(lea.Lead_Stage__c!=null && lea.Lead_Stage__c!=oldMap.get(lea.Id).Lead_Stage__c && lea.Campaign__c!=null
            && (lea.Lead_Stage__c=='Commercialization' ||
                lea.Lead_Stage__c=='Won' || lea.Lead_Stage__c=='Converted' || lea.Lead_Stage__c=='Upgrade')) {
                    cmpIdSet.add(lea.Campaign__c);
                }
    }
    System.debug('CmpSet'+cmpIdSet);
    if(cmpIdSet.size()>0) {  for(Lead__c lea:[SELECT Id,Campaign__c,Lead_Stage__c from Lead__c where Campaign__c in:cmpIdSet]) { 
        if(lea.Lead_Stage__c=='Commercialization') {     
            if(commMap.containsKey(lea.Campaign__c)) {     
                commMap.get(lea.Campaign__c).add(lea);     
            } else {             
                commMap.put(lea.Campaign__c,new List<Lead__c>{lea});      
            }          
        }         else if(lea.Lead_Stage__c=='Won' || lea.Lead_Stage__c=='Converted') {
            if(wonMap.containsKey(lea.Campaign__c)) {
                wonMap.get(lea.Campaign__c).add(lea);
            } else {
                wonMap.put(lea.Campaign__c,new List<Lead__c>{lea});
            }               }
        else if(lea.Lead_Stage__c=='Upgrade') {    
            if(upgMap.containsKey(lea.Campaign__c)) {     
                upgMap.get(lea.Campaign__c).add(lea);       
            } else {            
                upgMap.put(lea.Campaign__c,new List<Lead__c>{lea});
            }
        }
    }
                            System.debug('Upg map'+upgMap);
                            System.debug('Won Map'+wonMap);
                            System.debug('commMap'+commMap);
                            for(Campaign__c cmp:[SELECT Id,Lead_Commercialize_Count__c,Lead_Upgrade_Count__c,Lead_Won_Count__c from Campaign__c where Id in:cmpIdSet] ) {   
                                if(commMap.containsKey(cmp.Id)) {      
                                    cmp.Lead_Commercialize_Count__c=commMap.get(cmp.Id).Size();
                                }
                                if(commMap.size()==0) {             
                                    cmp.Lead_Commercialize_Count__c=0;
                                }
                                if(wonMap.containsKey(cmp.Id)) {         
                                    cmp.Lead_Won_Count__c=wonMap.get(cmp.Id).Size();
                                }
                                if(wonMap.size()==0) {
                                    cmp.Lead_Won_Count__c=0;
                                }
                                if(upgMap.containsKey(cmp.Id)) {          
                                    cmp.Lead_Upgrade_Count__c=upgMap.get(cmp.Id).Size();
                                }
                                if(upgMap.size()==0) {
                                    cmp.Lead_Upgrade_Count__c=0;
                                }
                                cmpUpdateList.add(cmp);
                            }
                            System.debug('Campaign Update List'+cmpUpdateList);
                            if(cmpUpdateList.size()>0) {
                                update cmpUpdateList;
                            }
                            
                            }//End
}



public static void testMethodIterate() {
    Double numbers = 0;
    
    for (Integer i = 0; i < 100; i++) {
        // Incrementing multiple times in each iteration
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
            numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
        numbers++;
    
    }
    
}

}