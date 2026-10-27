public class KRACalculationsActiveCustomers {
   
    public static void calculateActiveCustomerKRA() {
        
        Map<String,List<User>> userIdUserLstMap = UserRolewiseGrouping_Class.createUserwiseGrouping('Domestic');
        system.debug('userIdUserLstMap in constructor***'+userIdUserLstMap);
        List<String> roleNamelst = new List<String>();
        for(String roleNm : userIdUserLstMap.keySet()) {
            roleNamelst.add(roleNm); 
        }
        roleNamelst.sort();
        system.debug('sorted ist'+roleNamelst);
        
        list<KRA_Configuration__c> lstKRAConfiguration = [Select Id,Quadrant__c,Role__c, Parameter__c,Financial_Year__c,Financial_Year__r.Start_Date__c,
                                                          Financial_Year__r.End_Date__c,Product_1__c,Product_2__c,Division__c,DivisionT__c, 
                                                          (select id,Points__c,KRA_Configuration__c,Achievement_to__c,
                                                           Achievement_from__c,Achievement_From_Number__c,
                                                           Achievement_to_Number__c from KRA_Details__r) 
                                                          from KRA_Configuration__c where Parameter__c='No of Active Customers'];
        
        if(!roleNamelst.isEmpty()){
            for(String roleName : roleNamelst){
                if(userIdUserLstMap.containsKey(roleName)){
                    calculateKRA(userIdUserLstMap.get(roleName),roleName, lstKRAConfiguration);
                } 
            }
        } 
    }  
    
    
    
    public static void calculateKRA(List<User> lstUser, String roleNm, list<KRA_Configuration__c> lstKRAConfiguration){
        Period lastFiscQaurterStartEndDt = [Select Id,StartDate,EndDate,FiscalYearSettings.StartDate,FiscalYearSettings.Enddate from period where type = 'QUARTER' AND /*StartDate = LAST_N_FISCAL_QUARTERS:2 AND*/ 
                                             StartDate = LAST_QUARTER];
        Date startDate = date.newInstance(lastFiscQaurterStartEndDt.StartDate.year(),lastFiscQaurterStartEndDt.StartDate.month(),lastFiscQaurterStartEndDt.StartDate.day());
        system.debug('***startDate***'+startDate);
        Date endDate = date.newInstance(lastFiscQaurterStartEndDt.EndDate.year(),lastFiscQaurterStartEndDt.EndDate.month(),lastFiscQaurterStartEndDt.EndDate.day());
        system.debug('***EndDate***'+EndDate);
        
        set<Id> userIds = new set<Id>();
        for(User usr : lstUser){
            userIds.add(usr.Id);
        }
        
        map<Id, User> mapUser = new map<Id, User>([Select Id , divisionT__c from User where id=: userIds]);
        
        //Get targets
        string Calltype = 'Active Customer';
        string queryTargetSelect = 'SUM(Target__c)target , Sales_Employee__c, Sales_Employee__r.UserRole.Name roleName ';
        string queryTargetWhere = ' Sales_Employee__c=:userIds AND Start_Date__c >=: startDate AND End_Date__c <=: endDate AND Target_Type__c =: Calltype ';
        string queryTargetGrpBy ='Sales_Employee__c,Sales_Employee__r.UserRole.Name ';
        String queryTarget = 'Select ' + queryTargetSelect + ' from KRA_Target__c where '+queryTargetWhere + ' Group By '+ queryTargetGrpBy;
        system.debug('**queryTarget***'+queryTarget);
        AggregateResult[] TargetAggreRes = database.query(queryTarget);
        
        
        //Get Actuals
        string Status = 'Active';
        string queryActivitySelect = 'Count(Id)cnt, Sales_Employee__c owner ';
        string queryActivityWhere = ' Start_Date__c >=: startDate AND End_Date__c <=: endDate' +
            ' AND Activation_Type__c = \'KRA\' AND Status__c =: Status';
        string queryActivityGrpBy = 'Sales_Employee__c';
        
        String queryActivity = 'Select ' + queryActivitySelect + ' from Account_Activation_History__c where Sales_Employee__c =: userIds and ' 
            + queryActivityWhere + ' Group By '+ queryActivityGrpBy;
        
        //Get Self Event Opens
        AggregateResult[] selfActivityAggr = database.query(queryActivity);
        system.debug('***selfActivityAggr***'+selfActivityAggr);
        system.debug('**roleNm***'+roleNm);
		
        map<string, AggregateResult> mapUser_Aggr = new map<string, AggregateResult>();
        for(AggregateResult aggrRes : selfActivityAggr){
            mapUser_Aggr.put((string)aggrRes.get('owner'), aggrRes);
        }
        
        //Get Team Actuals
        queryActivitySelect = 'Count(Id) cnt, Sales_Employee__r.managerId owner ';
        queryActivityGrpBy = 'Sales_Employee__r.managerId';
        queryActivity = 'Select ' + queryActivitySelect + ' from Account_Activation_History__c where Sales_Employee__r.managerId =: userIds and ' 
            + queryActivityWhere + ' Group By '+ queryActivityGrpBy;
        system.debug('**queryActivity***'+queryActivity);
        AggregateResult[] teamActivityAggr = database.query(queryActivity);
        system.debug('***teamActivityAggr***'+teamActivityAggr);
        
        //map<string, AggregateResult> mapUser_TeamAggr = new map<string, AggregateResult>();
        //for(AggregateResult aggrRes : teamActivityAggr){
        //    mapUser_TeamAggr.put((string)aggrRes.get('owner'), aggrRes);
        //}
        
        //Get Team Count
        queryActivitySelect = 'Count(Id) cnt, managerId mngrId';
        queryActivityGrpBy = 'managerId';
        queryActivityWhere = 'isActive=true';
        queryActivity = 'Select ' + queryActivitySelect + ' from User where managerId =: userIds and ' 
            + queryActivityWhere + ' Group By '+ queryActivityGrpBy;
        system.debug('**queryActivity***'+queryActivity);
        AggregateResult[] teamCountAggr = database.query(queryActivity);
        system.debug('***teamCountAggr***'+teamCountAggr);
        
        //map<string, AggregateResult> mapUser_TeamCountAggr = new map<string, AggregateResult>();
        //for(AggregateResult aggrRes : teamCountAggr){
        //    mapUser_TeamCountAggr.put((string)aggrRes.get('mngrId'), aggrRes);
       // }
        
		        
        //Get team KRA calculations
        String queryKRACalculation = 'Select SUM(Total_Actuals__c)cnt, Sales_Employee__r.managerId owner from KRA_Calculation__c where Sales_Employee__r.managerId=:userIds group By Sales_Employee__r.managerId';
        AggregateResult[] kraCalAggr = database.query(queryKRACalculation);
        
        //map<string, AggregateResult> mapUser_TeamKRACalAggr = new map<string, AggregateResult>();
        //for(AggregateResult aggrRes : teamCountAggr){
        //    mapUser_TeamKRACalAggr.put((string)aggrRes.get('owner'), aggrRes);
       //}
        
        
        map<string, integer> mapUser_SelfActual = new map<string, integer>();
        map<string, integer> mapUser_TeamActual = new map<string, integer>();
        string ownerId, uniqueKey, salesEmp, roleName,division; 
        string parameter = 'Active Customers';
        list<KRA_Calculation__c> lstKRACal = new list<KRA_Calculation__c>();
       
        KRA_Calculation__c kraCalc = new KRA_Calculation__c();
        
        for(user usrRec : lstUser){
            kraCalc = new KRA_Calculation__c();
            kraCalc.Start_Date__c = lastFiscQaurterStartEndDt.StartDate;
            kraCalc.End_Date__c = lastFiscQaurterStartEndDt.EndDate;
            if(usrRec.IsActive){
                kraCalc.OwnerId = usrRec.Id;    
            }else{
                //kraCalc.OwnerId = usrRec.Id;
            }
            
            salesEmp = usrRec.id;
            roleName = roleNm;
            division = usrRec.divisionT__c;
            kraCalc.Target__c = 0;
            kraCalc.Sales_Employee__c = salesEmp;
            uniqueKey = (string) salesEmp+'_'+(Date) startDate+'_'+(string) parameter;
            kraCalc.UniqueKey__c = uniqueKey;
            kraCalc.Self_Actual__c = 0;
            kraCalc.Team_Actual__c = 0;
            kraCalc.Team_count__c = 1;
            
            for (AggregateResult selfAr : selfActivityAggr)  {
                if((string)selfAr.get('owner') == salesEmp) {
                    kraCalc.Self_Actual__c = (decimal) selfAr.get('cnt');
                    break;
                }
                System.debug('cnt:-' + selfAr.get('cnt'));
            }
            
            for (AggregateResult kraAggr : kraCalAggr)  {
                if((string) kraAggr.get('owner') == salesEmp){
                    kraCalc.Team_Actual__c = (decimal) kraAggr.get('cnt');
                    break;
                }
            }
            
            for (AggregateResult kraAggr : teamCountAggr)  {
                if((string) kraAggr.get('mngrId') == salesEmp){
                    kraCalc.Team_count__c += (decimal) kraAggr.get('cnt');
                    break;
                }
            }
            
            //Find allocated KRA configuration
            for(KRA_Configuration__c kraConfig : lstKRAConfiguration){
                for(string role : kraConfig.Role__c.split(';')){
                    if(roleName.contains(role) && (division.contains(kraConfig.DivisionT__c) || kraConfig.DivisionT__c.contains(division))) {
                        kracalc.KRA_Configuration__c = KRAConfig.Id;
                        system.debug('***kracalc***'+kracalc);
                        decimal totalActual = kracalc.Team_Actual__c + kracalc.Self_Actual__c;
                        //kracalc.Total_Actual__c = totalActual;
                        system.debug('***role***'+role);
                        if(role != 'RSM'){
                            system.debug('***Inside if***');
                            kracalc.Actual__c = kracalc.Self_Actual__c;  
                        }else{
                            system.debug('***Inside else***');
                            kracalc.Actual__c = totalActual; 
                        }
                        
                        kracalc.Points__c = 0;
                        //kracalc.Percentage__c = (kracalc.Actual__c / kracalc.Team_count__c) * 100;
                        decimal kraNumber = kracalc.Actual__c / kracalc.Team_count__c;
                        for(KRA_Parameter_Detail__c kra :  kraConfig.KRA_Details__r) {
                            //if((kracalc.Percentage__c > 100 && kra.Achievement_from__c == 100) 
                            //|| (kracalc.Percentage__c >= kra.Achievement_from__c && kracalc.Percentage__c <= kra.Achievement_to__c)){
                            system.debug('**kraNumber**'+kraNumber);
                            system.debug('**kra.Achievement_From_Number__c**'+kra.Achievement_From_Number__c);
                            system.debug('**kra.Achievement_To_Number__c**'+kra.Achievement_To_Number__c);
                            if( kraNumber >= kra.Achievement_From_Number__c && kracalc.Percentage__c <= kra.Achievement_To_Number__c ||
                              (kraNumber >= kra.Achievement_From_Number__c && kraNumber >= kra.Achievement_to_Number__c)) {
                                kracalc.Points__c = kra.Points__c;
                                break;
                            } 
                        }
                        break;
                    }
                }
            }            
            lstKRACal.add(kracalc);             
        }
        
      /*  for(AggregateResult Target : TargetAggreRes){
             kraCalc = new KRA_Calculation__c();
            //kracalc.KRA_Configuration__c = KRAConfig.Id;
            kraCalc.Start_Date__c = lastFiscQaurterStartEndDt.StartDate;
            kraCalc.End_Date__c = lastFiscQaurterStartEndDt.EndDate;
            kraCalc.OwnerId = (ID) Target.get('Sales_Employee__c');
            salesEmp = (Id) Target.get('Sales_Employee__c');
            roleName = (string) Target.get('roleName');
            division = mapUser.get(salesEmp).divisionT__c;
            
            kraCalc.Target__c = (Decimal) Target.get('target');
            kraCalc.Sales_Employee__c = (ID) Target.get('Sales_Employee__c');
            uniqueKey = (string) salesEmp+'_'+(Date) startDate+'_'+(string) parameter;
            kraCalc.UniqueKey__c = uniqueKey;
            kraCalc.Self_Actual__c = 0;
            kraCalc.Team_Actual__c = 0;
            
            for (AggregateResult selfAr : selfActivityAggr)  {
                if((string)selfAr.get('owner') == salesEmp) {
                    kraCalc.Self_Actual__c = (decimal) selfAr.get('cnt');
                    break;
                }
                System.debug('cnt:-' + selfAr.get('cnt'));
            }
            
            for (AggregateResult teamAr : teamActivityAggr)  {
                if((string)teamAr.get('owner') == salesEmp){
                    //kraCalc.Team_Actual__c = (decimal) teamAr.get('cnt');
                    break;
                }
            }
            
            for (AggregateResult kraAggr : kraCalAggr)  {
                if((string) kraAggr.get('owner') == salesEmp){
                    kraCalc.Team_Actual__c = (decimal) kraAggr.get('cnt');
                    break;
                }
            }
            
            //Find allocated KRA configuration
            for(KRA_Configuration__c kraConfig : lstKRAConfiguration){
                for(string role : kraConfig.Role__c.split(';')){
                    if(roleName.contains(role) && (division.contains(kraConfig.DivisionT__c) || kraConfig.DivisionT__c.contains(division))) {
                        kracalc.KRA_Configuration__c = KRAConfig.Id;
                        decimal totalActual = kracalc.Team_Actual__c + kracalc.Self_Actual__c;
                        //kracalc.Total_Actual__c = totalActual;
                        system.debug('***role***'+role);
                        if(role != 'RSM'){
                            system.debug('***Inside if***');
                            kracalc.Actual__c = kracalc.Self_Actual__c;  
                        }else{
                            system.debug('***Inside else***');
                            kracalc.Actual__c = totalActual; 
                        }
                        kracalc.Percentage__c = (kracalc.Actual__c / kracalc.Target__c) * 100;
                        for(KRA_Parameter_Detail__c kra :  kraConfig.KRA_Details__r) {
                            //if((kracalc.Percentage__c > 100 && kra.Achievement_from__c == 100) 
                               //|| (kracalc.Percentage__c >= kra.Achievement_from__c && kracalc.Percentage__c <= kra.Achievement_to__c)){
                            if(kracalc.Percentage__c >= kra.Achievement_from__c && kracalc.Percentage__c <= kra.Achievement_to__c) {
                                   kracalc.Points__c = kra.Points__c;
                                   break;
                               } 
                        }
                        break;
                    }
                }
            }            
            lstKRACal.add(kracalc); 
        } */
        
        upsert lstKRACal UniqueKey__c;
        system.debug('***lstKRACal ***'+lstKRACal);
    }

}