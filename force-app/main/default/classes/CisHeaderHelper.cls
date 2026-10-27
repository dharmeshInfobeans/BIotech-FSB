/**=====================================================================
* 
* Name: CisHeaderHelper 
* Description: This Helper is using to put the CE-CIS  and the Phakic rating according to the given ranges.
* Created Date: 25-08-2022
* Created By: (Plus91labs) -Pankaj Sen
* 
* Date Modified                        Description of the update
*           
=====================================================================*/


public class CisHeaderHelper {
    public static void getCeCisRating(List<CIS_Header__c> newList,Map<Id,CIS_Header__c> oldMap) {
        Map<String,string> ceCisMap=new Map<String,string>();
        Map<String,decimal> ratingDataMap=new Map<String,decimal>();
        Map<String,String> recordTypeMap=new Map<String,String>();
        Map<String,List<CE_CIS_Configuration__c>> ceCisListMap=new Map<String,List<CE_CIS_Configuration__c>>();
        Map<String,String> accApproverMap=new Map<String,String>();
        for(RecordType rec:[SELECT id,Name from RecordType]) {//Get all the recordType Names
            recordTypeMap.put(rec.Id,rec.Name);
        }
        
        for(CIS_Header__c cisHea:newList) {
            
            if(cisHea.Stop_Approval__c==false && (cisHea.EDOF_Family__c!=oldMap.get(cisHea.id).EDOF_Family__c || cisHea.Hydrophilics__c!=oldMap.get(cisHea.id).Hydrophilics__c || cisHea.Hydrophobic_Monofocal__c!=oldMap.get(cisHea.id).Hydrophobic_Monofocal__c || 
                                                  cisHea.MF_Family__c!=oldMap.get(cisHea.id).MF_Family__c || cisHea.No_of_LVC_Procedures__c!=oldMap.get(cisHea.id).No_of_LVC_Procedures__c|| 
                                                  cisHea.Phakic__c!=oldMap.get(cisHea.id).Phakic__c ||  cisHea.Popular_Hydrophobic_Monofocal_Dropdown__c!=oldMap.get(cisHea.id).Popular_Hydrophobic_Monofocal_Dropdown__c || 
                                                  cisHea.TORIC__c!=oldMap.get(cisHea.id).TORIC__c ||  cisHea.Total__c!=oldMap.get(cisHea.id).Total__c ||  cisHea.Trifocal_Family__c!=oldMap.get(cisHea.id).Trifocal_Family__c )){
                                                      if(recordTypeMap.get(cisHea.RecordTypeId)!=null || string.isNotBlank(recordTypeMap.get(cisHea.RecordTypeId))) {
                                                          ceCisMap.put(cisHea.Account__c,recordTypeMap.get(cisHea.RecordTypeId));
                                                      } else {
                                                          ceCisMap.put(cisHea.Account__c,'TURKEY');
                                                      }
                                                      //get the unique Customer information sheet record according to the Customer
                                                  }
            
        }
        System.debug('Ce cis Map'+ceCisMap);
        if(ceCisMap.size()>0) {
            
            for(CE_CIS_Configuration__c ceCis:[SELECT Id,From_Range__c,To_Range__c,Type__c,Rating__c,Country__c 
                                               from CE_CIS_Configuration__c where Country__c=:ceCisMap.values() ]) {
                                                   System.debug('Ce cis data'+ceCis);
                                                   if(ceCisListMap.containskey(ceCis.Country__c)) {
                                                       ceCisListMap.get(ceCis.Country__c).add(ceCis);    
                                                   } else {
                                                       ceCisListMap.put(ceCis.Country__c,new List<CE_CIS_Configuration__c>{ceCis});//get the Ce cis Configurations data based on the country
                                                   }
                                               }
            
            System.debug('Ce cis List Map'+ceCisListMap);
            for(CIS_Header__c cuInShe:newList) {
                decimal generatingData=cuInShe.Hydrophobic_Monofocal__c+cuInShe.Popular_Hydrophobic_Monofocal_Dropdown__c+cuInShe.TORIC__c+cuInShe.MF_Family__c+cuInShe.Trifocal_Family__c+cuInShe.EDOF_Family__c;//get the total of all the fields.
                System.debug('Generating data'+generatingData);
                decimal premiumPerc;
                if(generatingData==0) {
                    premiumPerc=0;
                } else {
                    premiumPerc=MATH.ceil((cuInShe.TORIC__c+cuInShe.MF_Family__c+cuInShe.Trifocal_Family__c+cuInShe.EDOF_Family__c) /generatingData * 100.0);
                }
                //Get the percentage for Premium surgeries
                
                System.debug('Premium percentage'+premiumPerc);
                
                if(ceCisListMap.containsKey(recordTypeMap.get(cuInShe.RecordTypeId))) {
                    for(CE_CIS_Configuration__c ceCisConf:ceCisListMap.get(recordTypeMap.get(cuInShe.RecordTypeId))) {
                        System.debug('ceCisConf.Type__c22'+ceCisConf.Type__c);
                        if(ceCisConf.Type__c=='Surgeries') {
                            if(generatingData>=ceCisConf.From_Range__c && generatingData<=ceCisConf.To_Range__c) {
                                cuInShe.Ce_Cis_Rating__c=ceCisConf.Rating__c;
                            }
                        }
                        if(ceCisConf.Type__c=='Phakic') {
                            System.debug('Phakic'+cuInShe.Phakic__c);
                            if(cuInShe.Phakic__c>=ceCisConf.From_Range__c && cuInShe.Phakic__c<=ceCisConf.To_Range__c) {
                                cuInShe.Phakic_Rating__c=ceCisConf.Rating__c;
                            } 
                        }
                    }
                }   
            }
            
            
            for(CIS_Header__c cuInShe:newList) {
                decimal generatingData=cuInShe.Hydrophobic_Monofocal__c+cuInShe.Popular_Hydrophobic_Monofocal_Dropdown__c+
                    cuInShe.TORIC__c+cuInShe.MF_Family__c+cuInShe.Trifocal_Family__c+cuInShe.EDOF_Family__c;//get the total of all the fields.
                System.debug('Generating data'+generatingData);
                decimal premiumPerc;
                if(generatingData==0) {
                    premiumPerc=0;
                } else {
                    premiumPerc=MATH.ceil((cuInShe.TORIC__c+cuInShe.MF_Family__c+cuInShe.Trifocal_Family__c+cuInShe.EDOF_Family__c) /generatingData * 100.0);
                }
                System.debug('Premium'+premiumPerc);
                //   decimal premiumPhakic=cuInShe.Phakic__c+cuInShe.No_of_LVC_Procedures__c;//Get the Total for Premium phakic
                // System.debug('Decimal Premium phakic'+premiumPhakic);
                if(accApproverMap.containsKey(cuInShe.Account__c)) {
                    cuInShe.User__c=accApproverMap.get(cuInShe.Account__c);
                }
                if(ceCisListMap.containsKey(recordTypeMap.get(cuInShe.RecordTypeId))) {
                    for(CE_CIS_Configuration__c ceCisConf:ceCisListMap.get(recordTypeMap.get(cuInShe.RecordTypeId))) {
                        if(ceCisConf.Type__c=='Premium Phakic') {
                            if(cuInShe.No_of_LVC_Procedures__c>=ceCisConf.From_Range__c && cuInShe.No_of_LVC_Procedures__c<=ceCisConf.To_Range__c) {
                                cuInShe.Phakic_Rating__c=(cuInShe.Phakic_Rating__c?? '')+''+ceCisConf.Rating__c;
                                
                            } 
                        } 
                        if(ceCisConf.Type__c=='Premium surgeries') {
                            if(premiumPerc>=ceCisConf.From_Range__c && premiumPerc<=ceCisConf.To_Range__c) {
                                cuInShe.Ce_Cis_Rating__c= (cuInShe.Ce_Cis_Rating__c ?? '') +''+ceCisConf.Rating__c;
                                
                            } 
                        }
                        
                    }
                }
            }
        }
    } 
    /*---This mehtod is using to update the CE-CIS rating on the Account and the Lead from the customer information sheet-----*/
    public static void updateCeCisRatingAcccount(List<CIS_Header__c> newList,Map<Id,CIS_Header__c> oldMap) {
        Map<String,String> ceCisRatingMap=new Map<String,String>();
        Map<String,String> phakicRatingMap=new Map<String,String>();
        Map<String,String> ceCisRatingLeadMap=new Map<String,String>();
        Map<String,String> phakicRatingLeadMap=new Map<String,String>();
        Map<String,String> ceCisRatingcontactmap=new Map<String,String>();
        Map<String,String> phakicRatingcontactmap=new Map<String,String>();
        List<Account> accList=new List<Account>();
        List<Lead__c> leadList=new List<Lead__c>();
        List<contact> conlist = new List<contact>();
        Boolean showData=false;
        Set<Id> leadIdSet=new Set<Id>();
        for(CIS_Header__c cuInfSh:newList) {
            if(cuInfSh.Stop_Approval__c==false && (cuInfSh.Account__c!=null &&  cuInfSh.Status__c==oldMap.get(cuInfSh.Id).Status__c && 
                                                   (cuInfSh.EDOF_Family__c!=oldMap.get(cuInfSh.id).EDOF_Family__c || cuInfSh.Hydrophilics__c!=oldMap.get(cuInfSh.id).Hydrophilics__c || cuInfSh.Hydrophobic_Monofocal__c!=oldMap.get(cuInfSh.id).Hydrophobic_Monofocal__c || 
                                                    cuInfSh.MF_Family__c!=oldMap.get(cuInfSh.id).MF_Family__c || cuInfSh.No_of_LVC_Procedures__c!=oldMap.get(cuInfSh.id).No_of_LVC_Procedures__c|| 
                                                    cuInfSh.Phakic__c!=oldMap.get(cuInfSh.id).Phakic__c ||  cuInfSh.Popular_Hydrophobic_Monofocal_Dropdown__c!=oldMap.get(cuInfSh.id).Popular_Hydrophobic_Monofocal_Dropdown__c || 
                                                    cuInfSh.TORIC__c!=oldMap.get(cuInfSh.id).TORIC__c ||  cuInfSh.Total__c!=oldMap.get(cuInfSh.id).Total__c ||  cuInfSh.Trifocal_Family__c!=oldMap.get(cuInfSh.id).Trifocal_Family__c ))) {
                                                        ceCisRatingMap.put(cuInfSh.Account__c,cuInfSh.Ce_Cis_Rating__c);
                                                        phakicRatingMap.put(cuInfSh.Account__c,cuInfSh.Phakic_Rating__c);
                                                    }
            if(cuInfSh.Stop_Approval__c==false && (cuInfSh.Leads__c!=null &&  cuInfSh.Status__c==oldMap.get(cuInfSh.Id).Status__c  && 
                                                   (cuInfSh.EDOF_Family__c!=oldMap.get(cuInfSh.id).EDOF_Family__c || cuInfSh.Hydrophilics__c!=oldMap.get(cuInfSh.id).Hydrophilics__c || cuInfSh.Hydrophobic_Monofocal__c!=oldMap.get(cuInfSh.id).Hydrophobic_Monofocal__c || 
                                                    cuInfSh.MF_Family__c!=oldMap.get(cuInfSh.id).MF_Family__c || cuInfSh.No_of_LVC_Procedures__c!=oldMap.get(cuInfSh.id).No_of_LVC_Procedures__c|| 
                                                    cuInfSh.Phakic__c!=oldMap.get(cuInfSh.id).Phakic__c ||  cuInfSh.Popular_Hydrophobic_Monofocal_Dropdown__c!=oldMap.get(cuInfSh.id).Popular_Hydrophobic_Monofocal_Dropdown__c || 
                                                    cuInfSh.TORIC__c!=oldMap.get(cuInfSh.id).TORIC__c ||  cuInfSh.Total__c!=oldMap.get(cuInfSh.id).Total__c ||  cuInfSh.Trifocal_Family__c!=oldMap.get(cuInfSh.id).Trifocal_Family__c ))) {
                                                        ceCisRatingLeadMap.put(cuInfSh.Leads__c,cuInfSh.CE_CIS_Rating__c);
                                                        phakicRatingLeadMap.put(cuInfSh.Leads__c,cuInfSh.Phakic_Rating__c); 
                                                    }
            //----------------Added below-------------
            if(cuInfSh.Stop_Approval__c==false && (cuInfSh.contact__c !=null &&  cuInfSh.Status__c==oldMap.get(cuInfSh.Id).Status__c  && 
                                                   (cuInfSh.EDOF_Family__c!=oldMap.get(cuInfSh.id).EDOF_Family__c || cuInfSh.Hydrophilics__c!=oldMap.get(cuInfSh.id).Hydrophilics__c || cuInfSh.Hydrophobic_Monofocal__c!=oldMap.get(cuInfSh.id).Hydrophobic_Monofocal__c || 
                                                    cuInfSh.MF_Family__c!=oldMap.get(cuInfSh.id).MF_Family__c || cuInfSh.No_of_LVC_Procedures__c!=oldMap.get(cuInfSh.id).No_of_LVC_Procedures__c|| 
                                                    cuInfSh.Phakic__c!=oldMap.get(cuInfSh.id).Phakic__c ||  cuInfSh.Popular_Hydrophobic_Monofocal_Dropdown__c!=oldMap.get(cuInfSh.id).Popular_Hydrophobic_Monofocal_Dropdown__c || 
                                                    cuInfSh.TORIC__c!=oldMap.get(cuInfSh.id).TORIC__c ||  cuInfSh.Total__c!=oldMap.get(cuInfSh.id).Total__c ||  cuInfSh.Trifocal_Family__c!=oldMap.get(cuInfSh.id).Trifocal_Family__c ))) {
                                                        ceCisRatingcontactmap.put(cuInfSh.contact__c,cuInfSh.CE_CIS_Rating__c);
                                                        phakicRatingcontactmap.put(cuInfSh.contact__c,cuInfSh.Phakic_Rating__c); 
                                                    }

            
            if(cuInfSh.Status__c!=oldMap.get(cuInfSh.Id).Status__c && cuInfSh.Status__c=='Approved') {
                leadIdSet.add(cuInfSh.Leads__c);
                showData=true;
            }            
            
        }
        
        
        System.debug('Ce Lead Map'+ceCisRatingLeadMap);
        
        if(ceCisRatingcontactmap.size()>0 && phakicRatingcontactmap.size()>0) {
            for(contact con:[SELECT Id,Ce_Cis_Rating__c,Phakic_Rating__c from contact where Id in:ceCisRatingcontactmap.keySet()]) {
                if(ceCisRatingcontactmap.containsKey(con.Id)) {
                    con.Ce_Cis_Rating__c=ceCisRatingcontactmap.get(con.Id);//Update the CE-CIS rating on the Lead
                    if(phakicRatingcontactmap.containsKey(con.Id)) {
                        con.Phakic_Rating__c=phakicRatingcontactmap.get(con.Id);//Update the Phakic rating on the Lead
                    }
                    conlist.add(con);
                }
            }
            if(conlist.size()>0) {
                
                update conlist; 
            }
            
        }
        
        System.debug('CE cis Map'+ceCisRatingMap);
        if(ceCisRatingMap.size()>0 && phakicRatingMap.size()>0) {
            for(Account acc:[SELECT Id,Name,CE_CIS_Rating__c,Phakic_Rating__c,last_CIS_date__c,last_CE_date__c from Account where Id in:ceCisRatingMap.keySet()]) {
                if(ceCisRatingMap.containsKey(acc.Id)) {
                    acc.CE_CIS_Rating__c=ceCisRatingMap.get(acc.Id);//Update the CE-CIS rating on the Account 
                    acc.last_CIS_date__c=system.today();
                    acc.last_CE_date__c=system.today();
                    
                    if(phakicRatingMap.containsKey(acc.Id)) {
                        acc.Phakic_Rating__c=phakicRatingMap.get(acc.Id);//Update the Phakic rating on the Account
                    }
                    accList.add(acc);
                }
            }
            if(accList.size()>0) {
                update accList; 
            }
            
        }
        System.debug('Ce Lead Map'+ceCisRatingLeadMap);
        if(ceCisRatingLeadMap.size()>0 && phakicRatingLeadMap.size()>0) {
            for(Lead__c lea:[SELECT Id,CE_CIS_Rating__c,Phakic_Rating__c,Lead_Stage__c from Lead__c where Id in:ceCisRatingLeadMap.keySet() AND Lead_Stage__c!='Converted' ]) {
                if(ceCisRatingLeadMap.containsKey(lea.Id)) {
                    lea.CE_CIS_Rating__c=ceCisRatingLeadMap.get(lea.Id);//Update the CE-CIS rating on the Lead
                    if(phakicRatingLeadMap.containsKey(lea.Id)) {
                        lea.Phakic_Rating__c=phakicRatingLeadMap.get(lea.Id);//Update the Phakic rating on the Lead
                    }
                    leadList.add(lea);
                }
            }
            if(leadList.size()>0) {
                
                update leadList; 
            }
            
        }
        
        
        
        if(leadIdSet.size()>0 && showData==true) {
            List<Lead__c> leadUpdateList=new List<Lead__c>();
            for(Lead__c lea:[SELECT Id,CE_CIS_Approval__c from Lead__c where Id in:leadIdSet AND Lead_Stage__c !='Won' AND Lead_Closed__c != true]) {
                lea.CE_CIS_Approval__c=true;
                leadUpdateList.add(lea);
            }
            if(leadUpdateList.size()>0) {
                update leadUpdateList; 
            }
            
        }
    }
    
    
    public static void updateCEcisApprovalLead(List<CIS_Header__c> newList) {
        List<CIS_Header__c> cisHeaUpdateList=new List<CIS_Header__c>();
        Set<String> leadIdSet=new Set<String>();
        Set<String> accId=new Set<String>();
        Set<String> leadId=new Set<String>();
        for(CIS_Header__c cis:newList) {
            cis.IsPrimary__c=true; 
            if(cis.Leads__c!=null) {
                leadIdSet.add(cis.Leads__c);
            }
            
            if(cis.Account__c!=null) {
                accId.add(cis.Account__c);
            }
            
        }
        System.debug('Lead Id set'+leadIdSet);
        if(leadIdSet.size()>0) {
            List<Lead__c> leadUpdateList=new List<Lead__c>();
            for(Lead__c lea:[SELECT Id,CE_CIS_Approval__c from Lead__c where Id in:leadIdSet]) {
                lea.CE_CIS_Approval__c=false;
                leadUpdateList.add(lea);
            }
            if(leadUpdateList.size()>0) {
                update leadUpdateList; 
            }
            
        }
        for(CIS_Header__c cisHead:[SELECT Id,Account__c,Leads__c from CIS_Header__c where (Account__c in:accId OR Leads__c in:leadIdSet)]) {
            cisHead.IsPrimary__c=false;
            cisHeaUpdateList.add(cisHead);
        }
        if(cisHeaUpdateList.size()>0) {
            update  cisHeaUpdateList;
        }
    }
    
    
    public static void updateProductCountOnCampaign(List<CIS_Header__c> newList,Map<Id,CIS_Header__c> oldMap) {
        Set<string> accIdSet=new Set<String>();
        Map<String,List<Map<String,Double>>> countDataMap=new Map<String,List<Map<String,Double>>>();
        Map<String, Map<String,List<Map<String,Double>>>> accountUniqueMap=new Map<String, Map<String,List<Map<String,Double>>>>(); 
        Map<String,String> camMap=new Map<String,String>();
        List<Campaign_Member__c> cmpMemUpdateList= new List<Campaign_Member__c>();
        List<Campaign__c> campaignUpdateList=new List<Campaign__c>();
        Set<String> citySet=new Set<String>();
        // Set<String> accIdSet=new Set<String>();
        
        for(CIS_Header__c cisHd:newList) {
            System.debug('cisHd.Account__c'+cisHd.Account__c);
            System.debug('cisHd.Status__c'+cisHd.Status__c);
             System.debug('oldMap.get(cisHd.id).Status__c'+oldMap.get(cisHd.id).Status__c);
            System.debug('cisHd.City__c'+cisHd.City__c);
            if(cisHd.Account__c!=null && (cisHd.Status__c!=oldMap.get(cisHd.id).Status__c && cisHd.Status__c=='Approved' && cisHd.City__c!=null)) {
                citySet.add(cisHd.City__c.toUpperCase()); 
                accIdSet.add(cisHd.Account__c);
            }
            
        }
        if(citySet.size()>0) {
            countDataMap= CampaignTriggerHelper.getCisHeaderList(citySet,new Set<String>()); 
            
            for(Account acc:[SELECT Id,BillingCity,(SELECT Id,Phakic__c,Hydrophilics__c,Hydrophobic_Monofocal__c,Popular_Hydrophobic_Monofocal_Dropdown__c,
                                                    EDOF_Family__c,MF_Family__c,Trifocal_Family__c,TORIC__c,Account__r.BillingCity from CIS_Headers__r where (Status__c='Approved' AND IsPrimary__c=:true) ORDER By lastmodifieddate desc limit 1) from Account where Id  in:accIdSet
                             AND BillingCity in:citySet]) {
                                 List<Map<String,Double>> cisHeaderCountList=new List<Map<String,Double>>();
                                 Map<String,List<Map<String,Double>>> countDataMap1=new Map<String,List<Map<String,Double>>>(); 
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
                                 countDataMap1.put(acc.BillingCity.toUpperCase(),cisHeaderCountList); 
                                 accountUniqueMap.put(acc.Id,countDataMap1);
                             }
            
           System.debug('SerailizeCountDataMap'+JSON.serialize(countDataMap));
            System.debug('Account map'+JSON.serialize(accountUniqueMap));
            if(accountUniqueMap.size()>0) {
                System.debug('Testing menu');
                for(Campaign__c cam:[SELECT Id,City__c,Product_1_Name__c,Product_2_Name__c,Product_3_Name__c,Product_4_Name__c,
                                     Product_1_Opportunity__c,Product_2_Opportunity__c,Product_3_Opportunity__c,Product_4_Opportunity__c from Campaign__c where City__c in:countDataMap.keySet()]) {
                                         if(countDataMap.size()>0 && countDataMap.containsKey(cam.City__c)) {
                                             List<Map<String,double>> dataList=countDataMap.get(cam.City__c);
                                             Map<String,double> paramMap=CampaignTriggerHelper.getUniqueCountMap(dataList);
                                             System.debug('Param map--'+JSON.serialize(paramMap));
                                             if(cam.Product_1_Name__c!=null) {
                                                 ProductMapping__c mc = ProductMapping__c.getValues(cam.Product_1_Name__c);
                                                 if(mc!=null && paramMap.containsKey(mc.Product_Category__c)) {
                                                     
                                                     cam.Product_1_Opportunity__c=paramMap.get(mc.Product_Category__c);
                                                 }
                                             }
                                             if(cam.Product_2_Name__c!=null) {
                                                 ProductMapping__c mc = ProductMapping__c.getValues(cam.Product_2_Name__c);
                                                 if(mc!=null && paramMap.containsKey(mc.Product_Category__c)) {
                                                     cam.Product_2_Opportunity__c=paramMap.get(mc.Product_Category__c);
                                                 }
                                             }
                                             if(cam.Product_3_Name__c!=null) {
                                                 ProductMapping__c mc = ProductMapping__c.getValues(cam.Product_3_Name__c);
                                                 if(mc!=null && paramMap.containsKey(mc.Product_Category__c)) {
                                                     cam.Product_3_Opportunity__c=paramMap.get(mc.Product_Category__c);
                                                 }
                                             }
                                             if(cam.Product_4_Name__c!=null) {
                                                 ProductMapping__c mc = ProductMapping__c.getValues(cam.Product_4_Name__c);
                                                 if(mc!=null && paramMap.containsKey(mc.Product_Category__c)) {
                                                     cam.Product_4_Opportunity__c=paramMap.get(mc.Product_Category__c);
                                                 }
                                             }
                                             campaignUpdateList.add(cam);
                                         }
                                     }
                
                
                for(Campaign_Member__c cmp:[SELECT Id,Product_1Opportunity__c,Product_2_Opportunity__c,Product_3_Opportunity__c,Product_4_Opportunity__c,
                                            Campaign1__c,Campaign1__r.City__c,Campaign1__r.Product_1_Opportunity__c,Campaign1__r.Product_2_Opportunity__c,
                                            Campaign1__r.Product_3_Opportunity__c,Campaign1__r.Product_4_Opportunity__c,Account__c,Campaign1__r.Product_1_Name__c,
                                            Campaign1__r.Product_2_Name__c,Campaign1__r.Product_3_Name__c,Campaign1__r.Product_4_Name__c
                                            from Campaign_Member__c where (Account__c!=null AND Account__c in:accIdSet)]) {
                                                if(accountUniqueMap.containsKey(cmp.Account__c)) {
                                                    List<Map<String,double>> dataList=accountUniqueMap.get(cmp.Account__c).get(cmp.Campaign1__r.City__c);
                                                    if(dataList!=null) {
                                                        
                                                        
                                                        Map<String,double> paramMap=CampaignTriggerHelper.getUniqueCountMap(dataList);
                                                        if(cmp.Campaign1__r.Product_1_Name__c!=null) {
                                                            ProductMapping__c mc = ProductMapping__c.getValues(cmp.Campaign1__r.Product_1_Name__c);
                                                            System.debug('mc'+mc.Product_Category__c);  
                                                            if(mc!=null && paramMap.containsKey(mc.Product_Category__c)) {
                                                                cmp.Product_1Opportunity__c=paramMap.get(mc.Product_Category__c);
                                                            }
                                                        }
                                                        if(cmp.Campaign1__r.Product_2_Name__c!=null) {
                                                            ProductMapping__c mc = ProductMapping__c.getValues(cmp.Campaign1__r.Product_2_Name__c);
                                                            if(mc!=null && paramMap.containsKey(mc.Product_Category__c)) {
                                                                cmp.Product_2_Opportunity__c=paramMap.get(mc.Product_Category__c);
                                                            }
                                                        }
                                                        if(cmp.Campaign1__r.Product_3_Name__c!=null) {
                                                            ProductMapping__c mc = ProductMapping__c.getValues(cmp.Campaign1__r.Product_3_Name__c);
                                                            if(mc!=null && paramMap.containsKey(mc.Product_Category__c)) {
                                                                cmp.Product_3_Opportunity__c=paramMap.get(mc.Product_Category__c);
                                                            }
                                                        }
                                                        if(cmp.Campaign1__r.Product_4_Name__c!=null) {
                                                            ProductMapping__c mc = ProductMapping__c.getValues(cmp.Campaign1__r.Product_4_Name__c);
                                                            if(mc!=null &&   paramMap.containsKey(mc.Product_Category__c)) {
                                                                cmp.Product_4_Opportunity__c=paramMap.get(mc.Product_Category__c);
                                                            }
                                                        }                                                
                                                        cmpMemUpdateList.add(cmp);  
                                                    }
                                                }//Nested account unique map close
                                                
                                                
                                                
                                            } //For loop close cam
                
            }//accountUniqueMap main close
        }//accIdSet close
        
        if(campaignUpdateList.size()>0) {
            update  campaignUpdateList;
            System.debug('Update Campaing List--'+JSON.serialize(campaignUpdateList));
        }
        if(cmpMemUpdateList.size()>0) {
            System.debug('Campaign Meme list--'+JSON.serialize(cmpMemUpdateList));
            update cmpMemUpdateList; 
        }
        
    }//method close
    
    
    
}