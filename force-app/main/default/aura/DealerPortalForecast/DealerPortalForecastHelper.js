({
    // create year picklist
    createYearPicklist: function (component, event, helper) {
                console.log('year:-->TETST');

        var d = new Date();
        // var currentYear = d.getFullYear();
        //var currentYear = d.setFullYear(d.getFullYear()-1);
        var currentYear = d.getFullYear();
        var year = [];
        var lastYear = component.get("v.lastYear");
        var yeardiff = lastYear - currentYear;
        year.push({ "class": "optionClass", label: currentYear, value: currentYear, selected: true });

        for (var i = 1; i <= yeardiff; i++) {
            year.push({ "class": "optionClass", label: currentYear + i, value: currentYear + i });
        }
        console.log('year:-->',year);
        
        component.find("fromyearPickListValues").set("v.options", year);
        component.find("toyearPickListValues").set("v.options", year);
    },
    // create month picklist
    createMonthPicklist: function (component, event, helper) {
        var dt = new Date();
        var selectedMonth = dt.getMonth() + 1;
        var months = [];
        months.push({ "class": "optionClass", label: $A.get("$Label.c.January"), value: "1" },
            { "class": "optionClass", label: $A.get("$Label.c.February"), value: "2" },
            { "class": "optionClass", label: $A.get("$Label.c.March"), value: "3" },
            { "class": "optionClass", label: $A.get("$Label.c.April"), value: "4" },
            { "class": "optionClass", label: $A.get("$Label.c.May"), value: "5" },
            { "class": "optionClass", label: $A.get("$Label.c.June"), value: "6" },
            { "class": "optionClass", label: $A.get("$Label.c.July"), value: "7" },
            { "class": "optionClass", label: $A.get("$Label.c.August"), value: "8" },
            { "class": "optionClass", label: $A.get("$Label.c.September"), value: "9" },
            { "class": "optionClass", label: $A.get("$Label.c.October"), value: "10" },
            { "class": "optionClass", label: $A.get("$Label.c.November"), value: "11" },
            { "class": "optionClass", label: $A.get("$Label.c.December"), value: "12" });
        for (var i = 0; i < months.length; i++) {
            if (months[i].value == selectedMonth)
                months[i].selected = true;
        }
        component.find("frommonthPickListValues").set("v.options", months);
        component.find("tomonthPickListValues").set("v.options", months);
    },
})