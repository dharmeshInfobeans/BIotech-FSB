/**=====================================================================
* 
* Name: SumbitCeCisController 
* Description: This Controller is using to get the CIS configuration data and show on Lead and Account on New CE-CIS button.
* Created Date: 28-08-2022
* Created By: (Plus91labs)-Pankaj Sen
* 
* Date Modified     11/07/2024 By Gyadeen Ahirwar                   Description of the update
*           
=====================================================================*/
public class SumbitCeCisController {
    
    /****This method is using to get the Product data according to differnet recordId of lead and Account****/
    @AuraEnabled(cacheable=true)
    public static Map<String,List<String>> getCisHeader(String recordId) {
        Id objectId=(Id)recordId;
        string country='';
        
        if(Schema.Account.SObjectType==objectId.getSobjectType()) {
            country=[SELECT Id,BillingCountry from Account where id=:recordId limit 1].BillingCountry;
        } else if(Schema.Lead__c.SObjectType==objectId.getSobjectType()) {
            country=[SELECT Id,Country__c from Lead__c where id=:recordId limit 1].Country__c;
        } else if(Schema.Contact.SObjectType==objectId.getSobjectType()) {
            country =[SELECT Id,mailingcountry from Contact where id=:recordId limit 1].mailingcountry;
        }
        
        System.debug('Country'+country);
        //   System.debug('Account Billing country'+acc.BillingCountry);
        Map<String,List<String>> cisConfMap=new Map<String,List<String>>();  
        List<Map<String,String>> companyListMap=new List<Map<String,String>>();
        List<Map<String,String>> categoryListMap=new List<Map<String,String>>();
        for(CIS_Configuration__c cisConf:[SELECT Id,Company__c,Categories__c,Record_Type__c from CIS_Configuration__c where Record_Type__c=:country]) {
            
            if(cisConfMap.containsKey('Company')) {
                cisConfMap.get('Company').add(cisConf.Categories__c);
                
            } else {
                cisConfMap.put('Company',new List<String>{cisConf.Categories__c});
            }
        }
        
        
        return cisConfMap;
        
    }
    /*****This Method is using to get the company Name data according to the Product Name and record id of Lead and Account****/
    @AuraEnabled
    public static Map<String,Object> getCisConfigData(string recordId,string poductName) {
        
        Map<String,Object> cisConfMap=new Map<String,Object>(); 
        try{
            Id objectId=(Id)recordId;
            string country='';
            
            if(Schema.Account.SObjectType==objectId.getSobjectType()) {
                country=[SELECT Id,BillingCountry from Account where id=:recordId].BillingCountry;
            } else if(Schema.Lead__c.SObjectType==objectId.getSobjectType()) {
                country=[SELECT Id,Country__c from Lead__c where id=:recordId].Country__c;
            } else if(Schema.Contact.SObjectType==objectId.getSobjectType()) {
                country=[SELECT Id,mailingcountry from Contact where id=:recordId].MailingCountry;
            }
            
            System.debug('Country'+country);
            CIS_Configuration__c cisConfList=[SELECT Id,Company__c,Categories__c,Record_Type__c 
                                              from CIS_Configuration__c where Record_Type__c=:country 
                                              AND Categories__c=:poductName limit 1];
            List<Map<String,String>> companyListMap=new List<Map<String,String>>();
            
            if(cisConfList.Company__c.contains(';')) {
                List<String> companyList=cisConfList.Company__c.split(';');
                
                for(String str:companyList) {
                    Map<String,String> labelDataMap=new Map<String,String>();
                    labelDataMap.put('label',str);
                    labelDataMap.put('value',str);
                    companyListMap.add(labelDataMap);
                }
                cisConfMap.put('Company',companyListMap);
            } else {
                cisConfMap.put('Company',cisConfList.Company__c); 
            }
        }catch(Exception e) {
            System.debug(Logginglevel.ERROR, e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
        return cisConfMap;
        
        
    }
    /***This method is using to insert CIS header data according to the different conditions****/
    @AuraEnabled
    public static string saveData(List<Map<String,Object>> CeCisDataList,string recordId,Integer lvcData,string submitData,string premium,string regular,String selectedCurrency) {
        string message='';
        try{
            Id objectId=(Id)recordId;
            string country='';
            List<CIS_Line__c> cisLineItemList=new List<CIS_Line__c>();
            System.debug('Ce cis Data'+CeCisDataList);
            System.debug('LVC '+lvcData);
            CIS_Header__c cis=new CIS_Header__c();
            if(Schema.Account.SObjectType==objectId.getSobjectType()){
                Account acc=[SELECT id,Approver_1__c,Approver_2__c,BillingCountry from Account where Id=:recordId limit 1];
                if(acc.Approver_1__c!=null) {
                    cis.User__c=acc.Approver_1__c;
                    
                }else {
                    cis.User__c=acc.Approver_2__c;
                }
                cis.RecordTypeId=Schema.SObjectType.CIS_Header__c.getRecordTypeInfosByName().get(acc.BillingCountry.toUpperCase()). getRecordTypeId();
                cis.Account__c=recordId;
            } else if(Schema.Lead__c.SObjectType==objectId.getSobjectType()) {
                Lead__c lea=[SELECT id,ManagerId__c,Country__c	from Lead__c where Id=:recordId limit 1];
                cis.User__c=lea.ManagerId__c;
                cis.Leads__c=recordId;
                cis.RecordTypeId=Schema.SObjectType.CIS_Header__c.getRecordTypeInfosByName().get(lea.Country__c.toUpperCase()). getRecordTypeId();
            }else if(Schema.contact.SObjectType==objectId.getSobjectType()) {
                contact con =[SELECT id,MailingCountry,OwnerId from contact where Id=:recordId limit 1];
                User u = [  SELECT Id, Name, L1_manager__c FROM User WHERE Id = :con.OwnerId LIMIT 1 ];
                cis.User__c=u.L1_manager__c;
                cis.contact__c = recordId;
                cis.RecordTypeId=Schema.SObjectType.CIS_Header__c.getRecordTypeInfosByName().get(con.MailingCountry.toUpperCase()). getRecordTypeId();
            }
            
            cis.No_of_LVC_Procedures__c=lvcData;
            cis.Year__c=String.valueOf(system.today().Year());
            cis.CurrencyIsoCode = 'USD';
            cis.Regular_Percentage__c=regular!=null ? decimal.valueOf(regular) : 0;
            cis.Premium_Percentage__c=premium!=null ? decimal.valueOf(premium) : 0;
            if(submitData=='submit' && submitData!='') {
                cis.Status__c='Submit for Approval';    
            }else {
                cis.Status__c='Draft';   
            }
            
            insert cis;
            for(Map<String,Object> cisLine:CeCisDataList) {
                if(string.isNotBlank(string.valueOf(cisLine.get('Company'))) || string.isNotBlank(string.valueOf(cisLine.get('Product'))) 
                   || string.isNotBlank(string.valueOf(cisLine.get('Value'))) || String.isNotBlank(String.valueOf(cisLine.get('Price')))) {
                       CIS_Line__c cisLineItems=new CIS_Line__c();
                       cisLineItems.CIS_Header__c=cis.Id;
                       cisLineItems.Company__c=string.valueOf(cisLine.get('Company'));
                       cisLineItems.Product__c=string.valueOf(cisLine.get('Product'));
                     //  cisLineItems.No_of_Surguries__c=double.valueOf(cisLine.get('Value'));
                        Object valueObj = cisLine.get('Value');
                       
                       if (valueObj instanceof Decimal) {
                           cisLineItems.No_of_Surguries__c = ((Decimal) valueObj).doubleValue();
                       } else if (valueObj != null && valueObj != '') {
                           cisLineItems.No_of_Surguries__c = Double.valueOf(String.valueOf(valueObj));
                       } else {
                           cisLineItems.No_of_Surguries__c = 0;
                       }
                       cisLineItems.Avg_Purchase_Price__c=double.valueOf(cisLine.get('Price'));
                       //cisLineItems.Local_Avg_Purchase_Price__c=double.valueOf(cisLine.get('AveragePrice'));
                        Object avgPriceObj = cisLine.get('AveragePrice');
                       
                       if (avgPriceObj instanceof Decimal) {
                           cisLineItems.Local_Avg_Purchase_Price__c = ((Decimal) avgPriceObj).doubleValue();
                       } else if (avgPriceObj != null && String.valueOf(avgPriceObj) != '') {
                           cisLineItems.Local_Avg_Purchase_Price__c = Double.valueOf(String.valueOf(avgPriceObj));
                       } else {
                           cisLineItems.Local_Avg_Purchase_Price__c = 0;
                       }
                       cisLineItems.Local_Value__c=double.valueOf(cisLine.get('PriceValue'));
                       cisLineItems.USD_Value__c=double.valueOf(cisLine.get('UsdPriceTotal'));
                       cisLineItems.local_type__c=String.valueOf(cisLine.get('Type'));
                       cisLineItems.Currency__c=String.valueOf(selectedCurrency);
                       
                       cisLineItems.CurrencyIsoCode = 'USD';
                       cisLineItemList.add(cisLineItems); 
                   }
                
            }
            System.debug('Before'+cisLineItemList);
            insert cisLineItemList;
            System.debug('After'+cisLineItemList);
            if(submitData=='submit' && submitData!='') {
                cis.Stop_Approval__c=true; 
                update cis;
            }
            
            
            if(submitData=='submit') {
                message='success';
                
            }else {
                message=[SELECT Id from CIS_Header__c where Id=:cis.Id].Id;
            }
            
            
        }catch(Exception e) {
            message='error' + '-'+e.getMessage();
            System.debug(Logginglevel.ERROR, e.getMessage() +'at line no'+e.getLineNumber());
            throw new AuraHandledException(e.getMessage());
            
        }
        
        return message; 
        
    }
    /***This method is using to show the error on New CE Cis screen if there is already a CIS header record related to the Account and the Leadd****/
    @AuraEnabled(cacheable=true)
    public static string getCisError(String recordId) {
        Id objectId=(Id)recordId;
        string message='';
        List<sObject> ceLatestRecords;
        List<CIS_Header__c> ceLatestRecordsSubmitCeCis=new List<CIS_Header__c>();
        Boolean leadConverted=false;
        
        if(Schema.Account.SObjectType==objectId.getSobjectType()) {
            ceLatestRecords=[SELECT Id,Account__c,Status__c from CIS_Header__c where Status__c!='Approved' AND Status__c!='Rejected' AND Account__c =:recordId limit 2];   
        } else if(Schema.Lead__c.SObjectType==objectId.getSobjectType()) {
            ceLatestRecords=[SELECT Id,Account__c,Status__c from CIS_Header__c where Status__c!='Approved' AND Status__c!='Rejected' AND Leads__c =:recordId limit 2];   
            Lead__c lea=[SELECT Id,Name,Lead_Stage__c from Lead__c where Id=:recordId limit 1];
            if(lea.Lead_Stage__c=='Converted') {
                leadConverted=true;
            }
            
        }
        if(leadConverted) {
            message='leadConvertedError';
        }
        if(ceLatestRecords.size()>0) {
            message='error';
        } 
        else {
            message='success';
        }
        
        return message;
    }
    
    
    /**For Dermal and Orhto**/
    
    @AuraEnabled(cacheable=true)
    public static Map<String,object> getAccountData(String recordId) {
        Map<String,object> accMap=new Map<String,object>();
        Map<String,List<String>> cisConfMap=new Map<String,List<String>>();
        List<Map<String,String>> ceCisList=new List<Map<String,String>>();
        string recordType='';
        string country='';
        Account acc=[SELECT id,RecordType.Name,BillingCountry,Approver_1__c,Approver_2__c,(SELECT id,Status__c from CIS_Headers__r  where Status__c!='Approved') from Account where Id=:recordId];
        if(acc.RecordType.Name=='International -Dermal') {
            recordType='Dermal';
        }else if(acc.RecordType.Name=='International - Ortho'){
            recordType='Ortho';
        }else  if(acc.RecordType.Name=='Domestic - Ortho') {
            recordType='Ortho';
        }
        // recordType=acc.RecordType.Name;
        country=acc.BillingCountry;
        if(recordType!='' && country!='') {
            for(CIS_Configuration__c cisConf:[SELECT Id,Company__c,Categories__c,Record_Type__c from CIS_Configuration__c where (Record_Type__c=:recordType AND Country__c=:Country) ]) {
                if(cisConfMap.containsKey('Company')) {
                    cisConfMap.get('Company').add(cisConf.Company__c);
                } else {
                    cisConfMap.put('Company',new List<String>{cisConf.Company__c});
                }
            } 
            
            
            for(CE_CIS_Configuration__c ce:[SELECT Id,Package_Of_1Ml_Injections__c,Rating__c from CE_CIS_Configuration__c where (Record_Type__c=:recordType AND Country__c=:Country AND Package_Of_1Ml_Injections__c!=null)]) {
                ceCisList.add(new Map<String,String>{'label'=>ce.Package_Of_1Ml_Injections__c,'value'=>ce.Rating__c});
            }
        }
        accMap.put('RecordType',recordType);
        accMap.put('CisHeader',''); 
        accMap.put('Country',acc.BillingCountry); 
        accMap.put('Company',cisConfMap);
        accMap.put('Package',ceCisList);
        if(acc.Approver_1__c!=null) {
            accMap.put('User',acc.Approver_1__c); 
        }else {
            accMap.put('User',acc.Approver_2__c); 
            
        }
        if(acc.CIS_Headers__r.size()>0) {
            accMap.put('CisHeader','ShowError');  
        }
        return accMap;
    }
    
    @AuraEnabled
    public static Map<String,Object> getProductData(string recordType,String country,String company) {
        Map<String,Object> cisConfMap=new Map<String,Object>(); 
        try{
            CIS_Configuration__c cisConfList=[SELECT Id,Company__c,Categories__c,Record_Type__c 
                                              from CIS_Configuration__c where (Country__c=:country 
                                                                               AND Record_Type__c=:recordType AND Company__c=:company) limit 1];
            List<Map<String,String>> companyListMap=new List<Map<String,String>>();
            if(cisConfList.Categories__c.contains(';')) {
                List<String> companyList=cisConfList.Categories__c.split(';');
                
                for(String str:companyList) {
                    Map<String,String> labelDataMap=new Map<String,String>();
                    labelDataMap.put('label',str);
                    labelDataMap.put('value',str);
                    companyListMap.add(labelDataMap);
                }
                cisConfMap.put('Product',companyListMap);
            } else {
                Map<String,String> labelDataMap=new Map<String,String>();
                labelDataMap.put('label',cisConfList.Categories__c);
                labelDataMap.put('value',cisConfList.Categories__c);
                companyListMap.add(labelDataMap);
                cisConfMap.put('Product',companyListMap); 
            }
        }catch(Exception e) {
            System.debug(Logginglevel.ERROR, e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
        return cisConfMap;
    }
    
    
    @AuraEnabled
    public static string saveDermalData(List<Map<String,Object>> cisDataList,string country,string userId,string recordId,string submitData,string currentRating,String totalValue,Boolean dermal,string recordType) {
        List<CIS_Line__c> cisLineItemList=new List<CIS_Line__c>();
        double totalData=double.valueOf(totalValue);
        string rating='';
        for(CE_CIS_Configuration__c ce:[SELECT Id,Package_Of_1Ml_Injections__c,Rating__c from CE_CIS_Configuration__c where (Record_Type__c=:recordType AND Country__c=:Country
                                                                                                                             AND (From_Range__c<=:totalData AND To_Range__c>=:totalData))]) {
                                                                                                                                 rating=ce.Rating__c;
                                                                                                                             }
        CIS_Header__c cis=new CIS_Header__c();
        cis.RecordTypeId=Schema.SObjectType.CIS_Header__c.getRecordTypeInfosByName().get(recordType). getRecordTypeId();
        cis.Account__c=recordId;
        cis.Year__c=String.valueOf(system.today().Year());
        cis.User__c=userId;
        cis.Ce_Cis_Rating__c=rating+''+currentRating;
        if(submitData=='submit' && submitData!='') {
            cis.Status__c='Submit for Approval';    
        }else {
            cis.Status__c='Draft';   
        }
        
        insert cis;
        
        for(Map<String,Object> cisLine:cisDataList) {
            system.debug('cisLine-->'+Json.serialize(cisLine));
            if(string.isNotBlank(string.valueOf(cisLine.get('Company'))) || string.isNotBlank(string.valueOf(cisLine.get('Product'))) 
               || string.isNotBlank(string.valueOf(cisLine.get('Value')))) {
                   CIS_Line__c cisLineItems=new CIS_Line__c();
                   cisLineItems.CIS_Header__c=cis.Id;
                   cisLineItems.Company__c=string.valueOf(cisLine.get('Company'));
                   cisLineItems.Product__c=string.valueOf(cisLine.get('Product'));
                   system.debug('double-->'+ CisLine.get('Value'));
                   cisLineItems.No_of_Surguries__c=double.valueOf(cisLine.get('Value'));
                   cisLineItemList.add(cisLineItems); 
               }
            
        }
        insert cisLineItemList;
        if(submitData=='submit' && submitData!='') {
            cis.Stop_Approval__c=true; 
            update cis;
        }
        Account acc=new Account();
        acc.Id=recordId;
        acc.CE_CIS_Rating__c=rating+''+currentRating;
        update acc;
        
        return 'success';
    }
    @AuraEnabled(cacheable=true)
    public static Object  returnCisHeaderAndLineItem(String recordId){
        Id objectId=(Id)recordId;
        System.debug('inside'+recordId);
        if(Schema.Account.SObjectType==objectId.getSobjectType()){
            System.debug('inside 330');
            
            return [
                SELECT Id, Total__c, Name,Phakic_Rating__c ,Ce_Cis_Rating__c,LastModifiedDate,Status__c,No_of_LVC_Procedures__c,Regular_Percentage__c,Premium_Percentage__c,
                (SELECT Id, Name, Product__c, Company__c, No_of_Surguries__c,CIS_Type__c,Avg_Purchase_Price__c,Value__c,Local_Avg_Purchase_Price__c,local_type__c,Local_Value__c
                 FROM CIS_Lines__r)
                FROM CIS_Header__c WHERE Account__c=:recordId ORDER BY CreatedDate DESC
            ];
        }else if(Schema.Lead__c.SObjectType==objectId.getSobjectType()){
            System.debug('inside 339');
            return [ SELECT Id, Total__c, Name, Phakic_Rating__c , Ce_Cis_Rating__c,LastModifiedDate,Status__c,No_of_LVC_Procedures__c,Regular_Percentage__c,Premium_Percentage__c,
                    (SELECT Id, Name, Product__c, Company__c, No_of_Surguries__c,CIS_Type__c,Avg_Purchase_Price__c,Value__c,Local_Avg_Purchase_Price__c,local_type__c,Local_Value__c
                     FROM CIS_Lines__r)
                    FROM CIS_Header__c WHERE Leads__c=:recordId ORDER BY CreatedDate DESC];
            
        }else if(Schema.contact.SObjectType==objectId.getSobjectType()){
             return [ SELECT Id, Total__c, Name, Phakic_Rating__c , Ce_Cis_Rating__c,LastModifiedDate,Status__c,No_of_LVC_Procedures__c,Regular_Percentage__c,Premium_Percentage__c,
                    (SELECT Id, Name, Product__c, Company__c, No_of_Surguries__c,CIS_Type__c,Avg_Purchase_Price__c,Value__c,Local_Avg_Purchase_Price__c,local_type__c,Local_Value__c
                     FROM CIS_Lines__r)
                    FROM CIS_Header__c WHERE contact__c=:recordId ORDER BY CreatedDate DESC];
        }
        else{
            return null;
        }
    }
    @AuraEnabled(cacheable=true)
    public static List<CurrencyType> getActiveCurrencies() {
        
        return [
            SELECT Id, IsoCode, ConversionRate, DecimalPlaces, IsActive, IsCorporate
            FROM CurrencyType
            WHERE IsActive = true
        ];
        
    }
    @AuraEnabled(cacheable=true)
    public static String getAccountSelectedCurrency(String recordId){
        
        
        if(String.isBlank(recordId)) return null;
        Id objectId=(Id)recordId;
        List<Lead__c> leadList= new List<Lead__c>();
        List<Account> accList= new List<Account>();
        List<Contact> conList = new List<Contact>();
        if(Schema.Account.SObjectType==objectId.getSobjectType()) {
            accList=[SELECT Id,CurrencyIsoCode FROM Account WHERE Id = :recordId LIMIT 1];
            System.debug('accList'+accList);
        } else if(Schema.Lead__c.SObjectType==objectId.getSobjectType()) {
            leadList= [SELECT Id, Account__r.CurrencyIsoCode FROM Lead__c WHERE Id = :recordId LIMIT 1];
            System.debug('leadList'+leadList);
        }else if(Schema.contact.SObjectType==objectId.getSobjectType()){
            conList=[SELECT Id,Account.CurrencyIsoCode FROM Contact WHERE Id=:recordId LIMIT 1];
        }
        
        
        
        if(!conList.isEmpty() && conList[0].Account != Null){
            return conList[0].Account.CurrencyIsoCode;
        }
        if(!leadList.isEmpty() && leadList[0].Account__r != null){
            return leadList[0].Account__r.CurrencyIsoCode;
        }
        if(!accList.isEmpty()){
            System.debug('Inside accountList');
            return accList[0].CurrencyIsoCode;
        }
        
        return null;
    }
    @AuraEnabled
    public static void updateCisHeaderAndLineItem(List<Map<String,Object>> CeCisDataList,Integer lvcData,String selectedCurrency,String headerId){
        List<sObject> updateCisHeaderAndLineItem= new List<sObject>();
        System.debug('CeCisDataList'+CeCisDataList);
        updateCisHeaderAndLineItem.add(new CIS_Header__c(Id=headerId,No_of_LVC_Procedures__c=lvcData));
        for(Map<String,Object> cisLine:CeCisDataList) {
            if(string.isNotBlank(string.valueOf(cisLine.get('Company'))) || string.isNotBlank(string.valueOf(cisLine.get('Product'))) 
               || string.isNotBlank(string.valueOf(cisLine.get('Value'))) || String.isNotBlank(String.valueOf(cisLine.get('Price')))) {
                   if(String.isNotBlank(String.valueOf(cisLine.get('Id')))){
                       CIS_Line__c cisLineItems=new CIS_Line__c();
                       cisLineItems.Id=String.valueOf(cisLine.get('Id'));
                       cisLineItems.Company__c=string.valueOf(cisLine.get('Company'));
                       cisLineItems.Product__c=string.valueOf(cisLine.get('Product'));
                       Object valueObj = cisLine.get('Value');
                       
                       if (valueObj instanceof Decimal) {
                           cisLineItems.No_of_Surguries__c = ((Decimal) valueObj).doubleValue();
                       } else if (valueObj != null && valueObj != '') {
                           cisLineItems.No_of_Surguries__c = Double.valueOf(String.valueOf(valueObj));
                       } else {
                           cisLineItems.No_of_Surguries__c = 0;
                       }
                       
                       // cisLineItems.No_of_Surguries__c=double.valueOf(cisLine.get('Value')) != null?ouble.valueOf(cisLine.get('Value')):0;
                       cisLineItems.Avg_Purchase_Price__c =double.valueOf(cisLine.get('Price'));
                       cisLineItems.Local_Selected_Value__c=selectedCurrency;
                       // cisLineItems.Local_Value__c=double.valueOf(cisLine.get('PriceValue'));
                       String priceValueStr = (String) cisLine.get('PriceValue');
                       cisLineItems.Local_Value__c= String.isBlank(priceValueStr) ? 0 : Double.valueOf(priceValueStr);
                       //cisLineItems.USD_Value__c=double.valueOf(cisLine.get('UsdPriceTotal'));
                       String usdValueStr = (String) cisLine.get('UsdPriceTotal');
                       cisLineItems.USD_Value__c   = String.isBlank(usdValueStr)   ? 0 : Double.valueOf(usdValueStr);
                       cisLineItems.local_type__c=String.valueOf(cisLine.get('Type'));
                       cisLineItems.Currency__c=String.valueOf(selectedCurrency);
                       System.debug('usd'+double.valueOf(cisLine.get('UsdPriceTotal')));
                       
                       
                       
                       
                       // System.debug('gytfduyd'+cisLine.get('AveragePrice'));
                       //String AveragePriceStr = (String) cisLine.get('AveragePrice');
                       //cisLineItems.Local_Avg_Purchase_Price__c   = String.isBlank(AveragePriceStr)   ? 0 : Double.valueOf(AveragePriceStr);
                       Object avgPriceObj = cisLine.get('AveragePrice');
                       
                       if (avgPriceObj instanceof Decimal) {
                           cisLineItems.Local_Avg_Purchase_Price__c = ((Decimal) avgPriceObj).doubleValue();
                       } else if (avgPriceObj != null && String.valueOf(avgPriceObj) != '') {
                           cisLineItems.Local_Avg_Purchase_Price__c = Double.valueOf(String.valueOf(avgPriceObj));
                       } else {
                           cisLineItems.Local_Avg_Purchase_Price__c = 0;
                       }
                       
                       //cisLineItems.Local_Avg_Purchase_Price__c=double.valueOf(cisLine.get('AveragePrice'));
                       cisLineItems.CurrencyIsoCode = 'USD';
                       updateCisHeaderAndLineItem.add(cisLineItems); 
                   }
                   
               }
            
        }
        
        
        System.debug('updateCisHeaderAndLineItem'+JSON.serialize(updateCisHeaderAndLineItem));
        if(!updateCisHeaderAndLineItem.isEmpty()){
            update updateCisHeaderAndLineItem;
        }
        System.debug('CeCisDataList'+CeCisDataList);
        System.debug('lvcData'+lvcData);
        System.debug('selectedCurrency'+selectedCurrency);
        System.debug('headerId'+headerId);
    }
    
    
}