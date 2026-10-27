global class ParentToChildSyncAPIbatch implements Database.Batchable<String>, Database.Stateful {

    private Map<String, List<String>> parentToChildMap;
    private Map<String, String> bundleFlagMap;
    private List<String> chunkParents;

    // Constructor
    public ParentToChildSyncAPIbatch(
        Map<String, List<String>> parentToChildMap,
        Map<String, String> bundleFlagMap,
        List<String> chunkParents
    ){
        this.parentToChildMap = parentToChildMap;
        this.bundleFlagMap = bundleFlagMap;
        this.chunkParents = chunkParents;
    }

    // ===============================
    // START
    // ===============================
    global Iterable<String> start(Database.BatchableContext bc) {

        System.debug('🚀 ParentToChildSyncAPIbatch Started');

        return chunkParents;

    }

    // ===============================
    // EXECUTE
    // ===============================
    global void execute(Database.BatchableContext bc, List<String> scope) {

        try {
            
            if(scope.size()<1){
                 return;
            }

            if (parentToChildMap.isEmpty()) return;

            Set<String> allCodes = new Set<String>();

            for(String parentCode : scope){

                allCodes.add(parentCode);

                if(parentToChildMap.containsKey(parentCode)){
                    allCodes.addAll(parentToChildMap.get(parentCode));
                }
            }

            allCodes.addAll(bundleFlagMap.keySet());

            // Fetch Accounts
            Map<String, Account> accMap = new Map<String, Account>();

            for (Account acc : [
                SELECT Id, Customer_Type__c, SAP_Code__c, ParentId
                FROM Account
                WHERE SAP_Code__c IN :allCodes
            ]) {
                accMap.put(acc.SAP_Code__c, acc);
            }

            List<Account> updateList = new List<Account>();
            Set<Id> processedIds = new Set<Id>();

            for (String parentCode : scope) {

                Account parentAcc = accMap.get(parentCode);
                if (parentAcc == null) continue;

                if(!parentToChildMap.containsKey(parentCode)) continue;

                for (String childCode : parentToChildMap.get(parentCode)) {

                    Account childAcc = accMap.get(childCode);

                    if (childAcc != null 
                        && childAcc.Id != parentAcc.Id
                        && childAcc.ParentId != parentAcc.Id
                        && parentAcc.ParentId != childAcc.Id) {

                        childAcc.ParentId = parentAcc.Id;

                        if (!processedIds.contains(childAcc.Id)) {
                            updateList.add(childAcc);
                            processedIds.add(childAcc.Id);
                        }
                    }
                }
            }

            System.debug('bundleFlagMap--->' + JSON.serialize(bundleFlagMap));

            for (String sapCode : bundleFlagMap.keySet()) {

                Account acc = accMap.get(sapCode);
                if (acc == null) continue;

                String bundleValue = bundleFlagMap.get(sapCode);
                String newType = (bundleValue == 'X') ? 'Bundle' : 'Non-Bundle';

                if (String.isBlank(acc.Customer_Type__c) || acc.Customer_Type__c != newType) {

                    acc.Customer_Type__c = newType;

                    if (!processedIds.contains(acc.Id)) {
                        updateList.add(acc);
                        processedIds.add(acc.Id);
                    }
                }
            }

            TriggerControl.skipAccountTrigger = true;

            if (!updateList.isEmpty()) {
                update updateList;
            }

            TriggerControl.skipAccountTrigger = false;

        } catch (Exception ex) {

            createApiErrorLog(
                'MOU scheme',
                'ParentToChildSyncAPIbatch',
                500,
                'DML_EXCEPTION',
                ex.getMessage(),
                null,
                null
            );
        }
    }

    // ===============================
    // FINISH
    // ===============================
    global void finish(Database.BatchableContext bc) {

        System.debug('🏁 ParentToChildSyncAPIbatch completed');

    }

    // ===============================
    // API LOG METHOD
    // ===============================
    public static void createApiErrorLog(
        String apiModuleType,
        String className,
        Integer statusCode,
        String status,
        String message,
        String requestBody,
        String responseBody
    ) {
        try {

            API_Log__c log = new API_Log__c();
            log.API_Module_Type__c = apiModuleType;
            log.Class_Name__c = className;
            log.Log_Date__c = System.now();
            log.Message__c = message;
            log.request_body__c = requestBody;
            log.Response_Body__c = responseBody;

            insert log;

        } catch (Exception ex) {

            System.debug('API Log insert failed: ' + ex.getMessage());

        }
    }
}