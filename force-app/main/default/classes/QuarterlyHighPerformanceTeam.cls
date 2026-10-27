global class QuarterlyHighPerformanceTeam {
    
    global Period last2FiscQaurterStartEndDt{get;set;}
    
    global QuarterlyHighPerformanceTeam(){
        last2FiscQaurterStartEndDt = [Select Id,StartDate,EndDate,FiscalYearSettings.StartDate,FiscalYearSettings.Enddate from period where type = 'QUARTER' AND StartDate = LAST_QUARTER];
        system.debug('***last2FiscQaurterStartEndDt***'+last2FiscQaurterStartEndDt);
    }
    
    public List<Visit_Report__c> QuarterlyHighPerformance(KRA_Configuration__c KRAConfig, string rolename, List<string> Div){
        Date startDate = date.newInstance(last2FiscQaurterStartEndDt.StartDate.year(),last2FiscQaurterStartEndDt.StartDate.month(),last2FiscQaurterStartEndDt.StartDate.day());
        system.debug('***startDate***'+startDate);
        Date endDate = date.newInstance(last2FiscQaurterStartEndDt.EndDate.year(),last2FiscQaurterStartEndDt.EndDate.month(),last2FiscQaurterStartEndDt.EndDate.day());
        system.debug('***EndDate***'+EndDate);
        
        string queryHighPerformanceTeamDivision ='';
        if(Div.size() > 0){
            integer cnt =1;
            system.debug('***Div.size()***'+Div.size());
            for(string divs : Div){
                queryHighPerformanceTeamDivision += 'Sales_Employee__r.DivisionT__C like \''+divs+'%\'';
                if(cnt < Div.size()){
                    queryHighPerformanceTeamDivision +=' OR ';
                } 
                system.debug('***Div***'+Div);
                cnt++;
            }
        }
        system.debug('***queryHighPerformanceTeamDivision***'+queryHighPerformanceTeamDivision);
        string meetingtype = 'High Performance Team';
        string queryHighPerformanceTeamSelect;
        string queryHighPerformanceTeamWhere;
        system.debug('***KRAConfig.Role__c***'+KRAConfig.Role__c);
        
        if(rolename == 'RSM'){
            queryHighPerformanceTeamSelect = 'Sales_Employee__c,State__c,Team_Performance__c ';
            queryHighPerformanceTeamWhere = ' Sales_Employee__r.UserRole.Name LIKE \''+rolename+'%\' AND' +' Start_Date__c >=: startDate '+
                'AND End_Date__c <=: endDate ' + 'AND Meeting_Type__c =: meetingtype ';
        } else{
            queryHighPerformanceTeamSelect = 'Sales_Employee__c,State__c,Team_Performance__c ';
            queryHighPerformanceTeamWhere = ' Sales_Employee__r.UserRole.Name LIKE \''+rolename+'%\' AND (' + queryHighPerformanceTeamDivision +') AND Start_Date__c >=: startDate '+
                'AND End_Date__c <=: endDate ' + 'AND Meeting_Type__c =: meetingtype ';
        }
        String queryHighPerformanceTeam = 'Select ' + queryHighPerformanceTeamSelect + ' from Visit_Report__c where '+queryHighPerformanceTeamWhere;
        system.debug('**queryHighPerformanceTeam***'+queryHighPerformanceTeam);
        List<Visit_Report__c> HighPerformanceTeamAggreRes = database.query(queryHighPerformanceTeam);
        system.debug('***HighPerformanceTeamAggreRes***'+HighPerformanceTeamAggreRes);
        return HighPerformanceTeamAggreRes;
    }
    
    public void calculateHighPerformanceTeam(KRA_Configuration__c KRAConfig, string rolename, List<string> Div) {
        
        List<KRA_Calculation__c> lstKRACal= new List<KRA_Calculation__c>();
        KRA_Calculation__c kracalc = new KRA_Calculation__c();
        List<Visit_Report__c> HighPerformanceTeamars = QuarterlyHighPerformance(KRAConfig,rolename,Div);
        
        for(Visit_Report__c HighPerformanceTeam : HighPerformanceTeamars){
            kracalc = new KRA_Calculation__c();
            kracalc.KRA_Configuration__c = KRAConfig.Id;
            kracalc.Start_Date__c = last2FiscQaurterStartEndDt.StartDate;
            kracalc.End_Date__c = last2FiscQaurterStartEndDt.EndDate;
            kracalc.Region__c = HighPerformanceTeam.State__c;
            kracalc.OwnerId = HighPerformanceTeam.Sales_Employee__c;
            kracalc.Points__c = Decimal.valueOf(HighPerformanceTeam.Team_Performance__c);
            lstKRACal.add(kracalc);
        }
        insert lstKRACal; 
    }
}