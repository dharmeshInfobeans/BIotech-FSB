/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : CampaignNameHandler
 * Author          : <YourName>
 * Created Date    : Sep 30, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Sep 30, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Sep 30, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public class CampaignNameHandler {

	 public static void updateCampaignName(List<Campaign__c> campaignList){
        // Date todayDate = Date.today();
        // String currentYear = String.valueOf(todayDate.year());
        // String currentQuarter = 'Q' + String.valueOf(((todayDate.month() - 1) / 3) + 1);
        for(Campaign__c record:campaignList){
             Datetime baseDate = record.CreatedDate != null ? record.CreatedDate : Datetime.now();

        String currentYear    = String.valueOf(baseDate.year());
        String currentQuarter = 'Q' + String.valueOf(((baseDate.month() - 1) / 3) + 1);
            String activities = record.List_Of_Activities__c != null ? record.List_Of_Activities__c : '';
            String zone       = record.Zone__c != null ? record.Zone__c : '';
            String city       = record.City__c != null ? record.City__c : '';
            String country    = record.Country__c != null ? record.Country__c : '';
            
            // Construct the final name
            record.Name = currentYear + ' - ' + 
                          currentQuarter + ' - ' + 
                          activities + ' - ' + 
                          zone + ' - ' + 
                          city + ' - ' + 
                          country;
        }
        }
}