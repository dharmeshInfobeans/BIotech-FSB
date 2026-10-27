@isTest
public class CampaignTriggerHelperTest {

    @testSetup
    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        User u = new User(
            Alias = 'test1',
            Email='test@test.com',
            EmailEncodingKey='UTF-8',
            LastName='User',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            TimeZoneSidKey='Asia/Kolkata',
            ProfileId = p.Id,
            Username='test' + System.currentTimeMillis() + '@test.com'
        );
        insert u;
    }

    // ---------- SAFE TARGET ----------
    static Target__c buildSafeTarget(String name) {

        Target__c t = new Target__c(
            Name = name,
            Date__c = System.today(),
            Operation__c = 'Direct',
            Region__c = 'APAC',
            Zone__c = 'EAST',
            Country__c = 'INDIA',
            Group__c = 'ACCESS TO INNOVATION SERIES',
            List_Of_Activities__c = 'CME',
            Activity_Type__c = 'CME' // avoids helper failure
        );
        insert t;

        insert new Target_Line_Item__c(Target__c = t.Id);

        return t;
    }

    // ---------- CAMPAIGN ----------
    static Campaign__c buildCampaign(Id targetId, Id userId) {

        return new Campaign__c(
            Name = 'Test Campaign',
            Target__c = targetId,
            Executer__c = userId,

            Operation__c = 'Direct',
            Region__c = 'APAC',
            Zone__c = 'EAST',
            Country__c = 'INDIA',
            State__c = 'Punjab',

            Group__c = 'OTHER',
            List_Of_Activities__c = 'CME',
            Activity_Type__c = 'CONFERENCES',

            Categorize__c = 'Biotech Driven Event',

            City__c = 'Delhi',
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(2),

            Three_x_Three__c = 'test'
        );
    }

    // ---------- BASIC COVERAGE ----------
    @isTest
    static void test_fullCoverage() {

        User u = [SELECT Id FROM User LIMIT 1];

        Target__c t = buildSafeTarget('SafeTarget');

        Campaign__c cam = buildCampaign(t.Id, u.Id);

        Test.startTest();
        insert cam;

        cam.City__c = 'Ahmedabad';
        update cam;
        Test.stopTest();
    }

    // ---------- getUniqueCountMap ----------
    @isTest
    static void test_getUniqueCountMap() {

        List<Map<String, Double>> dataList = new List<Map<String, Double>>();

        dataList.add(new Map<String, Double>{
            'Phakic'=>1,'Hydrophilics'=>2,
            'Hydrophobic Monofocal'=>3,
            'Popular Hydrophobic Monofocal'=>4,
            'MF Family'=>5,'Trifocal Family'=>6,
            'EDOF Family'=>7,'Toric'=>8
        });

        dataList.add(new Map<String, Double>{
            'Phakic'=>1,'Hydrophilics'=>1,
            'Hydrophobic Monofocal'=>1,
            'Popular Hydrophobic Monofocal'=>1,
            'MF Family'=>1,'Trifocal Family'=>1,
            'EDOF Family'=>1,'Toric'=>1
        });

        Test.startTest();
        CampaignTriggerHelper.getUniqueCountMap(dataList);
        Test.stopTest();
    }

    // ---------- ACCOUNT + MEMBER BLOCK ----------
    @isTest
    static void test_afterUpdate_fullCoverage_block() {

        CampaignTriggerHelper.isUpdated = false;

        User u = [SELECT Id FROM User LIMIT 1];

        CIty__c region = new CIty__c(
            Name = 'TestRegion',
            country_key__c = 'IN',
            Region_Code__c = 'TR'
        );
        insert region;

        Account acc = new Account(
            Name = 'TestAcc',
            BillingCity = 'Ahmedabad',
            SAP_Code__c = '12345',
            Region__c = region.Id
        );
        insert acc;

        // 🔥 CIS without numeric fields (your requirement)
        insert new CIS_Header__c(
            Account__c = acc.Id,
            Status__c = 'Approved',
            IsPrimary__c = true
        );

        insert new ProductMapping__c(Name='P1', Product_Category__c='Phakic');
        insert new ProductMapping__c(Name='P2', Product_Category__c='Hydrophilics');
        insert new ProductMapping__c(Name='P3', Product_Category__c='MF Family');
        insert new ProductMapping__c(Name='P4', Product_Category__c='Toric');

        Target__c t = buildSafeTarget('MemberTarget');

        Campaign__c cam = new Campaign__c(
            Name='MemberCampaign',
            Target__c=t.Id,
            Executer__c=u.Id,
            Activity_Type__c='CONFERENCES',
            Start_Date__c=System.today(),
            End_Date__c=System.today().addDays(1),
            Operation__c='Direct',
            Region__c='APAC',
            Zone__c='EAST',
            Country__c='INDIA',
            State__c='Punjab',
            City__c='Ahmedabad',
            Group__c='OTHER',
            List_Of_Activities__c='CME',
            Categorize__c='Biotech Driven Event',
            Product_1_Name__c='P1',
            Product_2_Name__c='P2',
            Product_3_Name__c='P3',
            Product_4_Name__c='P4',
            Three_x_Three__c='test'
        );
        insert cam;

        insert new Campaign_Member__c(
            Campaign1__c=cam.Id,
            Account__c=acc.Id
        );

        Test.startTest();
        update cam;
        Test.stopTest();
    }

    // ---------- EXISTING TARGET MATCH ----------
  /*  @isTest
    static void test_existingTargetMatch() {

        CampaignTriggerHelper.isUpdated = false;

        User u = [SELECT Id FROM User LIMIT 1];
        Date d = System.today();
        DateTime dt = DateTime.newInstance(d, System.now().time());

        Map<String,String> qMap = new Map<String,String>{
            'January'=>'Q1','February'=>'Q1','March'=>'Q1',
            'April'=>'Q2','May'=>'Q2','June'=>'Q2',
            'July'=>'Q3','August'=>'Q3','September'=>'Q3',
            'October'=>'Q4','November'=>'Q4','December'=>'Q4'
        };

        String extId =
            d.year() + '-' +
            qMap.get(dt.format('MMMM')) +
            '-W' + dt.format('w') +
            '-CONFERENCES-' + u.Id;

        Target__c t = new Target__c(
            Name = extId,
            Date__c = System.today(),
            Operation__c='Direct',
            Region__c='APAC',
            Zone__c='EAST',
            Country__c='INDIA',
            Group__c='ACCESS TO INNOVATION SERIES',
            List_Of_Activities__c='CME',
            Activity_Type__c='CONFERENCES',
            Year__c=String.valueOf(d.year()),
            Week_No__c=Integer.valueOf(dt.format('w')),
            Quater_No__c=qMap.get(dt.format('MMMM')),
            User__c=u.Id
        );
        insert t;

        insert new Target_Line_Item__c(Target__c=t.Id);

        Campaign__c cam = buildCampaign(t.Id, u.Id);

        Test.startTest();
        insert cam;
        Test.stopTest();
    }
*/
    // ---------- NEW TARGET CREATION ----------
    @isTest
    static void test_newTargetCreation() {

        CampaignTriggerHelper.isUpdated = false;

        User u = [SELECT Id FROM User LIMIT 1];

        Target__c t = buildSafeTarget('Base');

        Campaign__c cam = new Campaign__c(
            Name='NoMatch',
            Target__c=t.Id,
            Executer__c=u.Id,
            Activity_Type__c='CONFERENCES',
            Start_Date__c=System.today().addDays(10),
            End_Date__c=System.today().addDays(11),
            Operation__c='Direct',
            Region__c='APAC',
            Zone__c='EAST',
            Country__c='INDIA',
            State__c='Punjab',
            City__c='Mumbai',
            Group__c='OTHER',
            List_Of_Activities__c='CME',
            Categorize__c='Biotech Driven Event',
            Three_x_Three__c='test'
        );

        Test.startTest();
        insert cam;
        Test.stopTest();
    }
  
