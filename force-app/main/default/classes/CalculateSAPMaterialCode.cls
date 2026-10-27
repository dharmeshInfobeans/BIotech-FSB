public class CalculateSAPMaterialCode {

    private static final String INTERNATIONAL_STRING = 'International';
    private static final String PHAKIC_STRING = 'PHAKIC';
    private static final String TORIC_STRING = 'TORIC';

    /**
     * Processes all Order Products for a given Order Id and returns a map of Order_Product__c Id to material code.
     */
    public static Map<Id, String> processOrderProductsByOrderId(Id orderId) {
        Map<Id, String> modeltostockMap = new Map<Id, String>();
        Map<Id, String> searchedMaterialCode = new Map<Id, String>();
        Set<Id> productWithoutStockIdSet = new Set<Id>();

        if (orderId == null) {
            return modeltostockMap;
        }

        // 1️⃣ Fetch all order products for the given order
        List<Order_Product__c> opList = [
            SELECT Id, Name, Product__c, Model_Txt__c, Spherical_Power__c, 
                   Cyindrical_Power__c, Axis_Angle__c
            FROM Order_Product__c
            WHERE Order__c = :orderId
        ];

        if (opList.isEmpty()) {
            return modeltostockMap;
        }

        // 2️⃣ Collect Product IDs and Model Names
        Set<Id> productIdSet = new Set<Id>();
        Set<String> modelNameSet = new Set<String>();
        for (Order_Product__c op : opList) {
            if (!String.isEmpty(op.Model_Txt__c)) modelNameSet.add(op.Model_Txt__c);
            if (op.Product__c != null) productIdSet.add(op.Product__c);
        }

        // 3️⃣ Query Product__c with Material Stocks
        Map<Id, Product__c> productStockMap = new Map<Id, Product__c>(
            [SELECT Id, Name, Dummy_Product_Code__c, Region__c,
                    (SELECT Id, Plant__c, Material_Code__c, Quantity__c, Product_Models__c
                     FROM Product_Material_Stocks__r
                     WHERE IsActive__c = TRUE
                     ORDER BY LastModifiedDate DESC)
             FROM Product__c
             WHERE Id IN :productIdSet]
        );

        // 4️⃣ Query Product_Model__c with Material Stocks
        List<Product_Model__c> modelStockList = [
            SELECT Id, Name, Product__c, Product__r.Dummy_Product_Code__c, Text_Name__c,
                   (SELECT Id, Plant__c, Material_Code__c, Quantity__c, Product_Id__c
                    FROM Product_Material_Stocks__r
                    WHERE IsActive__c = TRUE
                    ORDER BY LastModifiedDate DESC)
            FROM Product_Model__c
            WHERE Text_Name__c IN :modelNameSet
              AND Product__c IN :productIdSet
        ];

        Map<String, List<Product_Material_Stock__c>> modelStockMap = new Map<String, List<Product_Material_Stock__c>>();
        for (Product_Model__c modelObj : modelStockList) {
            modelStockMap.put(modelObj.Text_Name__c, modelObj.Product_Material_Stocks__r);
        }

        // 5️⃣ Main processing logic
        for (Order_Product__c orderProduct : opList) {
            Product__c relatedProduct = productStockMap.get(orderProduct.Product__c);

            List<Product_Material_Stock__c> stockList = new List<Product_Material_Stock__c>();
            if (!String.isEmpty(orderProduct.Model_Txt__c)) {
                stockList = modelStockMap.get(orderProduct.Model_Txt__c);
            } else if (relatedProduct != null) {
                stockList = relatedProduct.Product_Material_Stocks__r;
            }

            String materialCodeMatch = '';

            if (stockList != null && !stockList.isEmpty() && stockList.size() > 1) {
                if (orderProduct.Spherical_Power__c != null) {
                    String sphericalPowerStr = String.valueOf(orderProduct.Spherical_Power__c);
                    String cylindricalPowerStr = String.valueOf(orderProduct.Cyindrical_Power__c);
                    String axisAngleStr = String.valueOf(orderProduct.Axis_Angle__c);

                    if (sphericalPowerStr != null && relatedProduct != null) {
                        String partialPower = '';
                        String initPower;

                        Boolean isPhakicToric = relatedProduct.Name != null 
                            && relatedProduct.Name.toUpperCase().contains(PHAKIC_STRING)
                            && relatedProduct.Name.toUpperCase().contains(TORIC_STRING)
                            && relatedProduct.Region__c == INTERNATIONAL_STRING;

                        if (sphericalPowerStr.contains('-')) {
                            partialPower = sphericalPowerStr.substringBetween('-', '.');
                            initPower = partialPower;
                            partialPower = partialPower.length() == 1 && isPhakicToric ? '0' + partialPower : partialPower;
                            partialPower = 'N' + partialPower;
                            sphericalPowerStr = sphericalPowerStr.replaceFirst(initPower, partialPower).replace('-', '');
                        } else {
                            partialPower = sphericalPowerStr.substringBeforeLast('.');
                            initPower = partialPower;
                            partialPower = partialPower.length() == 1 && isPhakicToric ? '0' + partialPower : partialPower;
                            partialPower = 'P' + partialPower;
                            sphericalPowerStr = sphericalPowerStr.replaceFirst(initPower, partialPower);
                        }
                        materialCodeMatch = sphericalPowerStr;
                    }

                    if (relatedProduct != null 
                        && relatedProduct.Dummy_Product_Code__c != 'EP262'  
                        && relatedProduct.Dummy_Product_Code__c != 'EP263') {

                        if (cylindricalPowerStr != null) {
                            if (axisAngleStr != null || relatedProduct.Dummy_Product_Code__c == 'EP266') {
                                cylindricalPowerStr = cylindricalPowerStr.replace('.', '');
                                cylindricalPowerStr = cylindricalPowerStr.length() == 1 ? cylindricalPowerStr + '00' : cylindricalPowerStr;
                                materialCodeMatch += 'C0' + cylindricalPowerStr;
                            } else {
                                cylindricalPowerStr = cylindricalPowerStr.length() == 1 ? cylindricalPowerStr + '.00' : cylindricalPowerStr;
                                materialCodeMatch += 'C' + cylindricalPowerStr;
                            }
                        }
                        if (axisAngleStr != null) {
                            String initAxis = '';
                            axisAngleStr = 'A' + axisAngleStr;
                            axisAngleStr = axisAngleStr.substringBefore('0');
                            initAxis = axisAngleStr.substringAfter('A');
                            axisAngleStr = axisAngleStr.length() == 2 ? 'A0' + initAxis : (axisAngleStr.length() == 1 ? 'A00' : axisAngleStr);
                            materialCodeMatch += axisAngleStr;
                        }
                    }

                    searchedMaterialCode.put(orderProduct.Id, materialCodeMatch);

                    for (Product_Material_Stock__c stock : stockList) {
                        if (stock.Material_Code__c.contains(materialCodeMatch)) {
                            modeltostockMap.put(orderProduct.Id, stock.Material_Code__c);
                            break;
                        } else if (relatedProduct != null) {
                            modeltostockMap.put(orderProduct.Id, relatedProduct.Dummy_Product_Code__c);
                            productWithoutStockIdSet.add(orderProduct.Id);
                        }
                    }

                } else {
                    modeltostockMap.put(orderProduct.Id, stockList[0].Material_Code__c);
                }
            } else if (stockList == null || stockList.isEmpty()) {
                if (relatedProduct != null) {
                    modeltostockMap.put(orderProduct.Id, relatedProduct.Dummy_Product_Code__c);
                }
                productWithoutStockIdSet.add(orderProduct.Id);
            } else {
                modeltostockMap.put(orderProduct.Id, stockList[0].Material_Code__c);
            }

            if (!modeltostockMap.containsKey(orderProduct.Id) && stockList != null && !stockList.isEmpty()) {
                modeltostockMap.put(orderProduct.Id, stockList[0].Material_Code__c);
            }
        }

        return modeltostockMap;
    }


}