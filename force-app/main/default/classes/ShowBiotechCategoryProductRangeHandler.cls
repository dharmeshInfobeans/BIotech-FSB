public without sharing class ShowBiotechCategoryProductRangeHandler {

    public class BiotechDataWrapper {
        @AuraEnabled public String agreementPrice;
        @AuraEnabled public String foc;
        @AuraEnabled public String customsCharges;
        @AuraEnabled public String landingCost;
        @AuraEnabled public String endUserPrice;
        @AuraEnabled public String origin;
    }

    public class BrandValueWrapper {
        @AuraEnabled public String Brand_Name;
        @AuraEnabled public String Price_KeyAccounts;
        @AuraEnabled public String Price_for_Retail;
        @AuraEnabled public String Total_Package;
    }

    public class DivisionCategoryWrapper {
        @AuraEnabled public String key;
        @AuraEnabled public String division;
        @AuraEnabled public String category;
        @AuraEnabled public String productRange;
        @AuraEnabled public Integer rowspan;
        @AuraEnabled public Boolean showDivision;

        @AuraEnabled public String agreementPrice;
        @AuraEnabled public String agreementFOC;

        @AuraEnabled public List<BrandValueWrapper> brandValues;
        @AuraEnabled public BiotechDataWrapper biotechData; 
    }

    @AuraEnabled
    public static List<DivisionCategoryWrapper> getDistributorData(
        List<Id> distributorIds, 
        List<String> distributorName, 
        String userId,
        Id recordId
    ) {
        List<DivisionCategoryWrapper> finalList = new List<DivisionCategoryWrapper>();
        Boolean shouldCreateNewVersion = false;
        Id contactId;

        // ------------ Resolve Contact context: Community user vs Internal user on record page ------------
        User currentUser = [SELECT Id, ContactId FROM User WHERE Id = :userId LIMIT 1]??Null;

        if (currentUser?.ContactId != null) {
            // Community user case — apna khud ka Contact
            contactId = currentUser.ContactId;
        } else if (recordId != null) {
            // Internal user on Account record page — resolve Contact via existing Market X Ray Form
            List<Market_X_Ray_Form__c> accountForms = [
                SELECT Id, Contact__c, IsMarketXrayFormEditable__c 
                FROM Market_X_Ray_Form__c 
                WHERE Contact__r.AccountId = :recordId 
                ORDER BY CreatedDate DESC 
                LIMIT 1
            ];
            if (accountForms.isEmpty()) {
                return finalList; // is Account ke kisi bhi Contact ka form nahi mila
            }
            contactId = accountForms[0].Contact__c;
        } else {
            System.debug('Unable to determine Contact context.');
            //throw new AuraHandledException('Unable to determine Contact context.');
        }

        Contact con = [SELECT Create_New_Market_X_Ray_Version__c FROM Contact WHERE Id = :contactId LIMIT 1];
        shouldCreateNewVersion = con.Create_New_Market_X_Ray_Version__c;

        List<Market_X_Ray_Form__c> forms = [
            SELECT Id, IsMarketXrayFormEditable__c 
            FROM Market_X_Ray_Form__c 
            WHERE Contact__c = :contactId 
            ORDER BY CreatedDate DESC LIMIT 1
        ];

        System.debug('forms size >> ' + forms.size());
        System.debug('shouldCreateNewVersion >> ' + shouldCreateNewVersion);

        if (forms.isEmpty()) {
            return finalList;
        }

        if (shouldCreateNewVersion && forms[0].IsMarketXrayFormEditable__c == true) {
            return finalList;
        }

        Id formId = forms[0].Id;
        System.debug('formId ' + formId);

        List<DistributorLineItem__c> lineItems = [
            SELECT Id, Division__c, Category__c, Biotech_Product_Range__c, Brand_Name__c, Total_Package__c,
                   Price_Key_Account__c, Agreement_Product__r.FOC_Text__c, Agreement_Product__r.Price__c,
                   End_User_Price_by_Distributor_to_Doctor__c, Price_For_Retail__c, Origin__c, Distributor__r.Name
            FROM DistributorLineItem__c 
            WHERE Distributor__c IN :distributorIds AND Market_X_Ray_Form__c = :formId
            ORDER BY Division__c, Category__c
        ];

        System.debug('lineItems=======>>>>>' + lineItems);

        // ------------ Build bioTech row map by combination -------------
        Map<String, DistributorLineItem__c> biotechRowMap = new Map<String, DistributorLineItem__c>();
        for (DistributorLineItem__c rec : lineItems) {
            String comb = rec.Division__c + rec.Biotech_Product_Range__c + rec.Category__c;
            if (rec.Distributor__r.Name == 'Biotech') {
                biotechRowMap.put(comb, rec);
            }
        }

        Map<String, Map<String, DistributorLineItem__c>> categoryGroupMap = new Map<String, Map<String, DistributorLineItem__c>>();
        Map<String, Map<String, Map<String, DistributorLineItem__c>>> mapofBrandAnddistributorLineItem = new Map<String, Map<String, Map<String, DistributorLineItem__c>>>();

        for (DistributorLineItem__c rec : lineItems) {
            String combination = rec.Division__c + rec.Biotech_Product_Range__c + rec.Category__c;

            if (!categoryGroupMap.containsKey(rec.Division__c)) {
                categoryGroupMap.put(rec.Division__c, new Map<String, DistributorLineItem__c>());
            }
            categoryGroupMap.get(rec.Division__c).put(combination, rec);

            if (!mapofBrandAnddistributorLineItem.containsKey(rec.Division__c)) {
                mapofBrandAnddistributorLineItem.put(
                    rec.Division__c,
                    new Map<String, Map<String, DistributorLineItem__c>>()
                );
            }
            if (!mapofBrandAnddistributorLineItem.get(rec.Division__c).containsKey(rec.Distributor__r.Name.toUpperCase())) {
                mapofBrandAnddistributorLineItem
                    .get(rec.Division__c)
                    .put(rec.Distributor__r.Name.toUpperCase(), new Map<String, DistributorLineItem__c>());
            }
            mapofBrandAnddistributorLineItem
                .get(rec.Division__c)
                .get(rec.Distributor__r.Name.toUpperCase())
                .put(combination, rec);
        }

        for (String key : categoryGroupMap.keySet()) {
            String lastDivision = '';

            for (String str : categoryGroupMap.get(key).keySet()) {
                DivisionCategoryWrapper wrapper = new DivisionCategoryWrapper();
                DistributorLineItem__c firstRow = categoryGroupMap.get(key).get(str);

                wrapper.key = str;
                wrapper.division = firstRow.Division__c;
                wrapper.category = firstRow.Category__c;
                wrapper.productRange = firstRow.Biotech_Product_Range__c;
                wrapper.rowspan = categoryGroupMap.get(key).keySet().size();
                wrapper.showDivision = lastDivision == '' ? true : false;
                lastDivision = 'new';

                wrapper.brandValues = new List<BrandValueWrapper>();

                if (firstRow.Agreement_Product__r != null) {
                    wrapper.agreementPrice = String.valueOf(firstRow.Agreement_Product__r.Price__c);
                    wrapper.agreementFOC   = firstRow.Agreement_Product__r.FOC_Text__c;
                } else {
                    wrapper.agreementPrice = '-';
                    wrapper.agreementFOC   = '-';
                }

                for (String brand : distributorName) {
                    BrandValueWrapper brandval = new BrandValueWrapper();

                    if (mapofBrandAnddistributorLineItem.get(key).containsKey(brand)
                        && mapofBrandAnddistributorLineItem.get(key).get(brand).containsKey(str)
                    ) {
                        DistributorLineItem__c dis = mapofBrandAnddistributorLineItem
                            .get(key).get(brand).get(str);

                        brandval.Brand_Name = dis.Brand_Name__c;
                        brandval.Price_KeyAccounts = String.valueOf(dis.Price_Key_Account__c);
                        brandval.Price_for_Retail = String.valueOf(dis.Price_For_Retail__c);
                        brandval.Total_Package = String.valueOf(dis.Total_Package__c);
                    } else {
                        brandval.Brand_Name = '-';
                        brandval.Price_KeyAccounts = '-';
                        brandval.Price_for_Retail = '-';
                        brandval.Total_Package = '-';
                    }

                    wrapper.brandValues.add(brandval);
                }

                DistributorLineItem__c biotechRow = biotechRowMap.get(str);
                wrapper.biotechData = buildBiotechData(biotechRow);

                finalList.add(wrapper);
            }
        }

        System.debug(finalList);
        return finalList;
    }

    private static BiotechDataWrapper buildBiotechData(DistributorLineItem__c row) {
        BiotechDataWrapper biotech = new BiotechDataWrapper();

        if (row != null) {
            biotech.agreementPrice = row.Agreement_Product__r != null
                                   ? String.valueOf(row.Agreement_Product__r.Price__c)
                                   : '-';
            biotech.foc = row.Agreement_Product__r != null
                        ? row.Agreement_Product__r.FOC_Text__c
                        : '-';

            biotech.endUserPrice = row.End_User_Price_by_Distributor_to_Doctor__c != null
                                  ? String.valueOf(row.End_User_Price_by_Distributor_to_Doctor__c)
                                  : '-';

            biotech.origin = row.Origin__c != null
                           ? row.Origin__c
                           : '-';
        } else {
            biotech.agreementPrice = '-';
            biotech.foc = '-';
            biotech.endUserPrice = '-';
            biotech.origin = '-';
        }

        biotech.customsCharges = '-';
        biotech.landingCost = '-';

        return biotech;
    }
}



