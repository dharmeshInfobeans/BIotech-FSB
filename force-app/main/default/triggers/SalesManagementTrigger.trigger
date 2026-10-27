/********************
Name: SalesManagementTrigger
Created by : Nikhil Tripathi
Purpose : Handles relationship between monthly targets and plans
Version : 1.0
********************/

trigger SalesManagementTrigger on Monthly_Product_Plan__c (before insert, before update,after insert, after update,before delete,after delete) {
 MonthlyProductPlanTriggerHandler.updateMonthlyAOPWhenMppIsDeleted(Trigger.new,Trigger.old, Trigger.operationType);
    
  }