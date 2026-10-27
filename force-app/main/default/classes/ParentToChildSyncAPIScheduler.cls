global without sharing class ParentToChildSyncAPIScheduler implements Schedulable {

    global void execute(SchedulableContext sc) {

        List<ParentToChildBatchInvoker.FlowInput> inputs = 
            new List<ParentToChildBatchInvoker.FlowInput>();

        ParentToChildBatchInvoker.FlowInput inp = 
            new ParentToChildBatchInvoker.FlowInput();

        // Dummy value if required
        inp.customerNumber = '1200001';

        inputs.add(inp);

        ParentToChildBatchInvoker.runBatch(inputs);
    }
}