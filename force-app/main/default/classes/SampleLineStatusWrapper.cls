global class SampleLineStatusWrapper {

    // ════════════════════════════════════════════════════════════════════════
    // REQUEST WRAPPERS
    // ════════════════════════════════════════════════════════════════════════

    global class RequestWrapper {
        public String            headerId;     // SMO_<SF Header Id>
        public Boolean           isCancelled;  // true = SAP deleted order
        public List<LineRequest> lines;

        public RequestWrapper() {
            headerId    = '';
            isCancelled = false;
            lines       = new List<LineRequest>();
        }
    }

    global class LineRequest {
        public String                lineNumber;    // SRHL_<SF Line Item Id>
        public String                status;        // Ordered/Executed/Delivered/Returned/Cancelled
        public String                productCode;   // SAP Product Code
        public String                serialNumber;  // Serialized only — match key
        public String                batchNumber;   // Batch Number
        public String                quantity;      // Qty from SAP — drives how many SF lines to update
        public List<ShipmentRequest> shipments;     // ✅ ONLY for Delivered status

        public LineRequest() {
            lineNumber   = '';
            status       = '';
            productCode  = '';
            serialNumber = '';
            batchNumber  = '';
            quantity     = '';
            shipments    = new List<ShipmentRequest>();
        }
    }

    global class ShipmentRequest {
        public String invoiceNumber;          // → Invoice_Number__c
        public String externalInvoiceNumber;  // → External_Invoice_Number__c
        public String trackingNumber;         // → Tracking_Number__c
        public String deliveryNumber;         // → DeliveryNumber__c
        public String shippingPartner;        // → Shipping_Partner__c
        public String partnerName;            // → Partner_Name__c
        public String shippingNo;             // → Shipping_No__c
        public String SAPorderNumber;         // → Customer_SAP_Code__c
        public String shipingStatus;          // → Shiping_Status__c
        public String assignedDate;           // → Assigned_Date__c  (YYYY-MM-DD)
        public String assignedTime;           // → Assigned_Time__c  (HH:mm:ss)

        public ShipmentRequest() {
            invoiceNumber         = '';
            externalInvoiceNumber = '';
            trackingNumber        = '';
            deliveryNumber        = '';
            shippingPartner       = '';
            partnerName           = '';
            shippingNo            = '';
            SAPorderNumber        = '';
            shipingStatus         = '';
            assignedDate          = '';
            assignedTime          = '';
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // RESPONSE WRAPPERS
    // ════════════════════════════════════════════════════════════════════════

    global class ResponseWrapper {
        public String             status;
        public String             message;
        public Integer            updatedRecords;
        public List<LineResponse> lines;

        public ResponseWrapper() {
            status         = '';
            message        = '';
            updatedRecords = 0;
            lines          = new List<LineResponse>();
        }
    }

    global class LineResponse {
        public String  lineId;
        public String  lineNumber;
        public String  status;
        public Boolean shipmentsUpdated;

        public LineResponse() {
            lineId           = '';
            lineNumber       = '';
            status           = '';
            shipmentsUpdated = false;
        }
    }
}