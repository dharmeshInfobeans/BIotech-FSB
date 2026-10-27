//********************
//Name: SAPMappingTrigger
//Purpose : Handles relationship between SAP Line items and Monthly AOP
//Version : 1.0
//********************/

trigger SAPMappingTrigger on SAP_Line_Item__c (before insert,before update,after delete) 
{
    if(Trigger.isInsert){
        SAPLineHandler.MapSap(trigger.new);
        SAPLineHandler.updateActualAmtOnAOP(trigger.new);
    } 
    if(Trigger.isUpdate){
        SAPLineHandler.MapSap(trigger.new);
        SAPLineHandler.updateActualAmtOnAOP(trigger.old);
    }
    
    if(Trigger.isDelete){
        SAPLineHandler.updateActualAmtOnAOP(trigger.old);      
    }
    
}