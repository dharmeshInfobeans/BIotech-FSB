public class Create_Log_Entries{
    public static Log_Entry__c createLogEntries(String logType, String status, String message, String region, String className, String classType, String frequency){
        Log_Entry__c logEntry = new Log_Entry__c();
        logEntry.Region__c = region;
        logEntry.Status__c = status;
        logEntry.Message__c = message;
        logEntry.Log_Type__c = logType;
        logEntry.Class_Type__c = classType;
        logEntry.Class_Name__c = className;
        logEntry.Frequency__c = frequency;
        Insert logEntry;
        return logEntry;
    }
}