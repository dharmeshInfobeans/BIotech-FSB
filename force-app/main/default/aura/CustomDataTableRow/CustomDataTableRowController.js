({
    calculateAvgQtyTillDt : function(component,event,helper) 
    {
        
        var soldQuantity = event.getSource().get("v.value");
        var sourceName = event.getSource().get("v.name");     
        
        var currentYear = new Date().getFullYear();
        var currentMonth = new Date().getMonth();
        var selectedYear = component.get("v.selectedYear");
        var currentChildRowArr = component.get('v.wrapper.dasWrapperLst');
        var currentParentRow = component.get('v.wrapper');
        var i=0;
        var j=0;
        currentParentRow.averageQuantityTillDate = 0;
        currentParentRow.totalInCountrySalesTillDate = 0;
        currentParentRow.idealStockRequred = 0;
        var avgQty=0;
        var totalsalestillDt = 0;
        var difference = 0;
        console.log('currentMonth>>',currentMonth);
        if(selectedYear==currentYear)
        {
            for(j=0;j<=currentMonth;j++)
            {
                console.log('currentChildRowArr>>soldquantity>>',currentChildRowArr[j].soldQuantity);
                if(currentChildRowArr[j].soldQuantity!='')
                    avgQty += parseInt(currentChildRowArr[j].soldQuantity);
            }
            console.log('avgQty>>',avgQty);
            avgQty = Math.round(avgQty/(currentMonth+1));
            console.log('avgQty>>',avgQty);
            currentParentRow.averageQuantityTillDate = avgQty.toString();
            console.log('currentParentRow.averageQuantityTillDate>>',currentParentRow.averageQuantityTillDate);
            currentParentRow.idealStockRequred = Math.round((parseFloat(currentParentRow.averageQuantityTillDate) *4)).toString();
        }
        else
        {
            for(j=0;j<=currentChildRowArr.length-1;j++)
            {
                if(currentChildRowArr[j].soldQuantity!='')
                    avgQty += parseInt(currentChildRowArr[j].soldQuantity);
            }
            currentParentRow.averageQuantityTillDate = Math.round((avgQty / currentChildRowArr.length)).toString();
            currentParentRow.idealStockRequred = Math.round((parseFloat(currentParentRow.averageQuantityTillDate) *4)).toString();
        }
        for(j=0;j<=currentChildRowArr.length-1;j++)
        {
            if(currentChildRowArr[j].soldQuantity!='')   
                totalsalestillDt += parseInt(currentChildRowArr[j].soldQuantity);
        }
        currentParentRow.totalInCountrySalesTillDate = totalsalestillDt.toString();
        var openingStock = currentParentRow.openingStock!=''? parseInt(currentParentRow.openingStock) : 0;
        var openOrdersWithBioTech = currentParentRow.openOrdersWithBioTech!=''?parseInt(currentParentRow.openOrdersWithBioTech):0;
        var stockInTransit = currentParentRow.stockInTransit!='' ? parseInt(currentParentRow.stockInTransit) : 0;
        var idealStockRequred = currentParentRow.idealStockRequred!=''?parseInt(currentParentRow.idealStockRequred):0; 
        currentParentRow.difference = ( openingStock + openOrdersWithBioTech + stockInTransit ) - (idealStockRequred);
        component.set("v.wrapper",currentParentRow);
    }
})