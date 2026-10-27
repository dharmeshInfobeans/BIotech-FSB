public class CountFOCPercentage {
    
    public class Percent {
        @InvocableVariable
        public Decimal percentage;
        
        public Percent(Decimal percentage) {
            this.percentage = percentage;
        }
    }
    
    @InvocableMethod(label = 'Calculate FOC Percent' description = 'Count the FOC Percent' category = 'Order_Product__c')
    public static List<Percent> calculateFOCPercentage(List<Request> requests) {
        List<Percent> results = new List<Percent>();
        
        for (Request req : requests) {
            String focText = req.focText;
            Decimal quantity = req.quantity;
            
            // Null and empty check for focText and quantity
            if (String.isBlank(focText) || quantity == null) {
                results.add(new Percent(null));
                continue;
            }
            
            // Check if focText is a simple percentage using regex
            Pattern simplePercentagePattern = Pattern.compile('^\\d+%$');
            Matcher simplePercentageMatcher = simplePercentagePattern.matcher(focText);
            if (simplePercentageMatcher.matches()) {
                try {
                    Decimal percentage = Decimal.valueOf(focText.replace('%', ''));
                    results.add(new Percent(percentage));
                } catch (System.TypeException e) {
                    System.debug('Invalid percentage value: ' + focText);
                    results.add(new Percent(null));
                }
                break; // Move to the next request
            } else {
                // Process ranges
                String[] rangeData = focText.replaceAll('FOC ', '').split(', ');
                
                Boolean discountFound = false;
                
                for (String entry : rangeData) {
                    entry = entry.trim();
                    
                    // Use regular expressions to parse the range and discount
                    Pattern rangePattern = Pattern.compile('(\\d+)-(\\d+) Pcs\\) - (\\d+)%');
                    Matcher rangeMatcher = rangePattern.matcher(entry);
                    if (rangeMatcher.find()) {
                        try {
                            Decimal minRange = Decimal.valueOf(rangeMatcher.group(1));
                            Decimal maxRange = Decimal.valueOf(rangeMatcher.group(2));
                            Decimal discount = Decimal.valueOf(rangeMatcher.group(3));
                            
                            if (quantity >= minRange && quantity <= maxRange) {
                                results.add(new Percent(discount));
                                discountFound = true;
                                break;
                            }
                        } catch (System.TypeException e) {
                            System.debug('Invalid range or discount value: ' + entry);
                        }
                    } else if (entry.contains('Above')) {
                        Pattern abovePattern = Pattern.compile('(\\d+) & Above Pcs\\) - (\\d+)%');
                        Matcher aboveMatcher = abovePattern.matcher(entry);
                        if (aboveMatcher.find()) {
                            try {
                                Decimal minRange = Decimal.valueOf(aboveMatcher.group(1));
                                Decimal discount = Decimal.valueOf(aboveMatcher.group(2));
                                
                                if (quantity >= minRange) {
                                    results.add(new Percent(discount));
                                    discountFound = true;
                                    break;
                                }
                            } catch (System.TypeException e) {
                                System.debug('Invalid above range or discount value: ' + entry);
                            }
                        }
                    }
                }
                if (!discountFound) {
                    results.add(new Percent(0));
                }
            }
        }
        
        return results;
    }
    
    public class Request {
        @InvocableVariable
        public String focText;
        
        @InvocableVariable
        public Decimal quantity;
    }
}