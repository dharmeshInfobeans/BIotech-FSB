public class CampaignWrapper {
    public String state { get; set; }
    public Boolean started { get; set; }
    public Boolean completed { get; set; }
    public String startQuarter { get; set; }
    public String campaignEndQuarterNo { get; set; }
    public String product2Name { get; set; }
    public String product4Name { get; set; }
    public String city { get; set; }
    public String startMonth { get; set; }
    public String currencyIsoCode { get; set; }
    public String name { get; set; }
    public String country { get; set; }
    public String url { get; set; }
    public Boolean test { get; set; }
    public Boolean ended { get; set; }
    public String product3Name { get; set; }
    public String focusProduct { get; set; }
    public String product1Name { get; set; }
    public String zone { get; set; }
    public String operation { get; set; }
    public String status { get; set; }
    public String description { get; set; }
    public String listOfActivities { get; set; }
    public String campaignStage { get; set; }
    public String activityType { get; set; }
    public String region { get; set; }
    public String cmpgn_group { get; set; }
    public String targetId { get; set; }
    public Decimal newCustomer { get; set; }
    public Decimal startWeek { get; set; }
    public Decimal totalPresentCampaignMembers { get; set; }
    public Decimal totalCampaignMembers { get; set; }
    public Decimal attendeesAttended { get; set; }
    public Decimal existingCustomer { get; set; }
    public Decimal leadsGenerated { get; set; }
    public Decimal plannedAttendees { get; set; }
    public String executerId { get; set; }
    public Decimal totalActualExpense { get; set; }
    public Decimal product4Opportunity { get; set; }
    public Decimal product3Opportunity { get; set; }
    public Decimal product2Opportunity { get; set; }
    public Decimal product1Opportunity { get; set; }
    public Decimal customerProduct4Opportunity { get; set; }
    public Decimal customerProduct3Opportunity { get; set; }
    public Decimal customerProduct1Opportunity { get; set; }
    public Decimal customerProduct2Opportunity { get; set; }
    public Decimal costPerAttendee { get; set; }
    public Decimal averageExpensePerAttendeePlanned { get; set; }
    public Decimal attendeesInvited { get; set; }
    public Decimal attendedProduct4Opportunity { get; set; }
    public Decimal attendedProduct3Opportunity { get; set; }
    public Decimal attendedProduct2Opportunity { get; set; }
    public Decimal attendedProduct1Opportunity { get; set; }
    
    // Constructor
    public CampaignWrapper() {
        // Initialize default values if needed
    }
    
    // Method to populate the wrapper with values from a Campaign object (sObject)
    public CampaignWrapper(Campaign__c campaign) {
        this.state = campaign.State__c;
        this.started = campaign.Started__c;
        this.completed = campaign.Completed__c;
        this.startQuarter = campaign.Start_Quarter__c;
        this.campaignEndQuarterNo = campaign.Campaign_End_date_Quarter_No__c;
        this.product2Name = campaign.Product_2_Name__c;
        this.product4Name = campaign.Product_4_Name__c;
        this.city = campaign.City__c;
        this.startMonth = campaign.Start_Month__c;
        this.currencyIsoCode = campaign.CurrencyIsoCode;
        this.name = campaign.Name;
        this.country = campaign.Country__c;
        this.url = campaign.Url__c;
        this.test = campaign.test__c;
        this.ended = campaign.Ended__c;
        this.product3Name = campaign.Product_3_Name__c;
        this.focusProduct = campaign.Focus_Product__c;
        this.product1Name = campaign.Product_1_Name__c;
        this.zone = campaign.Zone__c;
        this.operation = campaign.Operation__c;
        this.status = campaign.Status__c;
        this.description = campaign.Description__c;
        this.listOfActivities = campaign.List_Of_Activities__c;
        this.campaignStage = campaign.Campaign_stage__c;
        this.activityType = campaign.Activity_Type__c;
        this.region = campaign.Region__c;
        this.cmpgn_group = campaign.Group__c;
        this.targetId = campaign.Target__c;
        this.newCustomer = campaign.New_Customer__c;
        this.startWeek = campaign.Start_Week__c;
        this.totalPresentCampaignMembers = campaign.Total_Present_Camaign_Member__c;
        this.totalCampaignMembers = campaign.Total_Camaign_Member__c;
        this.attendeesAttended = campaign.Attendes_Attended__c;
        this.existingCustomer = campaign.Existing_customer__c;
        this.leadsGenerated = campaign.Lead_Generated__c;
        this.plannedAttendees = campaign.Planned_Attendees__c;
        this.executerId = campaign.Executer__c;
        this.totalActualExpense = campaign.Total_Actual_Expense__c;
        this.product4Opportunity = campaign.Product_4_Opportunity__c;
        this.product3Opportunity = campaign.Product_3_Opportunity__c;
        this.product2Opportunity = campaign.Product_2_Opportunity__c;
        this.product1Opportunity = campaign.Product_1_Opportunity__c;
        this.customerProduct4Opportunity = campaign.Customer_Product_4_Opportunity__c;
        this.customerProduct3Opportunity = campaign.Customer_Product_3_Opportunity__c;
        this.customerProduct1Opportunity = campaign.Customer_Product_1_Opportunity__c;
        this.customerProduct2Opportunity = campaign.Customer_Porduct_2_Opportunity__c;
        this.costPerAttendee = campaign.Cost_of_Per_Attendee__c;
        this.averageExpensePerAttendeePlanned = campaign.Avergae_Expense_Per_Attendee_Planned__c;
        this.attendeesInvited = campaign.Attendes_Invited__c;
        this.attendedProduct4Opportunity = campaign.Attended_Product_4_Opportunity__c;
        this.attendedProduct3Opportunity = campaign.Attended_Product_3_Opportunity__c;
        this.attendedProduct2Opportunity = campaign.Attended_Product_2_Opportunity__c;
        this.attendedProduct1Opportunity = campaign.Attended_Product_1_Opportunity__c;
    }
    
    public static CampaignWrapper parse(String json){
        return (CampaignWrapper) System.JSON.deserialize(json, CampaignWrapper.class);
    }
    
}