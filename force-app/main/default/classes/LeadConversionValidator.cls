public class LeadConversionValidator {

    @InvocableMethod(
        label='Validate Lead Has Products'
        description='Returns error message if Lead has no Lead Products'
    )
    public static List<String> validateLeadProducts(List<Id> leadIds) {
        List<String> results = new List<String>();

        Map<Id, Integer> productCountByLead = new Map<Id, Integer>();

        for (AggregateResult agg : [
            SELECT Leads__c leadId, COUNT(Id) cnt
            FROM Lead_Product__c
            WHERE Leads__c IN :new Set<Id>(leadIds)
            GROUP BY Leads__c
        ]) {
            productCountByLead.put(
                (Id) agg.get('leadId'),
                (Integer) agg.get('cnt')
            );
        }

        for (Id leadId : leadIds) {
            Integer count = productCountByLead.get(leadId);
            results.add(
                (count == null || count == 0)
                    ? 'ERROR'
                    : 'OK'
            );
        }

        return results;
    }
}