public class CampaignMemberTriggerHelper {
   public static void updateLeadData(List<Campaign_Member__c> newList) {
        if(newList.size()>0) {
            Map<String,List<Campaign_Member__c>> camMemberMap=new Map<String,List<Campaign_Member__c>>();
            Set<string> campaignId=new Set<string>();
            List<Lead__c> leadUpdateList=new List<Lead__c>();
            
            for(Campaign_Member__c cmpMem:newList) {
                if(cmpMem.Campaign1__c!=null) {
                    campaignId.add(cmpMem.Campaign1__c); 
                }
                
            }  
            
            
            
            if(campaignId.size()>0) {
                for(Campaign__c cam:[SELECT Id,(SELECT Id,Lead1__c,Campaign1__r.Campaign_stage__c from Campaign_Members__r where Lead1__c!=null AND Lead1__r.lead_stage__c !='Won' AND Lead1__r.lead_stage__c !='Unqualified' AND Lead1__r.lead_stage__c !='Lost' AND Account__c=:null AND Lead1__r.lead_closed__c != true) from Campaign__c  where Id in:campaignId]) {
                    camMemberMap.put(cam.Id,cam.Campaign_Members__r);
                }
            }
            System.debug('Campaing memebr map'+camMemberMap);
            if(camMemberMap.size()>0) {
                for(string cam_Mem :camMemberMap.keySet()) {
                    if(camMemberMap.containsKey(cam_Mem)) {
                        for(Campaign_Member__c camMem_Old:camMemberMap.get(cam_Mem)) {
                            if(string.isNotBlank(camMem_Old.Campaign1__r.Campaign_stage__c)) {
                                Lead__c le=new Lead__c();
                                le.id=camMem_Old.Lead1__c;
                                if(camMem_Old.Campaign1__r.Campaign_stage__c=='CME') {
                                    le.Planned_CME__c=system.today();
                                }   
                                else if(camMem_Old.Campaign1__r.Campaign_stage__c=='RTM') {
                                    
                                    le.Planned_RTM__c=system.today();
                                    
                                } 
                                else if(camMem_Old.Campaign1__r.Campaign_stage__c=='User Meeting') {
                                    
                                    le.Planned_User_Meeting__c=system.today();
                                } 
                                else if(camMem_Old.Campaign1__r.Campaign_stage__c=='High Impact CME') {
                                    
                                    le.Planned_High_Impact_CME__c=system.today();
                                } 
                                else if(camMem_Old.Campaign1__r.Campaign_stage__c=='KOL/FOL Development') {
                                    
                                    le.Planned_KOL_FOL_Development__c=system.today();
                                } 
                                else if(camMem_Old.Campaign1__r.Campaign_stage__c=='Virtual exp. Lab') {
                                    
                                    le.Planned_Virtual_exp_Lab__c=system.today();
                                } 
                                else if(camMem_Old.Campaign1__r.Campaign_stage__c=='Wet Labs') {
                                    
                                    le.Planned_Wet_Labs__c=system.today();
                                } 
                                else if(camMem_Old.Campaign1__r.Campaign_stage__c=='Testimonial') {
                                    
                                    le.Planned_Testimonial__c=system.today();
                                } 
                                else if(camMem_Old.Campaign1__r.Campaign_stage__c=='CTP') {
                                    
                                    le.Planned_CTP__c=system.today();
                                } 
                                else if(camMem_Old.Campaign1__r.Campaign_stage__c=='Focus') {
                                    
                                    le.Planned_Focus__c=system.today();
                                } 
                                else if(camMem_Old.Campaign1__r.Campaign_stage__c=='Decode') {
                                    
                                    le.Planned_Decode__c=system.today();
                                } 
                                else if(camMem_Old.Campaign1__r.Campaign_stage__c=='Inclinic Branding') {
                                    
                                    le.Planned_Inclinic_Branding__c = system.today();
                                } 
                                leadUpdateList.add(le);
                            }
                        }
                    }
                } 
                if(leadUpdateList.size()>0) {
                    System.debug('Lead updte list'+leadUpdateList);
                    update leadUpdateList;
                }
            }
        }
    }
    
