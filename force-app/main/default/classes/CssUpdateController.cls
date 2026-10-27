public class CssUpdateController {

    public static void updateCssInFields(String objectApiName, List<String> fieldNames, String targetString, String newCss) {
        String soqlQuery = 'SELECT Id, ' + String.join(fieldNames, ', ') + ' FROM ' + objectApiName;

        List<sObject> records = Database.query(soqlQuery);

        List<sObject> recordsToUpdate = new List<sObject>();

        for (sObject record : records) {
            for (String fieldName : fieldNames) {
                if (record.get(fieldName) != null) {
                    String fieldValue = (String) record.get(fieldName);
                    if (fieldValue.contains(targetString)) {
                        String escapedTargetString = Pattern.quote(targetString);
                        String updatedFieldValue = fieldValue.replaceAll(escapedTargetString, '<span style="' + newCss + '">' + targetString + '</span>');
                        record.put(fieldName, updatedFieldValue);
                        recordsToUpdate.add(record);
                    }
                }
            }
        }

        if (!recordsToUpdate.isEmpty()) {
            Database.update(recordsToUpdate, false); // false for partial success
        }
    }
}