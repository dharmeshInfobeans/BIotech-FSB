global class ScheduleBatchAccountActivation implements Schedulable{
 global void execute(SchedulableContext sc)
 {
     BatchAccountActivationQuaterly bAcc = new BatchAccountActivationQuaterly('KRA');
     database.executeBatch(bAcc, 50);
 }
}