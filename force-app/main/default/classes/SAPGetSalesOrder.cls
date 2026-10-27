public class SAPGetSalesOrder {

    public static void getSalesOrder() {

        Http http = new Http();
        HttpRequest req = new HttpRequest();

        // Endpoint
        req.setEndpoint(
            'http://103.231.40.218:50000/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrder(\'5000001234\')'
        );
        req.setMethod('GET');

        // ---- BASIC AUTH ----
        String username = 'PIUSER';   // replace
        String password = 'Welcome@123';   // replace

        String auth = EncodingUtil.base64Encode(
            Blob.valueOf(username + ':' + password)
        );
        req.setHeader('Authorization', 'Basic ' + auth);

        // Headers
        req.setHeader('Accept', 'application/json');

        try {
            HttpResponse res = http.send(req);

            System.debug('Status Code : ' + res.getStatusCode());
            System.debug('Status      : ' + res.getStatus());
            System.debug('Response    : ' + res.getBody());

        } catch (Exception e) {
            System.debug('Callout Error: ' + e.getMessage());
        }
    }
}