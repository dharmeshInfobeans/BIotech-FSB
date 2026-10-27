public class EmailAlterUtil {
    
    @future(callout=true)
    public static void processEmail(Set<Id>orderIdSet, boolean isPFI){
        if(isPFI){
        	EmailTemplate temp = [select id from emailTemplate where DeveloperName = 'PFI_Sales_Contract'];
            sendEmail(orderIdSet,temp.Id);
        }else{
            EmailTemplate temp = [select id from emailTemplate where DeveloperName ='PFI_Sales_Contract'];
            sendEmail(orderIdSet,temp.Id);
        }
    }
	
    private static void sendEmail(Set<Id>orderIdSet, string templateId){
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        OrgWideEmailAddress org = [select id, Address from OrgWideEmailAddress where Address = 'crmhelpdesk@biotechhealthcare.com' limit 1];
        for(order__c order : [select id,Account__c,Email_CRM__c,Email_RSM__c,ownerId from order__c where Id in : orderIdSet]){
            PageReference pgContract = Page.Sales_Contracts;
            pgContract.getParameters().put('Id', order.Id); 
            PageReference pgPFI = Page.Proforma_Invoice;
            pgPFI.getParameters().put('Id', order.Id); 
        	Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            Set<String> toEmailList = new Set<String>();
            if(string.isNotBlank(order.Email_CRM__c)){
                toEmailList.add(order.Email_CRM__c);
            }
            if(string.isNotBlank(order.Email_RSM__c)){
                toEmailList.add(order.Email_RSM__c);
            }
            toEmailList.addAll(system.label.PFIEMAILS.split(','));
            list<String> tempEmail = new List<string>();
            tempEmail.addAll(toEmailList);
            mail.setTargetObjectId(order.OwnerId);
            mail.setToAddresses(tempEmail);
            mail.setOrgWideEmailAddressId(org.Id);
            mail.setSaveAsActivity(false);
            mail.setTemplateId(templateId);
            mail.setWhatId(order.Id);
            if(true){
                Messaging.EmailFileAttachment efa1 = new Messaging.EmailFileAttachment();
                Messaging.EmailFileAttachment efa2 = new Messaging.EmailFileAttachment();
				efa1.setFileName('Sales_Contract.pdf');
                if(!test.isRunningTest()){
                    efa1.setBody(pgContract.getContentAsPDF());
                    efa2.setBody(pgPFI.getContentAsPDF());
                }else{
                    efa1.setBody(Blob.valueOf('Test'));
                    efa2.setBody(Blob.valueOf('Test2'));
                }
				efa2.setFileName('Proforma_Invoice.pdf');
				mail.fileattachments = (new Messaging.EmailFileAttachment[] {efa1,efa2});
			}
            mails.add(mail);    
        }
        system.debug('Mails : '+mails);
        system.debug('Mails string : '+JSON.serialize(mails));
       	Messaging.SendEmailResult[] results = messaging.sendEmail(mails, false);
        system.debug('results : '+results);
    }
}