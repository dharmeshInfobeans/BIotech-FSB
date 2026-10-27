public class LeadFormController {
    
    @AuraEnabled
    public static AccountContactData getAccountWithContacts(String accountId) {
        try {
            Account acc = [
                SELECT Id, Name, Phone, Website, BillingStreet, BillingCity, 
                       BillingState, BillingPostalCode, BillingCountry, Industry,
                       AnnualRevenue, NumberOfEmployees
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];
            
            List<Contact> contacts = [
                SELECT Id, FirstName, LastName, Email, Phone, MobilePhone, Title,
                       MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry
                FROM Contact
                WHERE AccountId = :accountId
                ORDER BY LastName, FirstName
                LIMIT 10
            ];
            
            AccountContactData data = new AccountContactData();
            data.account = acc;
            data.contacts = contacts;
            
            return data;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching account data: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static AccountContactData getContactWithAccount(String contactId) {
        try {
            Contact con = [
                SELECT Id, FirstName, LastName, Email, Phone, MobilePhone, Title,
                       AccountId, Account.Name, Account.Phone, Account.Website,
                       Account.BillingStreet, Account.BillingCity, Account.BillingState,
                       Account.BillingPostalCode, Account.BillingCountry, Account.Industry,
                       Account.AnnualRevenue, Account.NumberOfEmployees,
                       MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry
                FROM Contact
                WHERE Id = :contactId
                LIMIT 1
            ];
            
            AccountContactData data = new AccountContactData();
            data.contact = con;
            if (con.AccountId != null) {
                data.account = con.Account;
            }
            
            return data;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching contact data: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<SearchResult> searchAccountsContacts(String searchTerm) {
        List<SearchResult> results = new List<SearchResult>();
        
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return results;
        }
        
        String searchQuery = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        
        try {
            // Search Accounts
            List<Account> accounts = [
                SELECT Id, Name, Phone, Website, BillingStreet, BillingCity, 
                       BillingState, BillingPostalCode, BillingCountry, Industry,
                       AnnualRevenue, NumberOfEmployees
                FROM Account
                WHERE Name LIKE :searchQuery
                ORDER BY Name
                LIMIT 10
            ];
            
            for (Account acc : accounts) {
                SearchResult sr = new SearchResult();
                sr.Id = acc.Id;
                sr.Name = acc.Name;
                sr.Type = 'Account';
                sr.Details = acc.Phone != null ? 'Phone: ' + acc.Phone : '';
                sr.Record = acc;
                results.add(sr);
            }
            
            // Search Contacts
            List<Contact> contacts = [
                SELECT Id, FirstName, LastName, Email, Phone, MobilePhone, Title, 
                       Account.Name, MailingStreet, MailingCity, MailingState, 
                       MailingPostalCode, MailingCountry
                FROM Contact
                WHERE FirstName LIKE :searchQuery 
                   OR LastName LIKE :searchQuery
                   OR Email LIKE :searchQuery
                ORDER BY LastName, FirstName
                LIMIT 10
            ];
            
            for (Contact con : contacts) {
                SearchResult sr = new SearchResult();
                sr.Id = con.Id;
                sr.Name = (con.FirstName != null ? con.FirstName + ' ' : '') + (con.LastName != null ? con.LastName : '');
                sr.Type = 'Contact';
                sr.Details = con.Email != null ? 'Email: ' + con.Email : '';
                sr.Record = con;
                results.add(sr);
            }
            
        } catch (Exception e) {
            throw new AuraHandledException('Error searching: ' + e.getMessage());
        }
        
        return results;
    }
    
    @AuraEnabled
    public static String createLead(Map<String, Object> leadData) {
        if (leadData == null || leadData.isEmpty()) {
            throw new AuraHandledException('Lead data is required');
        }
        
        Scorecard_Lead__c newLead = new Scorecard_Lead__c();
        
        try {
            // Map fields that exist on Scorecard_Lead__c
            // Basic Information
            newLead.FirstName__c = (String) leadData.get('FirstName');
            newLead.LastName__c = (String) leadData.get('LastName');
            newLead.Email__c = (String) leadData.get('Email');
            newLead.Mobile__c = (String) leadData.get('MobilePhone'); // Map MobilePhone to Mobile__c
            newLead.Company__c = (String) leadData.get('Company');
            newLead.Name = newLead.FirstName__c + ' ' + newLead.LastName__c;
            // Address Information
            newLead.Street__c = (String) leadData.get('Street');
            newLead.City__c = (String) leadData.get('City');
            newLead.PostalCode__c = (String) leadData.get('PostalCode');
            newLead.Country__c = (String) leadData.get('Country');
            newLead.Region__c = (String) leadData.get('Region');
            newLead.Title__c = (String) leadData.get('Title');
            // Region field
            // if (leadData.get('Region') != null) {
            //     try {
            //         newLead.put('Region__c', (String) leadData.get('Region'));
            //     } catch (Exception e) {
            //         system.debug('Region__c field not found on Scorecard_Lead__c: ' + e.getMessage());
            //     }
            // }
            
            // Additional fields (these need to be created on Scorecard_Lead__c if not exist)
            // Phone field - if Phone__c exists
            if (leadData.get('Phone') != null) {
                try {
                   // newLead.put('Phone__c', (String) leadData.get('Phone'));
                } catch (Exception e) {
                    // Field doesn't exist, skip
                    system.debug('Phone__c field not found on Scorecard_Lead__c: ' + e.getMessage());
                }
            }
            
            // Title field - if Title__c exists
            // if (leadData.get('Title') != null) {
            //     try {
            //         newLead.put('Title__c', (String) leadData.get('Title'));
            //     } catch (Exception e) {
            //         system.debug('Title__c field not found on Scorecard_Lead__c: ' + e.getMessage());
            //     }
            // }
            
            // Website field - if Website__c exists
            if (leadData.get('Website') != null) {
                try {
                    newLead.put('Website__c', (String) leadData.get('Website'));
                } catch (Exception e) {
                    system.debug('Website__c field not found on Scorecard_Lead__c: ' + e.getMessage());
                }
            }
            
            // State field - if State__c exists
            if (leadData.get('State') != null) {
                try {
                    newLead.put('State__c', (String) leadData.get('State'));
                } catch (Exception e) {
                    system.debug('State__c field not found on Scorecard_Lead__c: ' + e.getMessage());
                }
            }
            
            // LeadSource field - if LeadSource__c exists
            if (leadData.get('LeadSource') != null) {
                try {
                    newLead.put('LeadSource__c', (String) leadData.get('LeadSource'));
                } catch (Exception e) {
                    system.debug('LeadSource__c field not found on Scorecard_Lead__c: ' + e.getMessage());
                }
            }
            
            // Status field - if Status__c exists
            if (leadData.get('Status') != null) {
                try {
                    system.debug('Status__c field : ' +(String) leadData.get('Status'));
                    newLead.put('Status__c', (String) leadData.get('Status'));
                } catch (Exception e) {
                    system.debug('Status__c field not found on Scorecard_Lead__c: ' + e.getMessage());
                }
            }
            
            // Industry field - if Industry__c exists
            if (leadData.get('Industry') != null) {
                try {
                    newLead.put('Industry__c', (String) leadData.get('Industry'));
                } catch (Exception e) {
                    system.debug('Industry__c field not found on Scorecard_Lead__c: ' + e.getMessage());
                }
            }
            
            // Description field - if Description__c exists
            if (leadData.get('Description') != null) {
                try {
                    newLead.put('Description__c', (String) leadData.get('Description'));
                } catch (Exception e) {
                    system.debug('Description__c field not found on Scorecard_Lead__c: ' + e.getMessage());
                }
            }
            
            // AnnualRevenue field - if AnnualRevenue__c exists
            if (leadData.get('AnnualRevenue') != null) {
                try {
                    newLead.put('AnnualRevenue__c', (Decimal) leadData.get('AnnualRevenue'));
                } catch (Exception e) {
                    system.debug('AnnualRevenue__c field not found on Scorecard_Lead__c: ' + e.getMessage());
                }
            }
            
            // NumberOfEmployees field - if NumberOfEmployees__c exists
            if (leadData.get('NumberOfEmployees') != null) {
                try {
                    newLead.put('Number_Of_Employees__c', (Integer) leadData.get('NumberOfEmployees'));
                } catch (Exception e) {
                    system.debug('Number_Of_Employees__c field not found on Scorecard_Lead__c: ' + e.getMessage());
                }
            }
            
            // Validate required fields
            if (String.isBlank(newLead.LastName__c)) {
                throw new AuraHandledException('Last Name is required');
            }
            if (String.isBlank(newLead.Company__c)) {
                throw new AuraHandledException('Company is required');
            }
            
            // Validate that Region_Approver__c record exists for the selected region
            if (String.isNotBlank(newLead.Region__c)) {
                List<Region_Approver__c> regionApprovers = [
                    SELECT Id, Region__c, Approver_1__c
                    FROM Region_Approver__c 
                    WHERE Region__c = :newLead.Region__c 
                    LIMIT 1
                ];
                
                if (regionApprovers.isEmpty()) {
                    throw new AuraHandledException('Scorecard is not configured for the selected region. Please contact admin.');
                }
            } else {
                throw new AuraHandledException('Region is required to create a Scorecard Lead.');
            }
            
            insert newLead;
            return newLead.Id;
            
        } catch (AuraHandledException e) {
            // Re-throw AuraHandledException as-is to preserve the original error message
            throw e;
        } catch (DmlException e) {
            throw new AuraHandledException('Error creating Scorecard Lead: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException('Error creating Scorecard Lead: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getLeadPicklistValues() {
        Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();
        
        try {
            // Get picklist values from Scorecard_Lead__c custom fields
            // Use try-catch for each field in case they don't exist yet
            Schema.DescribeSObjectResult leadObj = Scorecard_Lead__c.sObjectType.getDescribe();
            Map<String, Schema.SObjectField> fieldMap = leadObj.fields.getMap();
            
             List<Map<String, String>> leadCountryOptions = new List<Map<String, String>>();
              if (fieldMap.containsKey('Country__c')) {
                Schema.DescribeFieldResult countryField = fieldMap.get('Country__c').getDescribe();
                if (countryField.getType() == Schema.DisplayType.PICKLIST) {
                    for (Schema.PicklistEntry entry : countryField.getPicklistValues()) {
                        if (entry.isActive()) {
                            leadCountryOptions.add(new Map<String, String>{
                                'label' => entry.getLabel(),
                                'value' => entry.getValue()
                            });
                        }
                    }
                }
            }
            // LeadSource picklist
            List<Map<String, String>> leadSourceOptions = new List<Map<String, String>>();
            if (fieldMap.containsKey('LeadSource__c')) {
                Schema.DescribeFieldResult leadSourceField = fieldMap.get('LeadSource__c').getDescribe();
                if (leadSourceField.getType() == Schema.DisplayType.PICKLIST) {
                    for (Schema.PicklistEntry entry : leadSourceField.getPicklistValues()) {
                        if (entry.isActive()) {
                            leadSourceOptions.add(new Map<String, String>{
                                'label' => entry.getLabel(),
                                'value' => entry.getValue()
                            });
                        }
                    }
                }
            } else {
                // Fallback: Use standard Lead picklist values if custom field doesn't exist
                // Schema.DescribeFieldResult standardLeadSourceField = Lead.LeadSource.getDescribe();
                // for (Schema.PicklistEntry entry : standardLeadSourceField.getPicklistValues()) {
                //     if (entry.isActive()) {
                //         leadSourceOptions.add(new Map<String, String>{
                //             'label' => entry.getLabel(),
                //             'value' => entry.getValue()
                //         });
                //     }
                // }
            }
            
            // Status picklist
            List<Map<String, String>> statusOptions = new List<Map<String, String>>();
            if (fieldMap.containsKey('Status__c')) {
                Schema.DescribeFieldResult statusField = fieldMap.get('Status__c').getDescribe();
                if (statusField.getType() == Schema.DisplayType.PICKLIST) {
                    for (Schema.PicklistEntry entry : statusField.getPicklistValues()) {
                        if (entry.isActive()) {
                            statusOptions.add(new Map<String, String>{
                                'label' => entry.getLabel(),
                                'value' => entry.getValue()
                            });
                        }
                    }
                }
            } else {
                // Fallback: Use standard Lead picklist values if custom field doesn't exist
                // Schema.DescribeFieldResult standardStatusField = Lead.Status.getDescribe();
                // for (Schema.PicklistEntry entry : standardStatusField.getPicklistValues()) {
                //     if (entry.isActive()) {
                //         statusOptions.add(new Map<String, String>{
                //             'label' => entry.getLabel(),
                //             'value' => entry.getValue()
                //         });
                //     }
                // }
            }
            
            // Industry picklist
            List<Map<String, String>> industryOptions = new List<Map<String, String>>();
            if (fieldMap.containsKey('Industry__c')) {
                Schema.DescribeFieldResult industryField = fieldMap.get('Industry__c').getDescribe();
                if (industryField.getType() == Schema.DisplayType.PICKLIST) {
                    for (Schema.PicklistEntry entry : industryField.getPicklistValues()) {
                        if (entry.isActive()) {
                            industryOptions.add(new Map<String, String>{
                                'label' => entry.getLabel(),
                                'value' => entry.getValue()
                            });
                        }
                    }
                }
            } else {
                // Fallback: Use standard Lead picklist values if custom field doesn't exist
                // Schema.DescribeFieldResult standardIndustryField = Lead.Industry.getDescribe();
                // for (Schema.PicklistEntry entry : standardIndustryField.getPicklistValues()) {
                //     if (entry.isActive()) {
                //         industryOptions.add(new Map<String, String>{
                //             'label' => entry.getLabel(),
                //             'value' => entry.getValue()
                //         });
                //     }
                // }
            }
            
            // Region picklist
            List<Map<String, String>> regionOptions = new List<Map<String, String>>();
            if (fieldMap.containsKey('Region__c')) {
                Schema.DescribeFieldResult regionField = fieldMap.get('Region__c').getDescribe();
                if (regionField.getType() == Schema.DisplayType.PICKLIST) {
                    for (Schema.PicklistEntry entry : regionField.getPicklistValues()) {
                        if (entry.isActive()) {
                            regionOptions.add(new Map<String, String>{
                                'label' => entry.getLabel(),
                                'value' => entry.getValue()
                            });
                        }
                    }
                }
            }
            
            result.put('leadSourceOptions', leadSourceOptions);
            result.put('leadCountryOptions', leadCountryOptions);
            result.put('statusOptions', statusOptions);
            result.put('industryOptions', industryOptions);
            result.put('regionOptions', regionOptions);
            
        } catch (Exception e) {
            throw new AuraHandledException('Error loading picklist values: ' + e.getMessage());
        }
        
        return result;
    }
    
    public class SearchResult {
        @AuraEnabled public String Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String Type;
        @AuraEnabled public String Details;
        @AuraEnabled public SObject Record;
    }
    
    public class AccountContactData {
        @AuraEnabled public Account account;
        @AuraEnabled public Contact contact;
        @AuraEnabled public List<Contact> contacts;
    }
}