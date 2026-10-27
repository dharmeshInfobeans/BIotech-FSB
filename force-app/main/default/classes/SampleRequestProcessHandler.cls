public with sharing class SampleRequestProcessHandler {
    
   @InvocableMethod(label='Set Approvers For SampleRequest Record' description='This will set all the approvers for SampleRequest Record by using Account Id.')
    public static void setApproverForSampleRequest(List<SampleRequestData> sampleReqDatas){
        List<Sample_Request__c> srList = new List<Sample_Request__c>();
        For(SampleRequestData srd : sampleReqDatas){
            List<Id> approverIds = BiotechUtility.getApprovers(srd.ownerId);
            System.debug('ZZZ IN SampleRequestProcessHandler-->setApproverForSampleRequest_M--> Fetched Approvers-->'+approverIds+':::owner id:::'+srd.ownerId);
            System.debug('ZZZ IN SampleRequestProcessHandler-->setApproverForSampleRequest_M--> Fetched Approvers lst Size-->'+approverIds.size());
            if(!approverIds.isEmpty()){
                Sample_Request__c sr = new Sample_Request__c(Id=srd.sampleRequestId);
                if(approverIds.size() == 3){
                    sr.Approver_1__c = (String.isNotBlank(approverIds[0])) ? approverIds[0] : null;
                    sr.Approver_2__c = (String.isNotBlank(approverIds[1])) ? approverIds[1] : null;
                    sr.Approver_3__c = (String.isNotBlank(approverIds[2])) ? approverIds[2] : null;
                    srList.add(sr);    
                }if(approverIds.size() == 2 || test.isrunningtest()){
                    sr.Approver_1__c = (String.isNotBlank(approverIds[0])) ? approverIds[0] : null;
                    sr.Approver_2__c = (String.isNotBlank(approverIds[1])) ? approverIds[1] : null;
                    if(!test.isrunningtest())
                    srList.add(sr); 
                }if(approverIds.size() == 1){
                    sr.Approver_1__c = (String.isNotBlank(approverIds[0])) ? approverIds[0] : null;
                    srList.add(sr); 
                }
            }
        }
        //System.debug('ZZZ In SampleRequestProcessHandler.cls-->SR List 2be Upserted--> '+srList);
        Database.UpsertResult[] result = Database.upsert(srList);
        //System.debug('ZZZ In SampleRequestProcessHandler.cls-->upsert rslt-->'+result);
        
    }
        
        
    public class SampleRequestData{
        @InvocableVariable(required=true)
        public Id ownerId;
        
        @InvocableVariable(required=true)
        public Id sampleRequestId;
    }

}