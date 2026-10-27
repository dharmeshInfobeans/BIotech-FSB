public without sharing class MarketXrayFormEmailNotificationApprover {
    
    @InvocableMethod(label='Get Pending Workitem IDs')
    public static List<ProcessInstanceObj> getPendingWorkitems(List<String> requests) {
        List<ProcessInstanceObj> results = new List<ProcessInstanceObj>();

        for(String req : requests) {
            ProcessInstanceObj obj = new ProcessInstanceObj();

            // Query the workitem and actor
            ProcessInstanceWorkitem wi = [
                SELECT Id, ActorId
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstanceId IN (
                    SELECT Id
                    FROM ProcessInstance
                    WHERE TargetObjectId = :req
                      AND Status = 'Pending'
                )
                LIMIT 1
            ];
            
            if(wi != null) {
                obj.processWorkItemId = wi.Id;
                obj.approverUserId = wi.ActorId;
            }
            
            results.add(obj);
        }
		System.debug('results'+ results);
        return results;
    }

    public class ProcessInstanceObj {
        @InvocableVariable(label='ProcessInstanseId')
        public Id processWorkItemId;

        @InvocableVariable(label='ApproverUserId')
        public Id approverUserId;
    }
}






/*public without sharing class MarketXrayFormEmailNotificationApprover {
    
    @InvocableMethod(label='Get Pending Workitem IDs')
    public static List<processInstanseObj> getPendingWorkitems(List<String> requests) {
        System.debug('requests'+requests);
        processInstanseObj proInstObj=new processInstanseObj();
        proInstObj.processWorkItemId=[Select id from ProcessInstanceWorkitem where ProcessInstanceId IN (Select id from ProcessInstance where TargetObjectId IN: requests and Status ='Pending')]?.Id;
        System.debug('proInstObj.processWorkItemId: '+proInstObj.processWorkItemId);
        return new List<processInstanseObj>{proInstObj};
    }
    
    
    
    public class processInstanseObj{
     
      @InvocableVariable(label='ProcessInstanseId')
      public Id processWorkItemId;
    }
}*/