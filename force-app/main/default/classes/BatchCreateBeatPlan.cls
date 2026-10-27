global class BatchCreateBeatPlan implements Database.Batchable <SObject> {
    global database.QueryLocator start(Database.BatchableContext bx){
        date todaydate = date.today();
        string recordtype  = 'Ophthalmic & Vision';
        string recordtype2 = 'Ortho-Dermal';
        string query = 'select subject,ownerId, StartDateTime, Beat_Plan__c from event where visit_Date__c = : todaydate AND Account__r.RecordType.Name !=:recordType AND Account__r.RecordType.Name !=:recordType2  ';
        return database.getQueryLocator(query);
    }
    global void execute(Database.BatchableContext bx, list<event> scope){
        System.debug('In Execute method : '+scope);
        try {
            map<String,list<event>> ownerEventMap = new map<String,list<event>>();
            map<string,string> beatmap = new map<String,String>();
            list<beat_Plan__c> beatList = new List<beat_Plan__c>();
            for(event obj : scope){
                if(ownerEventMap.containsKey(obj.ownerId)){
                    ownerEventMap.get(obj.ownerId).add(obj);
                }else{
                    ownerEventMap.put(obj.ownerId,new list<event>{obj});
                }
            }
            for(string obj : ownerEventMap.keySet()){
                beat_Plan__c bobj = new beat_Plan__c();
                bobj.Assigned_To__c = obj;
                bobj.BUI__c = obj+'-'+date.today().format();
                bobj.Beat_Date__c = date.today();
                beatList.add(bobj);
            }
            insert beatList;
            for(beat_Plan__c bobj : beatList){
                beatmap.put(bobj.Assigned_To__c, bobj.id);
            }
            System.debug('beat map in batch : '+beatmap);
            for (event eobj : scope) {
                eobj.Beat_Plan__c = beatmap.get(eobj.OwnerId);
            }
            System.debug('event with beat : '+scope);
            update scope;
                
        } catch (Exception e) {
           System.debug('error in beat plan batch : '+e.getMessage()+', at line  no : '+e.getLineNumber());
        } 
    }
    global void finish(Database.BatchableContext bx){
        system.debug('in finish method : ');
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = label.DCRBatchEmails.split(',');
        mail.setToAddresses(toAddresses);
        mail.setSubject('Beat Plan Batch Executed');
        mail.setPlainTextBody('Beat Plan created for today');
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
}