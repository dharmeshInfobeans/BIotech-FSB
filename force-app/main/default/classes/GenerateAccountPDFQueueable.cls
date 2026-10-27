public class GenerateAccountPDFQueueable implements Queueable,Database.AllowsCallouts {
    
    public Id recordIds;
    public GenerateAccountPDFQueueable(Id recordIds) {   this.recordIds = recordIds; }
    public void execute(QueueableContext context) {    Bio_uploadKYCDocument.sendEmailOnUpload(recordIds);   }
    
   
}