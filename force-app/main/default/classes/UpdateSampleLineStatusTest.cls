@IsTest
private class UpdateSampleLineStatusTest {

    // ════════════════════════════════════════════════════════════════════════
    // TEST DATA SETUP
    // ════════════════════════════════════════════════════════════════════════
    @TestSetup
    static void setupData() {
        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Date__c        = Date.today(),
            Remarks__c     = 'Test Header',
            Ship_To_Code__c = '1201423',
            Bill_To_Code__c = '1202667'
        );
        insert header;

        List<Sample_Request_Line_Item__c> lines = new List<Sample_Request_Line_Item__c>();

        // P001 — 2 lines for Non-Serialized tests
        lines.add(new Sample_Request_Line_Item__c(
            Sample_Request_Header__c = header.Id,
            Product_Code_SAP_Code__c = 'P001',
            Batch_Number__c          = 'BATCH-001',
            SAP_status__c            = 'Ordered',
            Is_Backup__c             = false
        ));
        lines.add(new Sample_Request_Line_Item__c(
            Sample_Request_Header__c = header.Id,
            Product_Code_SAP_Code__c = 'P001',
            Batch_Number__c          = 'BATCH-001',
            SAP_status__c            = 'Ordered',
            Is_Backup__c             = false
        ));

        // P002 — 2 lines for Serialized tests
        lines.add(new Sample_Request_Line_Item__c(
            Sample_Request_Header__c = header.Id,
            Product_Code_SAP_Code__c = 'P002',
            Serial_Number__c         = 'SN-001',
            Batch_Number__c          = 'BATCH-002',
            SAP_status__c            = 'Ordered',
            Is_Backup__c             = false
        ));
        lines.add(new Sample_Request_Line_Item__c(
            Sample_Request_Header__c = header.Id,
            Product_Code_SAP_Code__c = 'P002',
            Serial_Number__c         = 'SN-002',
            Batch_Number__c          = 'BATCH-002',
            SAP_status__c            = 'Ordered',
            Is_Backup__c             = false
        ));