    public static void productCount(List<Campaign_Member__c> newList) {
        Set<String> accIdSet=new Set<String>();
        Set<String> citySet=new Set<String>();
        Map<String, Map<String,List<Map<String,Double>>>> accountUniqueMap=new Map<String, Map<String,List<Map<String,Double>>>>(); 
        Set<String> cmpIdSet=new Set<String>();
        Map<String,Campaign__c> camMap=new Map<String,Campaign__c>();
        
        for(Campaign_Member__c  cmpMem:newList) {
            if(cmpMem.Campaign_City__c!=null) {
                citySet.add(cmpMem.Campaign_City__c);
            }
            if(cmpMem.Account__c!=null) {
                accIdSet.add(cmpMem.Account__c);
            }
            if(cmpMem.Campaign1__c!=null) {
                cmpIdSet.add(cmpMem.Campaign1__c);  
            }
        }
        
        if(cmpIdSet.size()>0) {
            for(Campaign__c cm:[SELECT Id,City__c,Product_1_Name__c,Product_2_Name__c,Product_3_Name__c,Product_4_Name__c from Campaign__c where Id in:cmpIdSet]) {
                camMap.put(cm.id,cm);
            }
        }
        
        if(citySet.size()>0 && accIdSet.size()>0) {
            for(Account acc:[SELECT Id,BillingCity,(SELECT Id,Phakic__c,Hydrophilics__c,Hydrophobic_Monofocal__c,Popular_Hydrophobic_Monofocal_Dropdown__c,
                                                    EDOF_Family__c,MF_Family__c,Trifocal_Family__c,TORIC__c,Account__r.BillingCity from CIS_Headers__r where  IsPrimary__c=:true ORDER By createddate desc limit 1) from Account where Id  in:accIdSet
                             AND BillingCity in:citySet]) {
                                 List<Map<String,Double>> cisHeaderCountList=new List<Map<String,Double>>();
                                 Map<String,List<Map<String,Double>>> countDataMap=new Map<String,List<Map<String,Double>>>(); 
                                 for(CIS_Header__c cis:acc.CIS_Headers__r) {
                                     Map<String,Double> uniqueMap=new Map<String,Double>();
                                     uniqueMap.put('Phakic',cis.Phakic__c); 
                                     uniqueMap.put('Hydrophilics',cis.Hydrophilics__c); 
                                     uniqueMap.put('Hydrophobic Monofocal',cis.Hydrophobic_Monofocal__c); 
                                     uniqueMap.put('Popular Hydrophobic Monofocal',cis.Popular_Hydrophobic_Monofocal_Dropdown__c); 
                                     uniqueMap.put('MF Family',cis.MF_Family__c); 
                                     uniqueMap.put('Trifocal Family',cis.Trifocal_Family__c); 
                                     uniqueMap.put('EDOF Family',cis.EDOF_Family__c); 
                                     uniqueMap.put('Toric',cis.TORIC__c); 
                                     cisHeaderCountList.add(uniqueMap);  
                                 }
                                 countDataMap.put(acc.BillingCity,cisHeaderCountList); 
                                 accountUniqueMap.put(acc.Id,countDataMap);
                             }//FOr loop close
            
            System.debug('Account Map---'+JSON.serialize(accountUniqueMap));
            
            for(Campaign_Member__c cmpMemb:newList) {
                if(cmpMemb.Account__c!=null && cmpMemb.Campaign1__c!=null ) {
                    if(camMap.containsKey(cmpMemb.Campaign1__c)) {
                        if(accountUniqueMap.containskey(cmpMemb.Account__c)) {
                            if(accountUniqueMap.get(cmpMemb.Account__c).containsKey(camMap.get(cmpMemb.Campaign1__c).City__c)) {
                                List<Map<String,double>> dataList=accountUniqueMap.get(cmpMemb.Account__c).get(camMap.get(cmpMemb.Campaign1__c).City__c);
                                Map<String,double> paramMap=CampaignTriggerHelper.getUniqueCountMap(dataList);
                                if(camMap.get(cmpMemb.Campaign1__c).Product_1_Name__c!=null) {
                                    ProductMapping__c mc = ProductMapping__c.getValues(camMap.get(cmpMemb.Campaign1__c).Product_1_Name__c);
                                    //    System.debug('mc'+mc.Product_Category__c);  
                                    if(mc!=null && paramMap.containsKey(mc.Product_Category__c)) {
                                        cmpMemb.Product_1Opportunity__c=paramMap.get(mc.Product_Category__c);
                                    }
                                }
                                if(camMap.get(cmpMemb.Campaign1__c).Product_2_Name__c!=null) {
                                    ProductMapping__c mc = ProductMapping__c.getValues(camMap.get(cmpMemb.Campaign1__c).Product_2_Name__c);
                                    if(mc!=null && paramMap.containsKey(mc.Product_Category__c)) {
                                        cmpMemb.Product_2_Opportunity__c=paramMap.get(mc.Product_Category__c);
                                    }
                                }
                                if(camMap.get(cmpMemb.Campaign1__c).Product_3_Name__c!=null) {
                                    ProductMapping__c mc = ProductMapping__c.getValues(camMap.get(cmpMemb.Campaign1__c).Product_3_Name__c);
                                    if(mc!=null && paramMap.containsKey(mc.Product_Category__c)) {
                                        cmpMemb.Product_3_Opportunity__c=paramMap.get(mc.Product_Category__c);
                                    }
                                }
                                if(camMap.get(cmpMemb.Campaign1__c).Product_4_Name__c!=null) {
                                    ProductMapping__c mc = ProductMapping__c.getValues(camMap.get(cmpMemb.Campaign1__c).Product_4_Name__c);
                                    if(mc!=null && paramMap.containsKey(mc.Product_Category__c)) {
                                        cmpMemb.Product_4_Opportunity__c=paramMap.get(mc.Product_Category__c);
                                    }
                                }
                            }else {
                                cmpMemb.Product_1Opportunity__c=0;
                                cmpMemb.Product_2_Opportunity__c=0;
                                cmpMemb.Product_3_Opportunity__c=0;
                                cmpMemb.Product_4_Opportunity__c=0;
                                
                            }
                        }
                    } 
                }
            }
        }//If close
        
    }
    
