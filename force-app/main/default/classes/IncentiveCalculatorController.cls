public with sharing class IncentiveCalculatorController {

    @AuraEnabled(cacheable=true)
    public static List<IncentiveDTO> getIncentiveData(Integer month, Integer year) {

        if (month == null || year == null) {
            return new List<IncentiveDTO>();
        }

        Date startDate = Date.newInstance(year, month, 1);
        Date endDate   = startDate.addMonths(1).addDays(-1);

        /* ---------------- ALL ACTIVE USERS ---------------- */
      /*  List<User> users = [
       * 
       * 
            SELECT Id, Name, Monthly_Salary__c
            FROM User
            WHERE IsActive =true /*and Country = 'INDIA' and  UserRole.name like 'Sales%'
            ];*/
        List<User> users=[SELECT Id,Name,Monthly_Salary__c FROM User WHERE IsActive=true AND (Id=:UserInfo.getUserId() OR ManagerId =:UserInfo.getUserId())];

        Set<Id> userIds = new Set<Id>();
        for (User u : users) userIds.add(u.Id);

        /* ---------------- TARGETS ---------------- */
        Map<Id, Sales_Target_Line__c> targetMap = new Map<Id, Sales_Target_Line__c>();
        for (Sales_Target_Line__c stl : [
            SELECT
                Sales_Target_Header__r.Sales_Person__c,
                Total_Sales_Target__c,
                Total_Marketing_lead_Generation_Target__c,
                Total_CTP_In_Clinic_Target__c
            FROM Sales_Target_Line__c
            WHERE Sales_Target_Header__r.Sales_Person__c IN :userIds
        ]) {
            targetMap.put(stl.Sales_Target_Header__r.Sales_Person__c, stl);
        }

        /* ---------------- SALES ACHIEVEMENT ---------------- */
        Map<Id, Decimal> salesMap = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Sales_Person__c uid, SUM(Amount__c) total
            FROM Opportunity__c
            WHERE Closed_Won_Date__c >= :startDate
              AND Closed_Won_Date__c <= :endDate
            GROUP BY Sales_Person__c
        ]) {
            salesMap.put((Id) ar.get('uid'), (Decimal) ar.get('total'));
        }

        /* ---------------- MARKETING ACHIEVEMENT ---------------- */
        Map<Id, Decimal> marketingMap = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Sales_Person__c uid, COUNT(Id) total
            FROM Lead__c
            WHERE CreatedDate >= :startDate
              AND CreatedDate <= :endDate
            GROUP BY Sales_Person__c
        ]) {
            marketingMap.put((Id) ar.get('uid'), (Decimal) ar.get('total'));
        }

        /* ---------------- CTP ACHIEVEMENT ---------------- */
        Set<String> callTypeSet = new Set<String>{'In Clinic Branding','CTP','Focus','Testimonial','SEP','CME','Webinar','RTM','MKTG/Conf/In Clinic / PD Planning','Welcome Kit','Counseling Kit','Patient Specific Standee','Cataract Surgery Counseling Kit','Milestone Celebration','Decode Program'};
        Map<Id, Decimal> ctpMap = new Map<Id, Decimal>();
        for(AggregateResult ar :[  SELECT OwnerId uid,COUNT(Id) total  FROM EVENT WHERE  CreatedDate >= :startDate  AND CreatedDate <= :endDate AND Call_Type__c='In Clinic Branding'  GROUP BY OwnerId ]){
             ctpMap.put((Id) ar.get('uid'), (Decimal) ar.get('total'));
        }
       /* for (AggregateResult ar : [
            SELECT Sales_Person__c uid, COUNT(Id) total
            FROM Lead__c
            WHERE CreatedDate >= :startDate
              AND CreatedDate <= :endDate
              AND (
                    Campaign__r.Target__r.Activity_Sub_Type__c = 'CTP'
                    OR Planned_Inclinic_Branding__c != null
                  )
            GROUP BY Sales_Person__c
        ]) {
            ctpMap.put((Id) ar.get('uid'), (Decimal) ar.get('total'));
        } */

        /* ---------------- INCENTIVE MASTER ---------------- */
        Map<String, Incentive_Target__c> incentiveMap = new Map<String, Incentive_Target__c>();
        for (Incentive_Target__c it : [
            SELECT Target_Parameter__c,
                   X60_79_99__c, X80_89_99__c, X90_99_99__c,
                   X100_109_99__c, X110_119_99__c, X120__c
            FROM Incentive_Target__c
        ]) {
            incentiveMap.put(it.Target_Parameter__c, it);
        }

        /* ---------------- FINAL RESULT ---------------- */
        List<IncentiveDTO> results = new List<IncentiveDTO>();

        for (User u : users) {

            Sales_Target_Line__c t = targetMap.get(u.Id);

            Decimal salary = u.Monthly_Salary__c != null ? u.Monthly_Salary__c : 0;

            Decimal sTarget = t != null && t.Total_Sales_Target__c != null ? t.Total_Sales_Target__c : 0;
            Decimal mTarget = t != null && t.Total_Marketing_lead_Generation_Target__c != null ? t.Total_Marketing_lead_Generation_Target__c : 0;
            Decimal cTarget = t != null && t.Total_CTP_In_Clinic_Target__c != null ? t.Total_CTP_In_Clinic_Target__c : 0;

            Decimal sAch = salesMap.containsKey(u.Id) ? salesMap.get(u.Id) : 0;
            Decimal mAch = marketingMap.containsKey(u.Id) ? marketingMap.get(u.Id) : 0;
            Decimal cAch = ctpMap.containsKey(u.Id) ? ctpMap.get(u.Id) : 0;

            Decimal sPct = sTarget == 0 ? 0 : (sAch / sTarget) * 100;
            Decimal mPct = mTarget == 0 ? 0 : (mAch / mTarget) * 100;
            Decimal cPct = cTarget == 0 ? 0 : (cAch / cTarget) * 100;

            Decimal sElig = getEligibility(incentiveMap.get('Sales Revenue Target'), sPct);
            Decimal mElig = getEligibility(incentiveMap.get('Marketing Lead Generation'), mPct);
            Decimal cElig = getEligibility(incentiveMap.get('CTP & In-clinic Branding'), cPct);

            Decimal totalElig = sElig + mElig + cElig;

            IncentiveDTO dto = new IncentiveDTO();
            dto.employeeName = u.Name;
            dto.monthYear = month + '-' + year;

            dto.salesTarget = sTarget;
            dto.salesAchievement = sAch;
            dto.salesPct = sPct;
            dto.salesEligibility = sElig;

            dto.marketingTarget = mTarget;
            dto.marketingAchievement = mAch;
            dto.marketingPct = mPct;
            dto.marketingEligibility = mElig;

            dto.ctpTarget = cTarget;
            dto.ctpAchievement = cAch;
            dto.ctpPct = cPct;
            dto.ctpEligibility = cElig;

            dto.totalEligibility = totalElig;
            dto.monthlySalary = salary;
            dto.monthlyIncentiveAmount = salary * (totalElig / 100);

            results.add(dto);
        }

        return results;
    }

    /* ---------------- ELIGIBILITY ---------------- */
    private static Decimal getEligibility(Incentive_Target__c it, Decimal pct) {
        if (it == null) return 0;
        if (pct >= 120) return it.X120__c != null ? it.X120__c : 0;
        if (pct >= 110) return it.X110_119_99__c != null ? it.X110_119_99__c : 0;
        if (pct >= 100) return it.X100_109_99__c != null ? it.X100_109_99__c : 0;
        if (pct >= 90)  return it.X90_99_99__c != null ? it.X90_99_99__c : 0;
        if (pct >= 80)  return it.X80_89_99__c != null ? it.X80_89_99__c : 0;
        if (pct >= 60)  return it.X60_79_99__c != null ? it.X60_79_99__c : 0;
        return 0;
    }

    /* ---------------- DTO ---------------- */
    public class IncentiveDTO {
        @AuraEnabled public String employeeName;
        @AuraEnabled public String monthYear;

        @AuraEnabled public Decimal salesTarget;
        @AuraEnabled public Decimal salesAchievement;
        @AuraEnabled public Decimal salesPct;
        @AuraEnabled public Decimal salesEligibility;

        @AuraEnabled public Decimal marketingTarget;
        @AuraEnabled public Decimal marketingAchievement;
        @AuraEnabled public Decimal marketingPct;
        @AuraEnabled public Decimal marketingEligibility;

        @AuraEnabled public Decimal ctpTarget;
        @AuraEnabled public Decimal ctpAchievement;
        @AuraEnabled public Decimal ctpPct;
        @AuraEnabled public Decimal ctpEligibility;

        @AuraEnabled public Decimal totalEligibility;
        @AuraEnabled public Decimal monthlySalary;
        @AuraEnabled public Decimal monthlyIncentiveAmount;
    }
}