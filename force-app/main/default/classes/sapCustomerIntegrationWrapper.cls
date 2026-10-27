global class sapCustomerIntegrationWrapper {
    
    global List<Request> records;
    
    global class Request {
        public String customer;
        public String Name;
        
        public String customerCity;
        public String businessCode;
        public String verticalCode;
        public String divisionCode;
        public String zoneCode;
        public String stateCode;
        public String salesDistrict;
        public String businessName;
        public String countryKey;
        public String verticalName;
        public String divisionName;
        public String zoneName;
        public String stateName;
        public String districtName;
        
        public String assignmentExternalId;
        public Boolean Active;
        
        public List<Hierarchy> hierarchies;
    }
    
    global class Hierarchy {
        public String hierarchyExternalId;
        public String hierarchyName;
        public Boolean isActive;
        public String countryKey;
        public String divisionName;
        public String subdivision;
        public String zoneName;
        
        //RLS fields
        public String bdmempid;
        public String bdm;
        public String bdmlevel;
        public String cmempid;
        public String cm;
        public String cmlevel;
        public String dmempid;
        public String dm;
        public String dmlevel;
        public String gmempid;
        public String gm;
        public String gmlevel;
        public String gsroempid;
        public String gsro;
        public String gsrolevel;
        public String kamempid;
        public String kam;
        public String kamlevel;
        public String nsmempid;
        public String nsm;
        public String nsmlevel;
        public String rmempid;
        public String rm;
        public String rmlevel;
        public String rsmempid;
        public String rsm;
        public String rsmlevel;
        public String Saeempid;
        public String sae;
        public String saelevel;
        public String sdeempid;
        public String sde;
        public String sdelevel;
        public String sseempid;
        public String sse;
        public String sselevel;
        public String tmempid;
        public String tm;
        public String tmlevel;
        public String zsmempid;
        public String zsm;
        public String zsmlevel;
        public Boolean customerMapping;
        public Boolean businessMapping;
    }
    
    global class Response {
        public Boolean success;
        public String message;
        public List<Result> results;
    }
    
    global class Result {
        public String sapCustomerexternalId;
        public Id accountId;
        public String operation;
        public String status;
        public String message;
        public List<AssignmentResult> assignments;
        public List<HierarchyResult> hierarchies;
    }
    
    global class AssignmentResult {
        public String assignmentexternalId;
        public Id recordId;
        public String status;
        public String message;
        public String assignmentoperation; // ADD THIS
    }
    
    global class HierarchyResult {
        public String hierarchyexternalId;
        public Id recordId;
        public String status;
        public String message;
        public String hierarchyoperation; // ADD THIS
    }
}