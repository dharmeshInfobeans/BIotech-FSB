/**=====================================================================
* 
* Name: AdressTriggerHelper 
* Description: This Helper is using the update the  addresses on lead(when it will insert or delete in the system)
* Created Date: 28-09-2022
* Created By: (Plus91labs)-Pankaj Sen
* 
* Date Modified                        Description of the update
*           
=====================================================================*/


public class AdressTriggerHelper {
    public static void updateAdressOnLead(List<Address__c> newList) {
        Set<String> leadIdSet=new Set<String>();
        Map<String,List<Address__c>> adressDataMap=new Map<String,List<Address__c>>();
        for(Address__c adr:newList) {
            if(adr.Lead__c!=null) {
                leadIdSet.add(adr.Lead__c);
                
            }
        }
        if(leadIdSet.size()>0) {
            for(Address__c adrsData:[SELECT Id,Billing_City__c,Billing_code__c,Billing_country__c,Billing_state__c,Billing_Street__c,Lead__c from Address__c where Lead__c in:leadIdSet ORDER By createdDate desc]) {
                if(adressDataMap.containsKey(adrsData.Lead__c)) {
                    adressDataMap.get(adrsData.Lead__c).add(adrsData);
                } else {
                    adressDataMap.put(adrsData.Lead__c,new List<Address__c>{adrsData});
                }
            }
        }
        
        if(adressDataMap.size()>0) {
            List<Lead__c> leadUpdateList=new List<Lead__c>();
            for(Lead__c lea:[SELECT Id,Billing_City__c,Billing_code__c,Country__c,Billing_state__c,Billing_Street__c,Account__c from Lead__c where id in:adressDataMap.keySet()]) {
                if(adressDataMap.containskey(lea.Id)) {
                    lea.Billing_City__c=adressDataMap.get(lea.Id)[0].Billing_City__c!=null ? adressDataMap.get(lea.Id)[0].Billing_City__c.toUpperCase() : adressDataMap.get(lea.Id)[0].Billing_City__c;
                    lea.Billing_code__c=adressDataMap.get(lea.Id)[0].Billing_code__c;
                    lea.Country__c=adressDataMap.get(lea.Id)[0].Billing_country__c.toUpperCase()!=null ? adressDataMap.get(lea.Id)[0].Billing_country__c.toUpperCase() : adressDataMap.get(lea.Id)[0].Billing_country__c.toUpperCase();
                    lea.Billing_state__c=adressDataMap.get(lea.Id)[0].Billing_state__c!=null ? adressDataMap.get(lea.Id)[0].Billing_state__c.toUpperCase() : adressDataMap.get(lea.Id)[0].Billing_state__c;
                    lea.Billing_Street__c=adressDataMap.get(lea.Id)[0].Billing_Street__c!=null ? adressDataMap.get(lea.Id)[0].Billing_Street__c.toUpperCase() : adressDataMap.get(lea.Id)[0].Billing_Street__c;
                   
                    
                    leadUpdateList.add(lea);
                    
                }
            }
            if(leadUpdateList.size()>0) {
                update leadUpdateList; 
            }
            
        }
        
        
    }
    
    public static void deleteAddresse(List<Address__c> oldList) {
        Set<String> leadIdSet=new Set<String>();
        Map<String,List<Address__c>> adressDataMap=new Map<String,List<Address__c>>();
        for(Address__c adr:oldList) {
            if(adr.Lead__c!=null) {
                leadIdSet.add(adr.Lead__c);
                
            }
        }
        if(leadIdSet.size()>0) {
            for(Address__c adrsData:[SELECT Id,Billing_City__c,Billing_code__c,Billing_country__c,Billing_state__c,Billing_Street__c,Lead__c from Address__c where Lead__c in:leadIdSet ORDER By createdDate desc]) {
                if(adressDataMap.containsKey(adrsData.Lead__c)) {
                    adressDataMap.get(adrsData.Lead__c).add(adrsData);
                } else {
                    adressDataMap.put(adrsData.Lead__c,new List<Address__c>{adrsData});
                }
            }
        }
        
        if(adressDataMap.size()>0) {
            List<Lead__c> leadUpdateList=new List<Lead__c>();
            for(Lead__c lea:[SELECT Id,Billing_City__c,Billing_code__c,Country__c,Billing_state__c,Billing_Street__c from Lead__c where id in:adressDataMap.keySet()]) {
                if(adressDataMap.containskey(lea.Id)) {
                    lea.Billing_City__c=adressDataMap.get(lea.Id)[0].Billing_City__c!=null ? adressDataMap.get(lea.Id)[0].Billing_City__c.toUpperCase() : adressDataMap.get(lea.Id)[0].Billing_City__c;
                    lea.Billing_code__c=adressDataMap.get(lea.Id)[0].Billing_code__c;
                    lea.Country__c=adressDataMap.get(lea.Id)[0].Billing_country__c.toUpperCase()!=null ? adressDataMap.get(lea.Id)[0].Billing_country__c.toUpperCase() : adressDataMap.get(lea.Id)[0].Billing_country__c.toUpperCase();
                    lea.Billing_state__c=adressDataMap.get(lea.Id)[0].Billing_state__c!=null ? adressDataMap.get(lea.Id)[0].Billing_state__c.toUpperCase() : adressDataMap.get(lea.Id)[0].Billing_state__c;
                    lea.Billing_Street__c=adressDataMap.get(lea.Id)[0].Billing_Street__c!=null ? adressDataMap.get(lea.Id)[0].Billing_Street__c.toUpperCase() : adressDataMap.get(lea.Id)[0].Billing_Street__c;
                    //  lea.Status__c=false;
                    leadUpdateList.add(lea);
                    
                }
            }
            if(leadUpdateList.size()>0) {
                update leadUpdateList; 
            }
            
        }
    }
}