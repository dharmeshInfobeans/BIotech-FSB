public Without Sharing class  CEUtilWS {
    public static Customer_Evaluation__c insertCERecord(Account acc, Customer_Evaluation__c custEvaluation){
                System.debug('accList[0].Approver_1__c::'+acc.Approver_1__c);
                System.debug('accList[0].Approver_2__c::'+acc.Approver_2__c);
                custEvaluation.Approver_1__c =acc.Approver_1__c;
                custEvaluation.Approver_2__c = acc.Approver_2__c;      
        upsert custEvaluation;
        return custEvaluation;
    }
}