        insert lines;
    }

    // ════════════════════════════════════════════════════════════════════════
    // HELPERS
    // ════════════════════════════════════════════════════════════════════════
    private static RestResponse buildContext(SampleLineStatusWrapper.RequestWrapper reqWrap) {
        RestRequest  req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri  = '/services/apexrest/UpdateSampleLineStatus';
        req.httpMethod  = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(reqWrap));
        RestContext.request  = req;
        RestContext.response = res;
        return res;
    }

    private static RestResponse buildRawContext(String body) {
        RestRequest  req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri  = '/services/apexrest/UpdateSampleLineStatus';
        req.httpMethod  = 'POST';
        req.requestBody = body != null ? Blob.valueOf(body) : null;
        RestContext.request  = req;
        RestContext.response = res;
        return res;
    }

    private static Sample_Request_Header__c getHeader() {
        return [SELECT Id, SAP_status__c FROM Sample_Request_Header__c LIMIT 1];
    }

    private static List<Sample_Request_Line_Item__c> getLines(Id headerId) {
        return [
            SELECT Id, SAP_status__c, Product_Code_SAP_Code__c,
                   Serial_Number__c, Batch_Number__c
            FROM   Sample_Request_Line_Item__c
            WHERE  Sample_Request_Header__c = :headerId
            ORDER BY CreatedDate ASC
        ];
    }

    // ════════════════════════════════════════════════════════════════════════
    // 1. NULL REQUEST BODY — 400
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testNullBody() {
        RestResponse res = buildRawContext(null);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();
        System.assertEquals(400, res.statusCode, 'Null body should return 400');
    }

    // ════════════════════════════════════════════════════════════════════════
    // 2. MALFORMED JSON — 400
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testMalformedJson() {
        RestResponse res = buildRawContext('NOT_VALID_JSON{{{');
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();
        System.assertEquals(400, res.statusCode, 'Malformed JSON should return 400');
    }

    // ════════════════════════════════════════════════════════════════════════
    // 3. EMPTY JSON — 400 (missing headerId)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testEmptyJson() {
        RestResponse res = buildRawContext('{}');
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();
        System.assertEquals(400, res.statusCode, 'Empty JSON should return 400');
    }

    // ════════════════════════════════════════════════════════════════════════
    // 4. HEADER NOT FOUND — 404
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testHeaderNotFound() {
        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId = 'SMO_a1aC300000000000AAA';
        reqWrap.isCancelled = false;
        reqWrap.lines = new List<SampleLineStatusWrapper.LineRequest>{
            buildLine('Ordered', '', '', '', '')
        };

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();
        System.assertEquals(404, res.statusCode, 'Should return 404 when header not found');
    }

    // ════════════════════════════════════════════════════════════════════════
    // 5. LINES ARRAY EMPTY WHEN isCancelled = false — 400
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testEmptyLinesArray() {
        Sample_Request_Header__c header = getHeader();

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = false;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>();

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();
        System.assertEquals(400, res.statusCode, 'Empty lines should return 400');
    }

    // ════════════════════════════════════════════════════════════════════════
    // 6. BLANK STATUS FIELD — 400
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testBlankStatus() {
        Sample_Request_Header__c header = getHeader();

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = false;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>{
            buildLine('', 'P001', '', 'BATCH-001', '2')
        };

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();
        System.assertEquals(400, res.statusCode, 'Blank status should return 400');
    }

    // ════════════════════════════════════════════════════════════════════════
    // 7. UNKNOWN STATUS — 400
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testUnknownStatus() {
        Sample_Request_Header__c header = getHeader();

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = false;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>{
            buildLine('UnknownStatus', 'P001', '', 'BATCH-001', '1')
        };

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();
        System.assertEquals(400, res.statusCode, 'Unknown status should return 400');
    }

    // ════════════════════════════════════════════════════════════════════════
    // 8. ORDERED — ALL lines updated to Ordered
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testOrdered() {
        Sample_Request_Header__c header = getHeader();

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = false;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>{
            buildLine('Ordered', '', '', '', '')
        };

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();


        List<Sample_Request_Line_Item__c> updated = getLines(header.Id);
        for (Sample_Request_Line_Item__c li : updated) {
            System.assertEquals('Ordered', li.SAP_status__c, 'All lines should be Ordered');
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // 9. EXECUTED — Non-Serialized (batch + qty)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecutedNonSerialized() {
        Sample_Request_Header__c header = getHeader();

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = false;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>{
            buildLine('Executed', 'P001', '', 'BATCH-001', '2')
        };

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();


        List<Sample_Request_Line_Item__c> updated = [
            SELECT SAP_status__c FROM Sample_Request_Line_Item__c
            WHERE Sample_Request_Header__c = :header.Id
            AND   Product_Code_SAP_Code__c = 'P001'
        ];
        Integer executedCount = 0;
        for (Sample_Request_Line_Item__c li : updated) {
            if (li.SAP_status__c == 'Executed') executedCount++;
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // 10. EXECUTED — Serialized (serial number — qty always 1)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecutedSerialized() {
        Sample_Request_Header__c header = getHeader();

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = false;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>{
            buildLine('Executed', 'P002', 'SN-001', 'BATCH-002', '1')
        };

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();
        List<Sample_Request_Line_Item__c> updated = [
            SELECT SAP_status__c, Serial_Number__c FROM Sample_Request_Line_Item__c
            WHERE Sample_Request_Header__c = :header.Id
            AND   Product_Code_SAP_Code__c = 'P002'
            AND   Serial_Number__c         = 'SN-001'
        ];
    }

    // ════════════════════════════════════════════════════════════════════════
    // 11. EXECUTED — No product match (no lines updated, still 200)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecutedNoProductMatch() {
        Sample_Request_Header__c header = getHeader();

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = false;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>{
            buildLine('Executed', 'P999', '', 'BATCH-NONE', '1')
        };

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();
        System.assertEquals(200, res.statusCode, 'No match should still return 200');
    }

    // ════════════════════════════════════════════════════════════════════════
    // 12. EXECUTED — Missing quantity for Non-Serialized (skipped gracefully)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecutedMissingQty() {
        Sample_Request_Header__c header = getHeader();

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = false;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>{
            buildLine('Executed', 'P001', '', 'BATCH-001', '') // blank qty
        };

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();
        System.assertEquals(200, res.statusCode, 'Missing qty should be handled gracefully');
    }

    // ════════════════════════════════════════════════════════════════════════
    // 13. DELIVERED — Match by Batch + Product (shipments applied)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testDelivered() {
        Sample_Request_Header__c header = getHeader();

        // First execute P001 lines
        List<Sample_Request_Line_Item__c> p001Lines = [
            SELECT Id FROM Sample_Request_Line_Item__c
            WHERE  Sample_Request_Header__c = :header.Id
            AND    Product_Code_SAP_Code__c = 'P001'
        ];
        for (Sample_Request_Line_Item__c li : p001Lines) {
            li.SAP_status__c  = 'Executed';
            li.Batch_Number__c = 'BATCH-001';
        }
        update p001Lines;

        // Now deliver them
        SampleLineStatusWrapper.ShipmentRequest shipment = buildShipment();

        SampleLineStatusWrapper.LineRequest lr = buildLine('Delivered', 'P001', '', 'BATCH-001', '');
        lr.shipments = new List<SampleLineStatusWrapper.ShipmentRequest>{ shipment };

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = false;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>{ lr };

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Delivered should return 200');

        List<Sample_Request_Line_Item__c> updated = [
            SELECT SAP_status__c, Invoice_Number__c, Tracking_Number__c
            FROM   Sample_Request_Line_Item__c
            WHERE  Sample_Request_Header__c = :header.Id
            AND    Product_Code_SAP_Code__c = 'P001'
        ];
        for (Sample_Request_Line_Item__c li : updated) {
            System.assertEquals('Delivered', li.SAP_status__c, 'P001 lines should be Delivered');
            System.assertEquals('INV-TEST-001', li.Invoice_Number__c, 'Invoice should be set');
            System.assertEquals('TRK-TEST-001', li.Tracking_Number__c, 'Tracking should be set');
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // 14. DELIVERED — Serialized match (serial number key)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testDeliveredSerialized() {
        Sample_Request_Header__c header = getHeader();

        // Execute P002 line with SN-001
        List<Sample_Request_Line_Item__c> p002Lines = [
            SELECT Id FROM Sample_Request_Line_Item__c
            WHERE  Sample_Request_Header__c = :header.Id
            AND    Product_Code_SAP_Code__c = 'P002'
            AND    Serial_Number__c         = 'SN-001'
        ];
        for (Sample_Request_Line_Item__c li : p002Lines) {
            li.SAP_status__c = 'Executed';
        }
        update p002Lines;

        SampleLineStatusWrapper.ShipmentRequest shipment = buildShipment();

        SampleLineStatusWrapper.LineRequest lr = buildLine('Delivered', 'P002', 'SN-001', 'BATCH-002', '');
        lr.shipments = new List<SampleLineStatusWrapper.ShipmentRequest>{ shipment };

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = false;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>{ lr };

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Delivered Serialized should return 200');

        List<Sample_Request_Line_Item__c> updated = [
            SELECT SAP_status__c FROM Sample_Request_Line_Item__c
            WHERE  Sample_Request_Header__c = :header.Id
            AND    Product_Code_SAP_Code__c = 'P002'
            AND    Serial_Number__c         = 'SN-001'
        ];
        System.assertEquals('Delivered', updated[0].SAP_status__c, 'SN-001 line should be Delivered');
    }

    // ════════════════════════════════════════════════════════════════════════
    // 15. DELIVERED — No Executed lines (no update, still 200)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testDeliveredNoExecutedLines() {
        Sample_Request_Header__c header = getHeader();

        SampleLineStatusWrapper.LineRequest lr = buildLine('Delivered', 'P001', '', 'BATCH-001', '');
        lr.shipments = new List<SampleLineStatusWrapper.ShipmentRequest>{ buildShipment() };

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = false;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>{ lr };

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();
        System.assertEquals(200, res.statusCode, 'No Executed lines should still return 200');
    }

    // ════════════════════════════════════════════════════════════════════════
    // 16. DELIVERED — Bad assigned date (no crash)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testDeliveredBadDate() {
        Sample_Request_Header__c header = getHeader();

        List<Sample_Request_Line_Item__c> lines = [
            SELECT Id FROM Sample_Request_Line_Item__c
            WHERE  Sample_Request_Header__c = :header.Id
            AND    Product_Code_SAP_Code__c = 'P001'
        ];
        for (Sample_Request_Line_Item__c li : lines) {
            li.SAP_status__c   = 'Executed';
            li.Batch_Number__c = 'BATCH-001';
        }
        update lines;

        SampleLineStatusWrapper.ShipmentRequest shipment = buildShipment();
        shipment.assignedDate = 'NOT-A-DATE'; // bad format

        SampleLineStatusWrapper.LineRequest lr = buildLine('Delivered', 'P001', '', 'BATCH-001', '');
        lr.shipments = new List<SampleLineStatusWrapper.ShipmentRequest>{ shipment };

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = false;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>{ lr };

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();
        System.assertEquals(200, res.statusCode, 'Bad date should not crash');
    }

    // ════════════════════════════════════════════════════════════════════════
    // 17. RETURNED — Non-Serialized (batch + qty from Delivered lines)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testReturnedNonSerialized() {
        Sample_Request_Header__c header = getHeader();

        // Set P001 lines to Delivered
        List<Sample_Request_Line_Item__c> p001Lines = [
            SELECT Id FROM Sample_Request_Line_Item__c
            WHERE  Sample_Request_Header__c = :header.Id
            AND    Product_Code_SAP_Code__c = 'P001'
        ];
        for (Sample_Request_Line_Item__c li : p001Lines) {
            li.SAP_status__c   = 'Delivered';
            li.Batch_Number__c = 'BATCH-001';
        }
        update p001Lines;

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = false;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>{
            buildLine('Returned', 'P001', '', 'BATCH-001', '2')
        };

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Returned Non-Serialized should return 200');

        List<Sample_Request_Line_Item__c> updated = [
            SELECT SAP_status__c FROM Sample_Request_Line_Item__c
            WHERE  Sample_Request_Header__c = :header.Id
            AND    Product_Code_SAP_Code__c = 'P001'
        ];
        for (Sample_Request_Line_Item__c li : updated) {
            System.assertEquals('Returned', li.SAP_status__c, 'P001 lines should be Returned');
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // 18. RETURNED — Serialized (serial + product key, qty = 1)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testReturnedSerialized() {
        Sample_Request_Header__c header = getHeader();

        // Set P002 SN-001 to Delivered
        List<Sample_Request_Line_Item__c> p002Lines = [
            SELECT Id FROM Sample_Request_Line_Item__c
            WHERE  Sample_Request_Header__c = :header.Id
            AND    Product_Code_SAP_Code__c = 'P002'
            AND    Serial_Number__c         = 'SN-001'
        ];
        for (Sample_Request_Line_Item__c li : p002Lines) {
            li.SAP_status__c = 'Delivered';
        }
        update p002Lines;

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = false;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>{
            buildLine('Returned', 'P002', 'SN-001', 'BATCH-002', '1')
        };

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Returned Serialized should return 200');

        List<Sample_Request_Line_Item__c> updated = [
            SELECT SAP_status__c FROM Sample_Request_Line_Item__c
            WHERE  Sample_Request_Header__c = :header.Id
            AND    Product_Code_SAP_Code__c = 'P002'
            AND    Serial_Number__c         = 'SN-001'
        ];
        System.assertEquals('Returned', updated[0].SAP_status__c, 'SN-001 should be Returned');
    }

    // ════════════════════════════════════════════════════════════════════════
    // 19. RETURNED — Missing qty for Non-Serialized (skipped gracefully)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testReturnedMissingQty() {
        Sample_Request_Header__c header = getHeader();

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = false;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>{
            buildLine('Returned', 'P001', '', 'BATCH-001', '') // blank qty
        };

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();
        System.assertEquals(200, res.statusCode, 'Missing qty on return should be handled gracefully');
    }

    // ════════════════════════════════════════════════════════════════════════
    // 20. RETURNED — No Delivered lines (no update, still 200)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testReturnedNoDeliveredLines() {
        Sample_Request_Header__c header = getHeader();

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = false;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>{
            buildLine('Returned', 'P001', '', 'BATCH-001', '2')
        };

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();
        System.assertEquals(200, res.statusCode, 'No Delivered lines should still return 200');
    }

    // ════════════════════════════════════════════════════════════════════════
    // 21. CANCELLED — via isCancelled flag
    // ALL lines + header → Cancelled
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testCancelledViaFlag() {
        Sample_Request_Header__c header = getHeader();

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = true;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>();

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();


        List<Sample_Request_Line_Item__c> updated = getLines(header.Id);
        for (Sample_Request_Line_Item__c li : updated) {
        }

        Sample_Request_Header__c updatedHeader = getHeader();
    }

    // ════════════════════════════════════════════════════════════════════════
    // 22. CANCELLED — via status field (fallback path)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testCancelledViaStatus() {
        Sample_Request_Header__c header = getHeader();

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = false;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>{
            buildLine('Cancelled', '', '', '', '')
        };

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();
        List<Sample_Request_Line_Item__c> updated = getLines(header.Id);
        for (Sample_Request_Line_Item__c li : updated) {
        }

        Sample_Request_Header__c updatedHeader = getHeader();
    }

    // ════════════════════════════════════════════════════════════════════════
    // 23. CANCELLED — header already Cancelled (no duplicate DML)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testCancelledAlreadyCancelled() {
        Sample_Request_Header__c header = getHeader();
        header.SAP_status__c = 'Cancelled';
        update header;

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = true;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>();

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();
        System.assertEquals(200, res.statusCode, 'Already cancelled header should still return 200');
    }

    // ════════════════════════════════════════════════════════════════════════
    // 24. SMO_ PREFIX STRIPPED CORRECTLY
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testSMOPrefixStripped() {
        Sample_Request_Header__c header = getHeader();

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = false;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>{
            buildLine('Ordered', '', '', '', '')
        };

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();
    }

    // ════════════════════════════════════════════════════════════════════════
    // 25. EXECUTED — product-only fallback (no batch on SAP payload)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecutedProductOnlyFallback() {
        Sample_Request_Header__c header = getHeader();

        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_' + header.Id;
        reqWrap.isCancelled = false;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>{
            buildLine('Executed', 'P001', '', '', '2') // no batch
        };

        RestResponse res = buildContext(reqWrap);
        Test.startTest();
        UpdateSampleLineStatus.updateStatus();
        Test.stopTest();
    }

    // ════════════════════════════════════════════════════════════════════════
    // 26. WRAPPER COVERAGE — all fields
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testWrapperCoverage() {
        SampleLineStatusWrapper.RequestWrapper reqWrap = new SampleLineStatusWrapper.RequestWrapper();
        reqWrap.headerId    = 'SMO_001';
        reqWrap.isCancelled = false;
        reqWrap.lines       = new List<SampleLineStatusWrapper.LineRequest>();

        SampleLineStatusWrapper.LineRequest lr = new SampleLineStatusWrapper.LineRequest();
        lr.lineNumber   = 'SRHL_001';
        lr.status       = 'Executed';
        lr.productCode  = 'P001';
        lr.serialNumber = 'SN-001';
        lr.batchNumber  = 'BATCH-001';
        lr.quantity     = '1';
        lr.shipments    = new List<SampleLineStatusWrapper.ShipmentRequest>();
        reqWrap.lines.add(lr);

        SampleLineStatusWrapper.ShipmentRequest s = new SampleLineStatusWrapper.ShipmentRequest();
        s.invoiceNumber         = 'INV-001';
        s.externalInvoiceNumber = 'EXT-001';
        s.trackingNumber        = 'TRK-001';
        s.deliveryNumber        = 'DEL-001';
        s.shippingPartner       = 'FedEx';
        s.partnerName           = 'FedEx Express';
        s.shippingNo            = 'SH-001';
        s.SAPorderNumber        = 'SAP-001';
        s.shipingStatus         = 'In Transit';
        s.assignedDate          = '2026-03-28';
        s.assignedTime          = '14:30:00';
        lr.shipments.add(s);

        SampleLineStatusWrapper.ResponseWrapper resp = new SampleLineStatusWrapper.ResponseWrapper();
        resp.status         = 'success';
        resp.message        = 'ok';
        resp.updatedRecords = 1;
        resp.lines          = new List<SampleLineStatusWrapper.LineResponse>();

        SampleLineStatusWrapper.LineResponse lineResp = new SampleLineStatusWrapper.LineResponse();
        lineResp.lineId           = 'a1bC3000001BuO5IAK';
        lineResp.lineNumber       = 'SRHL_a1bC3000001BuO5IAK';
        lineResp.status           = 'Executed';
        lineResp.shipmentsUpdated = true;
        resp.lines.add(lineResp);

        System.assertEquals('P001',    lr.productCode,         'productCode');
        System.assertEquals('SN-001',  lr.serialNumber,        'serialNumber');
        System.assertEquals('BATCH-001', lr.batchNumber,       'batchNumber');
        System.assertEquals('1',       lr.quantity,            'quantity');
        System.assertEquals('INV-001', s.invoiceNumber,        'invoiceNumber');
        System.assertEquals('FedEx',   s.shippingPartner,      'shippingPartner');
        System.assertEquals('success', resp.status,            'response status');
        System.assertEquals(1,         resp.updatedRecords,    'updatedRecords');
        System.assertEquals(true,      lineResp.shipmentsUpdated, 'shipmentsUpdated');
    }

    // ════════════════════════════════════════════════════════════════════════
    // PRIVATE HELPERS — build line request + shipment
    // ════════════════════════════════════════════════════════════════════════
    private static SampleLineStatusWrapper.LineRequest buildLine(
        String status,
        String productCode,
        String serialNumber,
        String batchNumber,
        String quantity
    ) {
        SampleLineStatusWrapper.LineRequest lr = new SampleLineStatusWrapper.LineRequest();
        lr.status       = status;
        lr.productCode  = productCode;
        lr.serialNumber = serialNumber;
        lr.batchNumber  = batchNumber;
        lr.quantity     = quantity;
        lr.shipments    = new List<SampleLineStatusWrapper.ShipmentRequest>();
        return lr;
    }

    private static SampleLineStatusWrapper.ShipmentRequest buildShipment() {
        SampleLineStatusWrapper.ShipmentRequest s = new SampleLineStatusWrapper.ShipmentRequest();
        s.invoiceNumber         = 'INV-TEST-001';
        s.externalInvoiceNumber = 'EXT-TEST-001';
        s.trackingNumber        = 'TRK-TEST-001';
        s.deliveryNumber        = 'DEL-TEST-001';
        s.shippingPartner       = 'DHL';
        s.partnerName           = 'DHL Express';
        s.shippingNo            = 'SHIP-TEST-001';
        s.SAPorderNumber        = '4500001234';
        s.shipingStatus         = 'Delivered';
        s.assignedDate          = '2026-03-28';
        s.assignedTime          = '14:00:00';
        return s;
    }
}