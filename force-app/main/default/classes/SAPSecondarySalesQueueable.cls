global class SAPSecondarySalesQueueable implements Queueable {
    private String requestBody;
    public SAPSecondarySalesQueueable(String requestBody) {
        this.requestBody = requestBody;
    }
    global void execute(QueueableContext qc) {
        try {
            System.debug('==> Queueable Safety Run Started');
            List<SecondarySalesWrapper.SecondarySalesRequest> lstPayload =
                (List<SecondarySalesWrapper.SecondarySalesRequest>)
                JSON.deserialize(
                    requestBody,
                    List<SecondarySalesWrapper.SecondarySalesRequest>.class
                );
            if (lstPayload == null || lstPayload.isEmpty()) {
                System.debug('Queueable: Payload empty');
                return;
            }
            System.debug('==> Queueable: Payload verified. Records already created by REST class.');
            System.debug('==> Queueable: Orders in payload: ' + lstPayload.size());
            for (SecondarySalesWrapper.SecondarySalesRequest payload : lstPayload) {
                System.debug('==> Queueable Audit: Processed Order => '
                             + payload.SalesOrder.Header.SAPOrderNumber
                             + ' | Type: ' + payload.SalesOrder.Header.OrderType
                             + ' | Items: ' + payload.SalesOrder.Items.size()
                            );
            }
            System.debug('==> Queueable Safety Run Completed Successfully');
        } catch (Exception e) {
            System.debug('==> Queueable Error: ' + e.getMessage()
                         + ' | Line: ' + e.getLineNumber()
                         + ' | Stack: ' + e.getStackTraceString()
                        );
        }
    }
}