global class QuarterlyLearnandGrowthTraining {
    
    global Period last2FiscQaurterStartEndDt{get;set;}
    
    global QuarterlyLearnandGrowthTraining(){
        last2FiscQaurterStartEndDt = [Select Id,StartDate,EndDate,FiscalYearSettings.StartDate,FiscalYearSettings.Enddate from period where type = 'QUARTER' AND StartDate = LAST_QUARTER];
        system.debug('***last2FiscQaurterStartEndDt***'+last2FiscQaurterStartEndDt);
    }
    
    public AggregateResult[] QuarterlyLearnandGrowth(KRA_Configuration__c KRAConfig, string rolename, List<string> Div){
        Date startDate = date.newInstance(last2FiscQaurterStartEndDt.StartDate.year(),last2FiscQaurterStartEndDt.StartDate.month(),last2FiscQaurterStartEndDt.StartDate.day());
        system.debug('***startDate***'+startDate);
        Date endDate = date.newInstance(last2FiscQaurterStartEndDt.EndDate.year(),last2FiscQaurterStartEndDt.EndDate.month(),last2FiscQaurterStartEndDt.EndDate.day());
        system.debug('***EndDate***'+EndDate);
        
        string queryLearnandGrowthTrainingDivision ='';
        if(Div.size() > 0){
            integer cnt =1;
            system.debug('***Div.size()***'+Div.size());
            for(string divs : Div){
                queryLearnandGrowthTrainingDivision += 'Sales_Employee__r.DivisionT__C like \''+divs+'%\'';
                if(cnt < Div.size()){
                    queryLearnandGrowthTrainingDivision +=' OR ';
                } 
                system.debug('***Div***'+Div);
                cnt++;
            }
        }
        system.debug('***queryLearnandGrowthTrainingDivision***'+queryLearnandGrowthTrainingDivision);
        string meetingtype = 'Learn & Growth Training';
        string queryLearnandGrowthTrainingSelect = 'AVG(Achieve_Percentage__c)Achievepercent ';
        string queryLearnandGrowthTrainingWhere;
        string queryLearnandGrowthTrainingGrpBy;        
        system.debug('***KRAConfig.Role__c***'+KRAConfig.Role__c);
        
        if(rolename == 'RSM'){
            queryLearnandGrowthTrainingSelect += ',Sales_Employee__c,State__c ';
            queryLearnandGrowthTrainingWhere = ' Sales_Employee__r.UserRole.Name LIKE \''+rolename+'%\' AND' +' Start_Date__c >=: startDate '+
                'AND End_Date__c <=: endDate ' + 'AND Meeting_Type__c =: meetingtype ';
            queryLearnandGrowthTrainingGrpBy ='Sales_Employee__c,State__c ';
        } else{
            queryLearnandGrowthTrainingSelect += ',Sales_Employee__c,State__c ';
            queryLearnandGrowthTrainingWhere = ' Sales_Employee__r.UserRole.Name LIKE \''+rolename+'%\' AND (' + queryLearnandGrowthTrainingDivision +') AND Start_Date__c >=: startDate '+
                'AND End_Date__c <=: endDate ' + 'AND Meeting_Type__c =: meetingtype ';
            queryLearnandGrowthTrainingGrpBy ='Sales_Employee__c,State__c ';
        }
        String queryLearnandGrowthTraining = 'Select ' + queryLearnandGrowthTrainingSelect + ' from Visit_Report__c where '+queryLearnandGrowthTrainingWhere + ' Group By '+ queryLearnandGrowthTrainingGrpBy;
        system.debug('**queryLearnandGrowthTraining***'+queryLearnandGrowthTraining);
        AggregateResult[] LearnandGrowthTrainingAggreRes = database.query(queryLearnandGrowthTraining);
        system.debug('***LearnandGrowthTrainingAggreRes***'+LearnandGrowthTrainingAggreRes);
        return LearnandGrowthTrainingAggreRes;
    }
    
    public void calculateLearnandGrowthTraining(KRA_Configuration__c KRAConfig, string rolename, List<string> Div) {
        
        List<KRA_Calculation__c> lstKRACal= new List<KRA_Calculation__c>();
        List<KRA_Parameter_Detail__c> KRAParam = KRAConfig.KRA_Details__r;
        KRA_Calculation__c kracalc = new KRA_Calculation__c();
        AggregateResult[] LearnandGrowthTrainingars = QuarterlyLearnandGrowth(KRAConfig,rolename,Div);
        for(AggregateResult LearnandGrowthTraining :LearnandGrowthTrainingars){
            kracalc = new KRA_Calculation__c();
            kracalc.KRA_Configuration__c = KRAConfig.Id;
            kracalc.Start_Date__c = last2FiscQaurterStartEndDt.StartDate;
            kracalc.End_Date__c = last2FiscQaurterStartEndDt.EndDate;
            kracalc.Region__c = (ID) LearnandGrowthTraining.get('State__c');
            kracalc.OwnerId = (ID) LearnandGrowthTraining.get('Sales_Employee__c');
            kracalc.Percentage__c = (Decimal) LearnandGrowthTraining.get('Achievepercent');
            for(KRA_Parameter_Detail__c kra :  KRAParam) {
                if((kracalc.Percentage__c > 100 && kra.Achievement_from__c == 100) 
                   || (kracalc.Percentage__c >= kra.Achievement_from__c && kracalc.Percentage__c <= kra.Achievement_to__c)){
                       kracalc.Points__c = kra.Points__c;
                       break;
                   } 
            }
            lstKRACal.add(kracalc); 
        }
        insert lstKRACal;
    }
}