    public static void beforeUpdate(List<Campaign_Member__c> newList,Map<id,Campaign_Member__c> oldMap) {
        Set<String> accIdSet=new Set<String>();
        Set<String> citySet=new Set<String>();
        Map<String, Map<String,List<Map<String,Double>>>> accountUniqueMap=new Map<String, Map<String,List<Map<String,Double>>>>(); 
        Set<String> cmpIdSet=new Set<String>();
        
        Map<String,Campaign__c> camMap=new Map<String,Campaign__c>(); 
        for(Campaign_Member__c  cmpMem:newList) {
            if(cmpMem.Attended__c!=oldMap.get(cmpMem.id).Attended__c && cmpMem.Attended__c) {
                if(cmpMem.Campaign_City__c!=null) {
                    citySet.add(cmpMem.Campaign_City__c);
                }
                if(cmpMem.Account__c!=null) {
                    accIdSet.add(cmpMem.Account__c);
                }
                if(cmpMem.Campaign1__c!=null) {
                    cmpIdSet.add(cmpMem.Campaign1__c);  
                }  
            }//If close
        }//For new close
        System.debug('Campaign Id Set'+cmpIdSet);
        if(cmpIdSet.size()>0) {
            for(Campaign__c cm:[SELECT Id,City__c,Product_1_Name__c,Product_2_Name__c,Product_3_Name__c,Product_4_Name__c from Campaign__c where Id in:cmpIdSet]) {
                camMap.put(cm.id,cm);
            }
        }//CmpSet If close
        System.debug('City Set'+citySet);
        System.debug('AccSet--'+accIdSet);
        if(citySet.size()>0 && accIdSet.size()>0) {
            for(Account acc:[SELECT Id,BillingCity,(SELECT Id,Phakic__c,Hydrophilics__c,Hydrophobic_Monofocal__c,Popular_Hydrophobic_Monofocal_Dropdown__c,
                                                    EDOF_Family__c,MF_Family__c,Trifocal_Family__c,TORIC__c,Account__r.BillingCity from CIS_Headers__r where IsPrimary__c=:true ORDER By createddate desc limit 1) from Account where Id  in:accIdSet
                             AND BillingCity in:citySet]) {
                                 List<Map<String,Double>> cisHeaderCountList=new List<Map<String,Double>>();
                                 Map<String,List<Map<String,Double>>> countDataMap=new Map<String,List<Map<String,Double>>>(); 
                                 for(CIS_Header__c cis:acc.CIS_Headers__r) {
                                     Map<String,Double> uniqueMap=new Map<String,Double>();
                                     uniqueMap.put('Phakic',cis.Phakic__c); 
                                     uniqueMap.put('Hydrophilics',cis.Hydrophilics__c); 
                                     uniqueMap.put('Hydrophobic Monofocal',cis.Hydrophobic_Monofocal__c); 
                                     uniqueMap.put('Popular Hydrophobic Monofocal',cis.Popular_Hydrophobic_Monofocal_Dropdown__c); 
                                     uniqueMap.put('MF Family',cis.MF_Family__c); 
                                     uniqueMap.put('Trifocal Family',cis.Trifocal_Family__c); 
                                     uniqueMap.put('EDOF Family',cis.EDOF_Family__c); 
                                     uniqueMap.put('Toric',cis.TORIC__c); 
                                     cisHeaderCountList.add(uniqueMap);  
                                 }
                                 countDataMap.put(acc.BillingCity,cisHeaderCountList); 
                                 accountUniqueMap.put(acc.Id,countDataMap);
                             }//FOr loop close
            
            System.debug('Account Map---'+JSON.serialize(accountUniqueMap)); 
            for(Campaign_Member__c cmpMemb:newList) {
                if(cmpMemb.Account__c!=null && cmpMemb.Campaign1__c!=null && (cmpMemb.Attended__c!=oldMap.get(cmpMemb.id).Attended__c && cmpMemb.Attended__c)) {
                    System.debug('In loop');
                    if(camMap.containsKey(cmpMemb.Campaign1__c)) {
                        if(accountUniqueMap.containskey(cmpMemb.Account__c)) {
                            if(accountUniqueMap.get(cmpMemb.Account__c).containsKey(camMap.get(cmpMemb.Campaign1__c).City__c)) {
                                List<Map<String,double>> dataList=accountUniqueMap.get(cmpMemb.Account__c).get(camMap.get(cmpMemb.Campaign1__c).City__c);
                                Map<String,double> paramMap=CampaignTriggerHelper.getUniqueCountMap(dataList);
                                if(camMap.get(cmpMemb.Campaign1__c).Product_1_Name__c!=null) {
                                    System.debug('In Main Loop');
                                    ProductMapping__c mc = ProductMapping__c.getValues(camMap.get(cmpMemb.Campaign1__c).Product_1_Name__c);
                                    //    System.debug('mc'+mc.Product_Category__c);  
                                    if(mc!=null && paramMap.containsKey(mc.Product_Category__c)) {
                                        cmpMemb.Attended_Product_1_Opportunity__c=paramMap.get(mc.Product_Category__c);
                                    }
                                }
                                if(camMap.get(cmpMemb.Campaign1__c).Product_2_Name__c!=null) {
                                    ProductMapping__c mc = ProductMapping__c.getValues(camMap.get(cmpMemb.Campaign1__c).Product_2_Name__c);
                                    if(mc!=null && paramMap.containsKey(mc.Product_Category__c)) {
                                        cmpMemb.Attended_Product_2_Opportunity__c=paramMap.get(mc.Product_Category__c);
                                    }
                                }
                                if(camMap.get(cmpMemb.Campaign1__c).Product_3_Name__c!=null) {
                                    ProductMapping__c mc = ProductMapping__c.getValues(camMap.get(cmpMemb.Campaign1__c).Product_3_Name__c);
                                    if(mc!=null && paramMap.containsKey(mc.Product_Category__c)) {
                                        cmpMemb.Attended_Product_3_Opportunity__c=paramMap.get(mc.Product_Category__c);
                                    }
                                }
                                if(camMap.get(cmpMemb.Campaign1__c).Product_4_Name__c!=null) {
                                    ProductMapping__c mc = ProductMapping__c.getValues(camMap.get(cmpMemb.Campaign1__c).Product_4_Name__c);
                                    if(mc!=null && paramMap.containsKey(mc.Product_Category__c)) {
                                        cmpMemb.Attended_Product_4_Opportunity__c=paramMap.get(mc.Product_Category__c);
                                    }
                                }
                            }else {
                                cmpMemb.Attended_Product_1_Opportunity__c=0;
                                cmpMemb.Attended_Product_2_Opportunity__c=0;
                                cmpMemb.Attended_Product_3_Opportunity__c=0;
                                cmpMemb.Attended_Product_4_Opportunity__c=0;
                                
                            }
                        }
                    } 
                }
            }
        }
        
    }
    
    
    
}