/*public without sharing class ShowBiotechCategoryProductRangeHandler {

    public class BiotechDataWrapper {
        @AuraEnabled public String agreementPrice;
        @AuraEnabled public String foc;
        @AuraEnabled public String customsCharges;
        @AuraEnabled public String landingCost;
        @AuraEnabled public String endUserPrice;
        @AuraEnabled public String origin;
    }

    public class BrandValueWrapper {
        @AuraEnabled public String Brand_Name;
        @AuraEnabled public String Price_KeyAccounts;
        @AuraEnabled public String Price_for_Retail;
        @AuraEnabled public String Total_Package;
    }

    public class DivisionCategoryWrapper {
        @AuraEnabled public String key;
        @AuraEnabled public String division;
        @AuraEnabled public String category;
        @AuraEnabled public String productRange;
        @AuraEnabled public Integer rowspan;
        @AuraEnabled public Boolean showDivision;

        // NEW – agreement fields for each row
        @AuraEnabled public String agreementPrice;
        @AuraEnabled public String agreementFOC;

        @AuraEnabled public List<BrandValueWrapper> brandValues;
        @AuraEnabled public BiotechDataWrapper biotechData; 
    }

    @AuraEnabled
    public static List<DivisionCategoryWrapper> getDistributorData(List<Id> distributorIds, List<String> distributorName, String userId) {
        List<DivisionCategoryWrapper> finalList = new List<DivisionCategoryWrapper>();
		Boolean shouldCreateNewVersion = false;

        User currentUser = [SELECT Id, ContactId, Contact.AccountId, Contact.Create_New_Market_X_Ray_Version__c FROM User WHERE Id = :userId LIMIT 1];

        if (currentUser.ContactId == null) {
            throw new AuraHandledException('This user is not associated with a Contact.');
        }

		if (currentUser.ContactId != null) {
            Contact con = [SELECT Create_New_Market_X_Ray_Version__c FROM Contact WHERE Id = :currentUser.ContactId LIMIT 1];
            shouldCreateNewVersion = con.Create_New_Market_X_Ray_Version__c;
        }

        List<Market_X_Ray_Form__c> forms = [SELECT Id, IsMarketXrayFormEditable__c FROM Market_X_Ray_Form__c WHERE Contact__c = :currentUser.ContactId ORDER BY CreatedDate DESC LIMIT 1];

		//Boolean shouldCreateNewVersion = currentUser.Contact.Create_New_Market_X_Ray_Version__c;
		System.debug('formsjefguiqregiugefhvoig'+forms.size());
	    System.debug('shouldCreateNewVersion'+shouldCreateNewVersion);
        //System.debug('forms[0].IsMarketXrayFormEditable__c'+forms[0].IsMarketXrayFormEditable__c);
		if (forms.isEmpty()) {
            return finalList;
        }
      
        

        if (shouldCreateNewVersion && !forms.isEmpty() && forms[0].IsMarketXrayFormEditable__c == true) {
            return finalList;
        }
        System.debug('finalList'+finalList);

        Id formId = forms[0].Id;
        System.debug('formId'+formId);

        List<DistributorLineItem__c> lineItems = [SELECT Id, Division__c, Category__c,Biotech_Product_Range__c,Brand_Name__c,Total_Package__c,
                   								  Price_Key_Account__c,Agreement_Product__r.FOC_Text__c,Agreement_Product__r.Price__c,
                                                  End_User_Price_by_Distributor_to_Doctor__c, Price_For_Retail__c, Origin__c, Distributor__r.Name
                                                  FROM DistributorLineItem__c WHERE Distributor__c IN :distributorIds AND Market_X_Ray_Form__c = :formId
           										  ORDER BY Division__c, Category__c];

        System.debug('lineItems=======>>>>>'+ lineItems);

        // ------------ CHANGE 1: Build bioTech row map by combination -------------
        Map<String, DistributorLineItem__c> biotechRowMap = new Map<String, DistributorLineItem__c>();
        for (DistributorLineItem__c rec : lineItems) {
            String comb = rec.Division__c + rec.Biotech_Product_Range__c + rec.Category__c;
            if (rec.Distributor__r.Name == 'Biotech') {
                biotechRowMap.put(comb, rec);
            }
        }

        Map<String, Map<String, DistributorLineItem__c>> categoryGroupMap = new Map<String, Map<String, DistributorLineItem__c>>();
        Map<String, Map<String, Map<String, DistributorLineItem__c>>> mapofBrandAnddistributorLineItem = new Map<String, Map<String, Map<String, DistributorLineItem__c>>>();

        for (DistributorLineItem__c rec : lineItems) {
            String combination = rec.Division__c + rec.Biotech_Product_Range__c + rec.Category__c;

            if (!categoryGroupMap.containsKey(rec.Division__c)) {
                categoryGroupMap.put(rec.Division__c, new Map<String, DistributorLineItem__c>());
            }
            categoryGroupMap.get(rec.Division__c).put(combination, rec);

            if (!mapofBrandAnddistributorLineItem.containsKey(rec.Division__c)) {
                mapofBrandAnddistributorLineItem.put(
                    rec.Division__c,
                    new Map<String, Map<String, DistributorLineItem__c>>()
                );
            }
            if (!mapofBrandAnddistributorLineItem.get(rec.Division__c).containsKey(rec.Distributor__r.Name.toUpperCase())) {
                mapofBrandAnddistributorLineItem
                    .get(rec.Division__c)
                    .put(rec.Distributor__r.Name.toUpperCase(), new Map<String, DistributorLineItem__c>());
            }
            mapofBrandAnddistributorLineItem
                .get(rec.Division__c)
                .get(rec.Distributor__r.Name.toUpperCase())
                .put(combination, rec);
        }

        for (String key : categoryGroupMap.keySet()) {
            String lastDivision = '';

            for (String str : categoryGroupMap.get(key).keySet()) {
                DivisionCategoryWrapper wrapper = new DivisionCategoryWrapper();
                DistributorLineItem__c firstRow = categoryGroupMap.get(key).get(str);

                wrapper.key = str;
                wrapper.division = firstRow.Division__c;
                wrapper.category = firstRow.Category__c;
                wrapper.productRange = firstRow.Biotech_Product_Range__c;
                wrapper.rowspan = categoryGroupMap.get(key).keySet().size();
                wrapper.showDivision = lastDivision == '' ? true : false;
                lastDivision = 'new';

                wrapper.brandValues = new List<BrandValueWrapper>();

                // --- populate AGREEMENT fields for THIS product row
                if (firstRow.Agreement_Product__r != null) {
                    wrapper.agreementPrice = String.valueOf(firstRow.Agreement_Product__r.Price__c);
                    wrapper.agreementFOC   = firstRow.Agreement_Product__r.FOC_Text__c;
                } else {
                    wrapper.agreementPrice = '-';  // no agreement product
                    wrapper.agreementFOC   = '-';
                }

                for (String brand : distributorName) {
                    BrandValueWrapper brandval = new BrandValueWrapper();

                    if ( mapofBrandAnddistributorLineItem.get(key).containsKey(brand)
                        && mapofBrandAnddistributorLineItem.get(key).get(brand).containsKey(str)
                    ) {
                        DistributorLineItem__c dis = mapofBrandAnddistributorLineItem
                            .get(key).get(brand).get(str);

                        brandval.Brand_Name = dis.Brand_Name__c;
                        brandval.Price_KeyAccounts = String.valueOf(dis.Price_Key_Account__c);
                        brandval.Price_for_Retail = String.valueOf(dis.Price_For_Retail__c);
                        brandval.Total_Package = String.valueOf(dis.Total_Package__c);
                    } else {
                        brandval.Brand_Name = '-';
                        brandval.Price_KeyAccounts = '-';
                        brandval.Price_for_Retail = '-';
                        brandval.Total_Package = '-';
                    }

                    wrapper.brandValues.add(brandval);
                }

                // ------------ CHANGE 2: Use biotechRowMap for correct End User Price ------------
                DistributorLineItem__c biotechRow = biotechRowMap.get(str);
                wrapper.biotechData = buildBiotechData(biotechRow);

                finalList.add(wrapper);
            }
        }
        system.debug(finalList);

        return finalList;
    }

    private static BiotechDataWrapper buildBiotechData(DistributorLineItem__c row) {
        BiotechDataWrapper biotech = new BiotechDataWrapper();

        // ------------ CHANGE 3: Safely handle null Biotech row -------------
        if (row != null) {
            biotech.agreementPrice = row.Agreement_Product__r != null
                                   ? String.valueOf(row.Agreement_Product__r.Price__c)
                                   : '-';
            biotech.foc = row.Agreement_Product__r != null
                        ? row.Agreement_Product__r.FOC_Text__c
                        : '-';

            // This now prints correct end user price for that product
            biotech.endUserPrice = row.End_User_Price_by_Distributor_to_Doctor__c != null
                                  ? String.valueOf(row.End_User_Price_by_Distributor_to_Doctor__c)
                                  : '-';

            biotech.origin = row.Origin__c != null
                           ? row.Origin__c
                           : '-';
        } else {
            biotech.agreementPrice = '-';
            biotech.foc = '-';
            biotech.endUserPrice = '-';  // no biotech data
            biotech.origin = '-';
        }

        biotech.customsCharges = '-';
        biotech.landingCost = '-';

        return biotech;
    }
}*/