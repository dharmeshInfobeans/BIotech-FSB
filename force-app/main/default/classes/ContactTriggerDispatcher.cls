public class ContactTriggerDispatcher {

    public static void handleBefore(List<Contact> newList, Map<Id, Contact> oldMap) {
        
        // Instantiate Handler Class
        ContactTriggerHandler handler = new ContactTriggerHandler();
        
        // Call Duplicate Check Logic
        handler.checkForDuplicate(newList);
    }
}