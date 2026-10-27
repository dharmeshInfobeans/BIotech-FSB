({
    onProductItemChange : function(component, event, helper){
        var subProduct = component.get('v.subProductItem');
        console.log(subProduct.modelTxt)
        var QPChangeEvent = component.getEvent("subProdChangeEvnt");
        QPChangeEvent.setParams({
            "orderProduct" : subProduct
        });
        QPChangeEvent.fire();        
    },
    calculateFOCquantity : function(component, event, helper) {
        var orderProduct = component.get('v.subProductItem');
         var opObj = component.get('v.orderProduct');
        console.log('BG >>> orderProduct >>> : ',JSON.stringify(opObj));
        console.log('BG >>> orderProduct Data:',orderProduct.totalQuantity);
        console.log('BG>> orderProduct quantity',opObj.FOCText);
        var foctext = opObj.FOCText;
        var result;
        if(foctext.includes('FOC')) {
            console.log('In if');
            result = this.findApplicableDiscount(opObj.FOCText, orderProduct.Quantity);
        }
        else {
            console.log('orderProduct In else');
           result = opObj.FOCText;
        }
        var FOCquantity = (Math.round((result*orderProduct.Quantity)/100));
        //const result = findApplicable Discount(qliRec.FOCText, qliRec.totalQuantity);

        // Do something with the result, such as displaying it in the component
        //component.set("v.resultMessage", result);
        console.log('orderProduct result :',result);
        console.log('orderProduct.Quantity :',orderProduct.Quantity);
        console.log('result*orderProduct.Quantity)/100 :',(result*orderProduct.Quantity)/100);
        console.log('math.raound : ',Math.round((result*orderProduct.Quantity)/100));
        console.log('22netquantity : ',FOCquantity);
        orderProduct.FocQuantity = FOCquantity; 
        orderProduct.totalQuantity=(orderProduct.FocQuantity==undefined || orderProduct.FocQuantity==0 || orderProduct.FocQuantity==null || orderProduct.FocQuantity=='' || orderProduct.FocQuantity==NaN) && (orderProduct.Quantity==undefined || orderProduct.Quantity==0 || orderProduct.Quantity==null || orderProduct.Quantity=='' || orderProduct.Quantity==NaN) ? 0 : (parseInt(orderProduct.Quantity) + parseInt(orderProduct.FocQuantity)); //code add
        
        component.set('v.orderProductRecord', orderProduct);

    },
    findApplicableDiscount: function(inputString, valueToCheck) {
        console.log('BG >>> in discount');
        var rangeData = inputString.replaceAll('FOC ', '').split(', '); // Split the input into individual range entries

        for (var entry of rangeData) {
            // Use regular expressions to parse the range and discount
            var match = entry.match(/(\d+)-(\d+|\w*) Pcs\) - (\d+)%/); 
            if (match) {
                var minRange = parseInt(match[1]);
                var maxRange = parseInt(match[2]);
                var discount = parseInt(match[3]);

                if (valueToCheck >= minRange && valueToCheck <= maxRange) {
                    return discount;
                }
            }else if(entry.includes('Above')) {
                match = entry.match(/(\d+) \& Above Pcs\) - (\d+)%/);
                if (match) {
                    console.log('BG >>> ',match); //
                    var minRange = parseInt(match[1]);
                    var discount = parseInt(match[2]);
                    if (valueToCheck >= minRange) {
                        return discount;
                    }
                }
            }
        }

        return 0;
    }
})