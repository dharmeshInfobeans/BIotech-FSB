public class CreateHolidayShareRecords implements Database.Batchable<SObject>,Database.Stateful {
    
    
    public Map<String , String> mapOfError = new Map<String , String>();
    public Map<String , Integer> numberOfError = new Map<String , Integer>();
    
    
    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator('Select id,state__c,OwnerId,Country__c from Holiday__c where Country__c !=null' );
    }
    
    public void execute(Database.BatchableContext bc, List<Holiday__c> listOfHoliday){
        List<Holiday__Share> listOfHolidayShare=new List<Holiday__Share>();
        List<User> listOFUser=[Select id,name,Country,Country__c,State__c,IsPartner,Profile.Name, Profile.UserType from user where Country__c !=null AND IsActive =true AND Profile.UserType='Standard'  ];
        System.debug('In Execute');
        for(user us:listOFUser){  
            for(Holiday__c holiday: listOfHoliday){
                if( holiday.OwnerId!=us.Id && us.Country__c==holiday.Country__c && ( us.Country__c!='INDIA' || ( holiday.State__c!=Null && us.State__c==holiday.State__c   ))   ){
                    System.debug('Match : ' +  us.Country__c + ' : ' + holiday.State__c);
                    listOfHolidayShare.add(new Holiday__Share(AccessLevel = 'Read', RowCause =Schema.Holiday__Share.RowCause.Manual, ParentId=holiday.Id,UserOrGroupId=us.id) ); 
                }
            } 
        }
        System.debug('listOfHolidayShare: '+listOfHolidayShare.size());
            List<Database.SaveResult> results = Database.insert(listOfHolidayShare,false);
            
            for (Integer i = 0; i < results.size(); i++) {
                Database.SaveResult sr = results[i];
                
                if (!sr.isSuccess()) {
                    Holiday__Share failedShare = listOfHolidayShare[i];
                    
                    for (Database.Error err : sr.getErrors()) {
                        
                        String errMsg = 'Status Code: ' + err.getStatusCode() +
                            ', Message: ' + err.getMessage();
                           
                        String errorRecordId = failedShare.ParentId + ' - ' + failedShare.UserOrGroupId;
                        mapOfError.put(errMsg, errorRecordId);
                        if(!numberOfError.containsKey(errMsg)) numberOfError.put(errMsg , 1);
                        else numberOfError.put(errMsg , numberOfError.get(errMsg)+1);
                        System.debug(errMsg + ' : ' + errorRecordId);
                    }
                }
            }
        
    }
    public void finish(Database.BatchableContext bc){
        System.debug('Inside Finished');
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setToAddresses(new String[] { 'ahsan@creatiquetech.com' });
        message.setSubject('Holiday Share Batch Errors');
        message.setPlainTextBody(
            'Total Errors: \n' +  JSON.serializePretty(numberOfError) + '\n\n' +
            'Error Details:\n' +
            JSON.serializePretty(mapOfError)
        );
        
        Messaging.SendEmailResult[] results =
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { message });
        
        if (results[0].success) {
            System.debug('The email was sent successfully.');
        } else {
            System.debug('The email failed to send: '
                         + results[0].errors[0].message);
        }
    }
}