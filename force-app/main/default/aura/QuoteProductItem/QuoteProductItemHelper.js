({
    calculatePrices : function(component, qliRec) {
        //Calculate the subtotal
        console.log('qliRec : ',qliRec.FocQuantity);
        console.log('qliRec Data:',qliRec.totalQuantity);
        console.log('qliRec quantity',qliRec.Quantity);
        qliRec.FocQuantity = qliRec.FocQuantity == undefined ? 0 : qliRec.FocQuantity;
     //   qliRec.SubTotalPrice = qliRec.SalesPrice * (qliRec.Quantity - qliRec.FocQuantity);
           qliRec.SubTotalPrice = qliRec.SalesPrice * qliRec.Quantity;
     
        qliRec.totalQuantity=(qliRec.FocQuantity==undefined || qliRec.FocQuantity==0 || qliRec.FocQuantity==null || qliRec.FocQuantity=='' || qliRec.FocQuantity==NaN) && (qliRec.Quantity==undefined || qliRec.Quantity==0 || qliRec.Quantity==null || qliRec.Quantity=='' || qliRec.Quantity==NaN) ? 0 : (parseInt(qliRec.Quantity) + parseInt(qliRec.FocQuantity)); //code add
        
        if(isNaN(qliRec.totalQuantity)){
            qliRec.totalQuantity=0;
        }
        
        var orderProductRecord = component.get('v.orderProductRecord');
     //   orderProductRecord.TotalPrice = qliRec.SalesPrice * (qliRec.Quantity - qliRec.FocQuantity);
          orderProductRecord.TotalPrice = qliRec.SalesPrice * qliRec.Quantity; 
        component.set('v.orderProductRecord', orderProductRecord); 
        console.log('Total Quantity:',qliRec.totalQuantity);
        console.log('BG >>> orderProductRecord : ',orderProductRecord); //
        
        //Calculate Total
        if(qliRec.Discount > 0)
            qliRec.TotalPrice = qliRec.SubTotalPrice -(qliRec.SubTotalPrice * qliRec.Discount/100);
        else
            qliRec.TotalPrice = qliRec.SubTotalPrice;
        
        component.set('v.orderProductRecord', qliRec);
        
        
        var calculatePriceEvent = component.getEvent("calculateAllQliTotalPrices");
        
        calculatePriceEvent.fire();    
        
    },

    calculateFOCquantity : function(component, qliRec) {
        console.log('BG >>> qliRec : ',qliRec.FocQuantity);
        console.log('BG >>> qliRec Data:',qliRec.totalQuantity);
        console.log('BG>> qliRec quantity',qliRec.FOCText);
        var foctext = qliRec.FOCText;
        var result;
        if(foctext.includes('FOC')) {
            console.log('In if');
            result = this.findApplicableDiscount(qliRec.FOCText, qliRec.Quantity);
        }
        else {
            console.log('In else');
           result = qliRec.FOCText;
        }
        var FOCquantity = (Math.round((result*qliRec.Quantity)/100));
        //const result = findApplicable Discount(qliRec.FOCText, qliRec.totalQuantity);

        // Do something with the result, such as displaying it in the component
        //component.set("v.resultMessage", result);
        console.log('result :',result);
        console.log('qliRec.Quantity :',qliRec.Quantity);
        console.log('result*qliRec.Quantity)/100 :',(result*qliRec.Quantity)/100);
        console.log('math.raound : ',Math.round((result*qliRec.Quantity)/100));
        console.log('11 netquantity : ',FOCquantity);
        qliRec.FocQuantity = FOCquantity; 
        console.log('qliRec.FocQuantity  : ',qliRec.FocQuantity );
        qliRec.totalQuantity=(qliRec.FocQuantity==undefined || qliRec.FocQuantity==0 || qliRec.FocQuantity==null || qliRec.FocQuantity=='' || qliRec.FocQuantity==NaN) && (qliRec.Quantity==undefined || qliRec.Quantity==0 || qliRec.Quantity==null || qliRec.Quantity=='' || qliRec.Quantity==NaN) ? 0 : (parseInt(qliRec.Quantity) + parseInt(qliRec.FocQuantity)); //code add
        
        component.set('v.orderProductRecord', qliRec);

    },

    findApplicableDiscount: function(inputString, valueToCheck) {
        var rangeData = inputString.replaceAll('FOC ', '').split(', '); // Split the input into individual range entries

        for (var entry of rangeData) {
            // Use regular expressions to parse the range and discount
            var match = entry.match(/(\d+)-(\d+|\w*) Pcs\) - (\d+)%/); 
          //  /(\d+)\s*(-|\&)\s*(\d+|\w+) Pcs\) - (\d+)%/
            //entry.match(/(\d+\s*-(\s*\d+\s*Pcs)|(\d+\s*&\s*Above\s*Pcs))\s*-\s*(\d+)\s*%/);
            //entry.match(/(\d+)-(\d+) Pcs\) - (\d+)%/); commented 

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