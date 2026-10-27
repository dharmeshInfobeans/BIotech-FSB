/**=====================================================================
* 
* Name: CisHeaderTrigger 
* Description: This Trugger is using to put the CE-CIS  and the Phakic rating according to the given ranges and calling the CISHeaderHealper
* Created Date: 25-08-2022-Pankaj Sen
* Created By: (Plus91labs) 
* 
* Date Modified                        Description of the update
*           
=====================================================================*/
trigger CisHeaderTrigger on CIS_Header__c (before update,before insert,after update) {
    
    if(Trigger.isbefore ) {
        if(Trigger.isUpdate) {
            CisHeaderHelper.getCeCisRating(Trigger.new,Trigger.oldMap);
            CisHeaderHelper.updateCeCisRatingAcccount(Trigger.new,Trigger.oldMap);
            
            System.debug('In update');
        }
        if(Trigger.isInsert) {
            CisHeaderHelper.updateCEcisApprovalLead(Trigger.new);
        }
        
    }
    
    if(Trigger.isAfter && Trigger.isUpdate) {
        CisHeaderHelper.updateProductCountOnCampaign(Trigger.new,trigger.oldMap);
    }
    
    
    
}