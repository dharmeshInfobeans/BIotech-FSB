@IsTest
private class CampaignUpdateProductHelperTest {

    @TestSetup
    static void setupData() {

        Target__c target = new Target__c(
            Name = 'Test Target'
        );
        insert target;

        // Campaign Name is overwritten by flows, so tests never query by Name
        insert new List<Campaign__c>{
            new Campaign__c(Name = 'Test Campaign 1', Target__c = target.Id),
            new Campaign__c(Name = 'Test Campaign 2', Target__c = target.Id)
        };

        insert new List<Product_Group__c>{
            new Product_Group__c(Name = 'Ophthalmology'),
            new Product_Group__c(Name = 'Orthopaedics'),
            new Product_Group__c(Name = 'Cardiology')
        };
    }


    // Campaigns in creation order (Id is ascending within a single insert)
    private static List<Campaign__c> getCampaigns() {
        return [
            SELECT Id, Focus_Product__c
            FROM Campaign__c
            ORDER BY Id
        ];
    }

    private static Map<String, Id> getProductGroupMap() {
        Map<String, Id> productGroupMap = new Map<String, Id>();
        for (Product_Group__c pg : [SELECT Id, Name FROM Product_Group__c]) {
            productGroupMap.put(pg.Name, pg.Id);
        }
        return productGroupMap;
    }

    private static Set<String> getFocusProducts(Id campaignId) {
        Campaign__c campaign = [
            SELECT Focus_Product__c
            FROM Campaign__c
            WHERE Id = :campaignId
        ];

        // Multi-select picklist values are stored semicolon separated
        return String.isBlank(campaign.Focus_Product__c)
            ? new Set<String>()
            : new Set<String>(campaign.Focus_Product__c.split(';'));
    }


    @IsTest
    static void testInsertCampaignLineItems() {

        Campaign__c campaign = getCampaigns()[0];
        Map<String, Id> pgMap = getProductGroupMap();

        Test.startTest();

        insert new List<Campaign_Line_Item__c>{
            new Campaign_Line_Item__c(
                Campaign__c = campaign.Id,
                Product_Group__c = pgMap.get('Ophthalmology')
            ),
            new Campaign_Line_Item__c(
                Campaign__c = campaign.Id,
                Product_Group__c = pgMap.get('Orthopaedics')
            ),
            new Campaign_Line_Item__c(
                Campaign__c = campaign.Id,
                Product_Group__c = pgMap.get('Cardiology')
            ),
            // Duplicate Product Group
            new Campaign_Line_Item__c(
                Campaign__c = campaign.Id,
                Product_Group__c = pgMap.get('Ophthalmology')
            )
        };

        Test.stopTest();

        System.assertEquals(
            new Set<String>{ 'Cardiology', 'Ophthalmology', 'Orthopaedics' },
            getFocusProducts(campaign.Id),
            'Campaign should contain unique Product Group names.'
        );
    }


    @IsTest
    static void testUpdateCampaignLineItemProductGroup() {

        Campaign__c campaign = getCampaigns()[0];
        Map<String, Id> pgMap = getProductGroupMap();

        Campaign_Line_Item__c lineItem = new Campaign_Line_Item__c(
            Campaign__c = campaign.Id,
            Product_Group__c = pgMap.get('Ophthalmology')
        );
        insert lineItem;

        Test.startTest();

        // Campaign__c is master-detail (not updateable), so send only the changed field
        update new Campaign_Line_Item__c(
            Id = lineItem.Id,
            Product_Group__c = pgMap.get('Orthopaedics')
        );

        Test.stopTest();

        System.assertEquals(
            new Set<String>{ 'Orthopaedics' },
            getFocusProducts(campaign.Id),
            'Campaign should contain the updated Product Group.'
        );
    }


    @IsTest
    static void testDeleteCampaignLineItem() {

        Campaign__c campaign = getCampaigns()[0];
        Map<String, Id> pgMap = getProductGroupMap();

        Campaign_Line_Item__c ophthalmologyLineItem = new Campaign_Line_Item__c(
            Campaign__c = campaign.Id,
            Product_Group__c = pgMap.get('Ophthalmology')
        );

        Campaign_Line_Item__c orthopaedicsLineItem = new Campaign_Line_Item__c(
            Campaign__c = campaign.Id,
            Product_Group__c = pgMap.get('Orthopaedics')
        );

        insert new List<Campaign_Line_Item__c>{
            ophthalmologyLineItem,
            orthopaedicsLineItem
        };

        Test.startTest();

        delete ophthalmologyLineItem;

        Test.stopTest();

        System.assertEquals(
            new Set<String>{ 'Orthopaedics' },
            getFocusProducts(campaign.Id),
            'Deleted Product Group should be removed from Campaign.'
        );
    }


    @IsTest
    static void testDeleteLastCampaignLineItem() {

        Campaign__c campaign = getCampaigns()[0];

        Campaign_Line_Item__c lineItem = new Campaign_Line_Item__c(
            Campaign__c = campaign.Id,
            Product_Group__c = getProductGroupMap().get('Ophthalmology')
        );
        insert lineItem;

        Test.startTest();

        delete lineItem;

        Test.stopTest();

        System.assert(
            getFocusProducts(campaign.Id).isEmpty(),
            'Campaign should have no Focus Product once all line items are removed.'
        );
    }


    // Campaign__c is a master-detail field and cannot be reparented, so this
    // verifies that changes on one Campaign never leak into another.
    @IsTest
    static void testCampaignsAreIndependent() {

        List<Campaign__c> campaigns = getCampaigns();
        Map<String, Id> pgMap = getProductGroupMap();

        Test.startTest();

        insert new List<Campaign_Line_Item__c>{
            new Campaign_Line_Item__c(
                Campaign__c = campaigns[0].Id,
                Product_Group__c = pgMap.get('Ophthalmology')
            ),
            new Campaign_Line_Item__c(
                Campaign__c = campaigns[1].Id,
                Product_Group__c = pgMap.get('Cardiology')
            )
        };

        Test.stopTest();

        System.assertEquals(
            new Set<String>{ 'Ophthalmology' },
            getFocusProducts(campaigns[0].Id),
            'Campaign 1 should only contain its own Product Group.'
        );

        System.assertEquals(
            new Set<String>{ 'Cardiology' },
            getFocusProducts(campaigns[1].Id),
            'Campaign 2 should only contain its own Product Group.'
        );
    }


    @IsTest
    static void testLineItemWithoutProductGroup() {

        Campaign__c campaign = getCampaigns()[0];

        Test.startTest();

        insert new Campaign_Line_Item__c(Campaign__c = campaign.Id);

        Test.stopTest();

        System.assert(
            getFocusProducts(campaign.Id).isEmpty(),
            'Line items without a Product Group should not populate Focus Product.'
        );
    }


    @IsTest
    static void testBulkInsert() {

        Campaign__c campaign = getCampaigns()[1];
        List<Id> productGroupIds = getProductGroupMap().values();

        List<Campaign_Line_Item__c> lineItems =
            new List<Campaign_Line_Item__c>();

        for (Integer i = 0; i < 100; i++) {
            lineItems.add(
                new Campaign_Line_Item__c(
                    Campaign__c = campaign.Id,
                    Product_Group__c =
                        productGroupIds[Math.mod(i, productGroupIds.size())]
                )
            );
        }

        Test.startTest();

        insert lineItems;

        Test.stopTest();

        System.assertEquals(
            new Set<String>{ 'Cardiology', 'Ophthalmology', 'Orthopaedics' },
            getFocusProducts(campaign.Id),
            'Bulk insert should create unique Product Group values.'
        );
    }
}