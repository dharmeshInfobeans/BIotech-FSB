trigger BDTracker on BD_Tracker__c (After Insert,After update) {
   /* 
    set<string>lstEmailSet = new set<string>();
    set<string>BDTName = new set<string>();
    Set<String>setOfRole = new Set<String>{'Biotech Vision Care Pvt. Ltd','CEO','Domestic Admin','Domestic RH','Head PMT','Manager - Clinical Affairs','Sr. Manager - Mkt',
            'Sr. Manager - PMT','ZSM','ZDM','RSM'};
    List<User>lstUser = [select id,Name,ManagerId,manager.email,manager.userrole.Name,userRole.Name from user where id =: userinfo.getUserId() ];
    EmailTemplate emailTemplate = [SELECT Id, Subject, HtmlValue, Body,Name FROM EmailTemplate WHERE Name = 'BD tracker stage']; //Email Template's ID
    EmailTemplate emailTemplateDelete = [SELECT Id, Subject, HtmlValue, Body,Name FROM EmailTemplate WHERE Name = 'BD tracker stage cancelled']; //Email Template's ID
    
    System.debug('emailTemplate'+emailTemplate);
    Map<string,String>mapOfString = new Map<String,string>();
    set<id>setOfAccountId = new Set<id>();
    if(trigger.isAfter && trigger.isInsert) {
        
        for(BD_Tracker__c objTracker : trigger.new){
            setOfAccountId.add(objTracker.Account__c);
        }
        for(Account objAccount : [select id,Name from Account where Id IN :setOfAccountId]){
            
            mapOfString.put(objAccount.id,objAccount.Name);
        }
        
        for(BD_Tracker__c objTracker : trigger.new){
          //  System.debug('==>'+trigger.oldMap.get(objTracker.id).isSubmitted__c);
            
            if(objTracker.isSubmitted__c && (!setOfRole.contains((lstUser[0].userRole.Name).split(' ')[0]))){
                System.debug('objTracker.isSubmitted__c'+objTracker.isSubmitted__c);
                String htmlBody = emailTemplate.HtmlValue;
                String plainBody = emailTemplate.Body;
                plainBody = plainBody.replace('{!BD_Tracker__c.Account__c}', mapOfString.get(objTracker.Account__c));
                
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setUseSignature(false);
                mail.setBccSender(false);
                mail.setSaveAsActivity(false);
                mail.setSubject(emailTemplate.Subject);
                mail.setHtmlBody(htmlBody);
                mail.setPlainTextBody(plainBody);
                List<String> sendTo = new List<String>();
                sendTo.add(lstUser[0].manager.email);
                mail.setToAddresses(sendTo);       
                Messaging.sendEmail(new Messaging.SingleEmailmessage[] {mail});
            }
        }
        
       
    }
    //Delete BD Tracker
    
    if(trigger.isAfter && trigger.isupdate) {
        
        for(BD_Tracker__c objTracker : trigger.new){
            setOfAccountId.add(objTracker.Account__c);
        }
        for(Account objAccount : [select id,Name from Account where Id IN :setOfAccountId]){
            
            mapOfString.put(objAccount.id,objAccount.Name);
        }
        
        
        
        for(BD_Tracker__c objTracker : trigger.new){
            
             if(objTracker.isSubmitted__c && (!setOfRole.contains((lstUser[0].userRole.Name).split(' ')[0])) && trigger.oldMap.get(objTracker.id).isSubmitted__c!= trigger.newMap.get(objTracker.id).isSubmitted__c){
                System.debug('objTracker.isSubmitted__c'+objTracker.isSubmitted__c);
                String htmlBody = emailTemplate.HtmlValue;
                String plainBody = emailTemplate.Body;
                plainBody = plainBody.replace('{!BD_Tracker__c.Account__c}', mapOfString.get(objTracker.Account__c));
                
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setUseSignature(false);
                mail.setBccSender(false);
                mail.setSaveAsActivity(false);
                mail.setSubject(emailTemplate.Subject);
                mail.setHtmlBody(htmlBody);
                mail.setPlainTextBody(plainBody);
                List<String> sendTo = new List<String>();
                sendTo.add(lstUser[0].manager.email);
                mail.setToAddresses(sendTo);       
                Messaging.sendEmail(new Messaging.SingleEmailmessage[] {mail});
            }
            
            if(objTracker.Stage__c=='Cancelled'  && (!setOfRole.contains((lstUser[0].userRole.Name).split(' ')[0]))){
                
                String htmlBody = emailTemplateDelete.HtmlValue;
                String plainBody = emailTemplateDelete.Body;
                plainBody = plainBody.replace('{!BD_Tracker__c.Name}', objTracker.name );
                plainBody = plainBody.replace('{!BD_Tracker__c.Stage__c}', objTracker.Stage__c );
                plainBody = plainBody.replace('{!BD_Tracker__c.Reason_For_Delete__c}', objTracker.Reason_For_Delete__c );
                
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setUseSignature(false);
                mail.setBccSender(false);
                mail.setSaveAsActivity(false);
                mail.setSubject(emailTemplate.Subject);
                mail.setHtmlBody(htmlBody);
                mail.setPlainTextBody(plainBody);
                List<String> sendTo = new List<String>();
                sendTo.add(lstUser[0].manager.email);
                mail.setToAddresses(sendTo);       
                Messaging.sendEmail(new Messaging.SingleEmailmessage[] {mail});
            }
        }
        
       
    }*/
}