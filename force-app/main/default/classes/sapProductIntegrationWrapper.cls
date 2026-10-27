public class sapProductIntegrationWrapper {
    
    public String status;
    public Summary summary;
    public List<SuccessDetail> successes;
    public List<ErrorDetail> errors = new List<ErrorDetail>();
    
    
     public class Summary {
        public Integer totalHeaders = 0;
        public Integer successfulHeaders = 0;
        public Integer failedHeaders = 0;
        public Integer totalLines = 0;
        public Integer successfulLines = 0;
        public Integer failedLines = 0;
    }
    
    public class SuccessDetail {
        public String level; 
        public String externalId;
        public Id recordId;
        public String operation; 
    }

    public class ErrorDetail {
        public String level;
        public String headerExternalId;
        public String lineExternalId;
        public String objectName;
        public String message;
    }
    
    public class MainWrapper {
        public List<RecordWrapper> records;
    }
    
    public class RecordWrapper {
        
        // Header Fields
        public String groupName;
        public String vertical;
        public String productFamily; 
        public String brand;
        public String category;
        public String subCategory;
        public Boolean activeheader; 
        public String headerExternalId;
        public String addition1;
        public String addition2;
        public String addition3;
        public String addition4;
        public String addition5;
        
        public List<LineWrapper> lines;
    }
    
    public class LineWrapper {
        
        public String productCode;
        public String country;
        public String language;
        public Boolean activeline;
        public String productFamilyLine;
        public String currency1;
        public String verticalLine;
        public String groupNameLine;
        public String brandLine;
        public String categoryLine;
        public String subCategoryLine;
        public String division;
        public Decimal axis;
        public Decimal cylinderPower;
        public Decimal diaptor;
        public String hydrophilicSize;
        public String sphericalPower;
        public String dummyProductCode;
        public String groupDescription;
        public String dummyProductDescription;
        public String originalProductDescription;
        public String lineExternalId;
        public String addition1;
        public String addition2;
        public String addition3;
        public String addition4;
        public String addition5;
    }
}