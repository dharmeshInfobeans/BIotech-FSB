public class BatchUpsertProductsFromSAP implements Database.Batchable<ProductMaterialStockWrapper>, Database.Stateful {
    // Test class - FetchUpdatedProductsFromSAPTest
    List<String> errorMessages = new List<String>();
    
    List<ProductMaterialStockWrapper> sapRecords = new List<ProductMaterialStockWrapper>();
    private Map<String, String> plantMap = new Map<String, String>();
    private Map<String, String> productMap = new Map<String, String>();
    private Map<String, String> productModelKeyMap = new Map<String, String>();
    
    private String INTERNATIONAL_STRING = 'International';
    
    
    public BatchUpsertProductsFromSAP(String pRequestBody) {
        sapRecords = (List<ProductMaterialStockWrapper>) JSON.deserialize(pRequestBody, List<ProductMaterialStockWrapper>.class);
        //sapRecords = pWrapperList; 
        List<Plant__c> plantList = new List<Plant__c>();
        plantList = [SELECT id, Name FROM Plant__c];
        for(Plant__c plantObj : plantList) {
            plantMap.put(String.ValueOf(plantObj.Name).subString(0,4), plantObj.Id);
        }
        
        List<Product__c> productList = [SELECT id, Dummy_Product_Code__c FROM Product__c WHERE Region__c =:INTERNATIONAL_STRING And Active__c =true];
        for(Product__c productObj : productList){
            productMap.put(productObj.Dummy_Product_Code__c, productObj.id);
        }
        
        List<Product_Model__c> modelList = [SELECT id, Text_Name__c, Product__c, Product__r.Dummy_Product_Code__c FROM Product_Model__c WHERE Product__r.Region__c =:INTERNATIONAL_STRING];
        for(Product_Model__c modelObj : modelList){
            String mapKey = '';
            if(productMap.containsKey(modelObj.Product__r.Dummy_Product_Code__c)) {
                mapKey = modelObj.Text_Name__c+'-'+modelObj.Product__r.Dummy_Product_Code__c;
            }
            productModelKeyMap.put(mapKey, modelObj.id);
        }
        
        system.debug('BG >>> plantMap:'+plantMap);
    }
    
    public Iterable<ProductMaterialStockWrapper> start(Database.BatchableContext context) { 
        
        return sapRecords;
    }
    
    public void execute(Database.BatchableContext context, List<ProductMaterialStockWrapper> scope) {        
        system.debug('BG >>> plantMap : '+plantMap);
        
        // Upsert the records into Salesforce based on Material Code
        List<Product_Material_Stock__c> productsToBeUpserted = new List<Product_Material_Stock__c>();
        for (ProductMaterialStockWrapper productWrapper : scope) {
            String mapKey = productWrapper.model+'-'+productWrapper.product;
            Product_Material_Stock__c productRecord = new Product_Material_Stock__c();
            productRecord.Material_Code__c = productWrapper.materialCode;
            productRecord.Quantity__c = productWrapper.quantity;
            productRecord.Product_Models__c = productModelKeyMap.containsKey(mapKey) ? productModelKeyMap.get(mapKey) : null;
            productRecord.Product_Id__c = productMap.containsKey(productWrapper.product) ? productMap.get(productWrapper.product) : null;
            system.debug('BG >>> productWrapper.plant: '+productWrapper.plant);
            productRecord.Plant__c = plantMap.get(productWrapper.plant);
            productRecord.Stock_Id__c = productRecord.Plant__c+'-'+productRecord.Material_Code__c;
            productRecord.IsActive__c = (productWrapper.stockType != null) ? Boolean.valueOf(productWrapper.stockType) : false;
            //roductRecord.
            // more fields will be added here
            system.debug('BG >>> productRecord: '+productRecord);
            productsToBeUpserted.add(productRecord);
        }
        Database.UpsertResult[] upsertResults = Database.upsert(productsToBeUpserted, Product_Material_Stock__c.Fields.Stock_Id__c, false);
        for (Database.UpsertResult result : upsertResults) //prepare a string variable
        {
            System.debug('result'+result);
            if (!result.isSuccess()) {
                for (Database.Error error : result.getErrors()) {   
                    errorMessages.add('Error Message: ' + error.getMessage() + ' | '+result.getId()+' | Status Code: ' + error.getStatusCode());
                }  
            }
        }
    }
    public void finish(Database.BatchableContext context) 
    {
        // email body with error messages in tabular form
        String emailBody = '';
        String emailSubject = '';
        if(!errorMessages.isEmpty()){
            emailBody = 'Error Messages:<br/><br/><table border="1px solid black" border-collapse="collapse"><tr><th>Error Message</th><th>Id</th><th>Status Code</th></tr>';
            for(String errorMessage : errorMessages) {
                emailBody += '<tr><td>' + errorMessage.replace('|', '</td><td>') + '</td></tr>';
            }
            emailBody += '</table>';
            emailSubject = 'Stock update errors';
        }
        else {
            emailBody = 'All the stock records where updated success fully!';
            emailSubject = 'Stock updated';
        }
        BatchUpsertEmail__mdt mdt = BatchUpsertEmail__mdt.getInstance('StockUpdateJob');
        
        List<String> recipientEmails = New List<String>();
        if(mdt.Emails__c.contains(',')) {
            recipientEmails = mdt.Emails__c.split(',');
        }
        else {
            recipientEmails.add(mdt.Emails__c);
        }
        if(!Test.isRunningTest()){
        recipientEmails.add('dharmeshkumar.vaishnav@infobeans.com,gopal.khandelwal@parasus.com');
        }
        // Send email with error messages
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        // String[] toAddresses = new String[]{mdt.RecipientEmail__c};
        mail.setToAddresses(recipientEmails);
        mail.setSubject(emailSubject);
        mail.setHtmlBody(emailBody);
        system.debug('BG >>> mail : '+mail);
        Messaging.SendEmailResult[] mailResults = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        system.debug('BG >>>1 mail : '+mail);
        
        if(mailResults[0].success){
            system.debug ('records have been updated successfully');
        }
    }
}

// Your batch finish logic here
/* 
if (!errorMessages.isEmpty()) {
String allErrors = String.join(errorMessages, '\n');
sendEmail(allErrors);
}
}

// Method to send email
public void sendEmail(String errorContent) {
Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

String[] toAddresses = new String[]{'bhakti.choudhary@infobeans.com'}; //mention email
mail.setToAddresses(toAddresses);
mail.setSubject('Error Report from Batch Job');
mail.setPlainTextBody(errorContent);
system.debug('BG 1 >>> mail : '+mail);
// Send the email
Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
system.debug('BG >>> mail : '+mail);

}
*/


/*global BatchUpsertProductsFromSAP(List<Product_Material_Stock__c> sapRecords) {
this.sapRecords = sapRecords;
}

global Database.QueryLocator start(Database.BatchableContext context) {
return Database.getQueryLocator('SELECT Id FROM Product_Material_Stock__c LIMIT 1');
}

global void execute(Database.BatchableContext context, List<SObject> scope) {
// Upsert the records into Salesforce based on Material Code
Database.upsert(sapRecords, Product_Material_Stock__c.Fields.Material_Code__c, false);
}

global void finish(Database.BatchableContext context) {
// Your batch finish logic here
}*/