@IsTest
public class CalculateSAPMaterialCodeTest {

    @testSetup
    static void testDataCreate() {

        Id systemAdminProfileId = [
            SELECT Id FROM Profile WHERE Name = 'System Administrator'
        ].Id;

        Id RBMRoleId = [
            SELECT Id FROM UserRole
            WHERE Name LIKE 'RSM Gujarat%'
            LIMIT 1
        ].Id;

        User systemAdmin =
            IB_TestDataFactory.createUser(
                systemAdminProfileId,
                'International',
                RBMRoleId,
                'EP-86573',
                'I;II;III;IV;V',
                null
            );

        System.runAs(systemAdmin) {

            // Region
            CIty__c MiamiRegion =
                IB_TestDataFactory.createRegionData('Miami', '90', 'US');

            // Dealer Account
            Id dealerAccountRT =
                Schema.sObjectType.Account
                    .getRecordTypeInfosByName()
                    .get('Dealer Portal')
                    .getRecordTypeId();

            Account internationalAcc =
                IB_TestDataFactory.createAccForInternational(MiamiRegion, '873890');
            internationalAcc.RecordTypeId = dealerAccountRT;
            update internationalAcc;

            Contact partnerContact =
                IB_TestDataFactory.createContact(internationalAcc.Id, 'Geller');

            // Plant
            Plant__c plant1 =
                IB_TestDataFactory.createPlantdata(
                    '1100-BTVCPL Unit-1',
                    'Ahmedabad, India',
                    'India'
                );

            // Products
            Product__c prod1 =
                IB_TestDataFactory.createProductData(
                    'V',
                    'International',
                    'EP096',
                    'Eyecryl Phakic TORIC'
                );
            prod1.Plant__c = plant1.Id;

            Product__c prod2 =
                IB_TestDataFactory.createProductData(
                    'I',
                    'International',
                    'EP096',
                    'Eyecryl Plus 600'
                );
            prod2.Plant__c = plant1.Id;

            update new List<Product__c>{ prod1, prod2 };

            // Product Model
            Product_Model__c model1 =
                IB_TestDataFactory.createProductModelData(
                    prod1.Id,
                    'B0702312'
                );

            // Material Stocks (MULTIPLE → critical for logic)
            IB_TestDataFactory.createProductMaterialStockData(
                prod1.Id,
                'P10C002A090',
                plant1.Id,
                model1.Id
            );

            IB_TestDataFactory.createProductMaterialStockData(
                prod1.Id,
                'P12C003A080',
                plant1.Id,
                model1.Id
            );

            // Master Agreement
            Date startDate = Date.today().addDays(-1);
            Date endDate   = Date.today().addDays(1);

            List<Master_Agreement__c> mas =
                IB_TestDataFactory.createMasterAgreements(
                    internationalAcc.Id,
                    startDate,
                    endDate,
                    1
                );

            Agreement_Product__c agrProd =
                IB_TestDataFactory.createAgreementProductForPoducts(
                    prod1.Id,
                    mas[0].Id
                );

            // Buyer Account
            Id buyerRT =
                Schema.sObjectType.Account
                    .getRecordTypeInfosByName()
                    .get('Buyer Account')
                    .getRecordTypeId();

            Account buyer = new Account(
                Name = 'Buyer',
                RecordTypeId = buyerRT,
                ParentId = internationalAcc.Id,
                Parent_Customer__c = internationalAcc.Id
            );
            insert buyer;

            // Order
            Order__c ord = new Order__c(
                Account__c = internationalAcc.Id,
                Buyer_Account__c = buyer.Id,
                Is_it_ok_to_cancel_old_Draft_Orders__c = true
            );
            insert ord;

            // Order Product (hits full spherical / cyl / axis logic)
            IB_TestDataFactory.createOrderProductData(
                ord.Id,
                false,
                agrProd.Id,
                prod1.Id,
                '10',       // spherical
                '0.25',     // cylindrical
                90,         // axis
                'B0702312'  // model text
            );

            // SAP Creds (required by org, not used directly)
            insert new SAP_Creds__c(
                Name = 'SAP_Fright_Split_Order',
                Endpoint__c = 'https://httpbin.org/post',
                Username__c = 'miuser',
                Password__c = 'password@123',
                Environment_Name__c = 'Dev'
            );
        }
    }

    // ========================= TEST METHODS =========================

    @IsTest
    static void testMaterialCode_ModelStockMatch() {

        Order__c ord = [SELECT Id FROM Order__c LIMIT 1];

        Test.startTest();
        Map<Id, String> result =
            CalculateSAPMaterialCode.processOrderProductsByOrderId(ord.Id);
        Test.stopTest();

        System.assert(!result.isEmpty(), 'Result should not be empty');

        Order_Product__c op =
            [SELECT Id FROM Order_Product__c LIMIT 1];

        String materialCode = result.get(op.Id);

        System.assertNotEquals(
            null,
            materialCode,
            'Material code must be populated'
        );

        System.assert(
            materialCode.contains('P') ||
            materialCode.contains('C') ||
            materialCode.contains('A'),
            'Material code should be derived from stock'
        );
    }

    @IsTest
    static void testFallbackToDummyProductCode() {

        Product__c prodNoStock = new Product__c(
            Name = 'No Stock Product',
            Region__c = 'International',
            Dummy_Product_Code__c = 'DUMMY-F'
        );
        insert prodNoStock;

        Order__c ord = [SELECT Id FROM Order__c LIMIT 1];

        Order_Product__c op = new Order_Product__c(
            Order__c = ord.Id,
            Product__c = prodNoStock.Id
        );
        insert op;

        Test.startTest();
        Map<Id, String> result =
            CalculateSAPMaterialCode.processOrderProductsByOrderId(ord.Id);
        Test.stopTest();

        System.assertEquals(
            'DUMMY-F',
            result.get(op.Id),
            'Should fallback to dummy product code'
        );
    }

    @IsTest
    static void testNullOrderId() {

        Test.startTest();
        Map<Id, String> result =
            CalculateSAPMaterialCode.processOrderProductsByOrderId(null);
        Test.stopTest();

        System.assertEquals(
            0,
            result.size(),
            'Null Order Id should return empty map'
        );
    }
}