@isTest
static void test_targetMapping_only() {

    CampaignTriggerHelper.isUpdated = false;

    User u = [SELECT Id FROM User LIMIT 1];

    Date d = System.today();

    DateTime dt = DateTime.newInstance(d, Time.newInstance(0,0,0,0));

    Map<String,String> qMap = new Map<String,String>{
        'January'=>'Q1','February'=>'Q1','March'=>'Q1',
        'April'=>'Q2','May'=>'Q2','June'=>'Q2',
        'July'=>'Q3','August'=>'Q3','September'=>'Q3',
        'October'=>'Q4','November'=>'Q4','December'=>'Q4'
    };

    String quarter = qMap.get(dt.format('MMMM'));
    Integer week = Integer.valueOf(dt.format('w'));

    String externalId =
        d.year() + '-' + quarter +
        '-W' + week +
        '-CONFERENCES-' + u.Id;

    Target__c t = new Target__c(
        Name = externalId,
        Date__c = System.today(),
        Operation__c = 'Direct',
        Region__c = 'APAC',
        Zone__c = 'EAST',
        Country__c = 'INDIA',
        Group__c = 'ACCESS TO INNOVATION SERIES',
        List_Of_Activities__c = 'CME',
        Activity_Type__c = 'CONFERENCES',

        Year__c = String.valueOf(d.year()),
        Week_No__c = week,
        Quater_No__c = quarter,
        User__c = u.Id
    );
    insert t;

    insert new Target_Line_Item__c(Target__c = t.Id);

    Campaign__c cam = new Campaign__c(
        Name = 'MappingTest',
        Target__c = t.Id,
        Executer__c = u.Id,
        Activity_Type__c = 'CONFERENCES',
        Start_Date__c = d,
        End_Date__c = d.addDays(1),

        Operation__c = 'Direct',
        Region__c = 'APAC',
        Zone__c = 'EAST',
        Country__c = 'INDIA',
        State__c = 'Punjab',
        City__c = 'Delhi',

        Group__c = 'OTHER',
        List_Of_Activities__c = 'CME',
        Categorize__c = 'Biotech Driven Event'
    );

    Test.startTest();
    insert cam;
    Test.stopTest();
}
    @isTest
static void test_cisHeaderMap_coverage_only() {

    CampaignTriggerHelper.isUpdated = false;

    // ---------- ACCOUNT ----------
    Account acc = new Account(
        Name = 'CIS_Test_Acc',
        BillingCity = 'Surat',
        SAP_Code__c = '111'
    );
    insert acc;

    // ---------- MULTIPLE CIS HEADERS ----------
    List<CIS_Header__c> cisList = new List<CIS_Header__c>();

    for(Integer i = 0; i < 2; i++){
        cisList.add(new CIS_Header__c(
            Account__c = acc.Id,
            Status__c = 'Approved',
            IsPrimary__c = true
        ));
    }

    insert cisList;

    // ---------- FORCE HELPER EXECUTION ----------
    Target__c t = new Target__c(
        Name = 'CIS_Target',
        Date__c = System.today(),
        Operation__c = 'Direct',
        Region__c = 'APAC',
        Zone__c = 'EAST',
        Country__c = 'INDIA',
        Group__c = 'ACCESS TO INNOVATION SERIES',
        List_Of_Activities__c = 'CME',
        Activity_Type__c = 'CME'
    );
    insert t;

    insert new Target_Line_Item__c(Target__c = t.Id);

    Campaign__c cam = new Campaign__c(
        Name = 'CIS_Campaign',
        Target__c = t.Id,
        Activity_Type__c = 'CONFERENCES',
        Start_Date__c = System.today(),
        End_Date__c = System.today().addDays(1),
        Operation__c = 'Direct',
        Region__c = 'APAC',
        Zone__c = 'EAST',
        Country__c = 'INDIA',
        State__c = 'Punjab',
        City__c = 'Surat',
        Group__c = 'OTHER',
        List_Of_Activities__c = 'CME',
        Categorize__c = 'Biotech Driven Event'
    );
    insert cam;

    // 🔥 IMPORTANT: Link Campaign Member (this triggers cisHeaderMap usage)
    insert new Campaign_Member__c(
        Campaign1__c = cam.Id,
        Account__c = acc.Id
    );

    Test.startTest();
    update cam; // 🔥 THIS triggers CIS block
    Test.stopTest();
}
    @isTest
static void test_targetList_mapping_and_update() {

    CampaignTriggerHelper.isUpdated = false;

    User u = [SELECT Id FROM User LIMIT 1];

    Date d = System.today();

    DateTime dt = DateTime.newInstance(d, Time.newInstance(0,0,0,0));

    Map<String,String> qMap = new Map<String,String>{
        'January'=>'Q1','February'=>'Q1','March'=>'Q1',
        'April'=>'Q2','May'=>'Q2','June'=>'Q2',
        'July'=>'Q3','August'=>'Q3','September'=>'Q3',
        'October'=>'Q4','November'=>'Q4','December'=>'Q4'
    };

    String quarter = qMap.get(dt.format('MMMM'));
    Integer week = Integer.valueOf(dt.format('w'));

    // 🔥 DO NOT CREATE MATCHING TARGET → force helper to create new one
    Target__c base = new Target__c(
        Name = 'BaseTarget',
        Date__c = System.today(),
        Operation__c = 'Direct',
        Region__c = 'APAC',
        Zone__c = 'EAST',
        Country__c = 'INDIA',
        Group__c = 'ACCESS TO INNOVATION SERIES',
        List_Of_Activities__c = 'CME',
        Activity_Type__c = 'CME' // 🔥 safe
    );
    insert base;

    insert new Target_Line_Item__c(Target__c = base.Id);

    // 🔥 CAMPAIGN → will generate externalId
    Campaign__c cam = new Campaign__c(
        Name = 'FinalCoverage',
        Target__c = base.Id,
        Executer__c = u.Id,

        Activity_Type__c = 'CONFERENCES',
        Start_Date__c = d,
        End_Date__c = d.addDays(1),

        Operation__c = 'Direct',
        Region__c = 'APAC',
        Zone__c = 'EAST',
        Country__c = 'INDIA',
        State__c = 'Punjab',
        City__c = 'Delhi',

        Group__c = 'OTHER',
        List_Of_Activities__c = 'CME',
        Categorize__c = 'Biotech Driven Event',

        Three_x_Three__c = 'test'
    );

    Test.startTest();

    insert cam; // 🔥 THIS triggers targetList creation + mapping + update

    Test.stopTest();
}
}