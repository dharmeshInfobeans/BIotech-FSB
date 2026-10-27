import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { registerListener, unregisterAllListeners, fireEvent } from 'c/pubsub';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Apex Imports
import getEvents from '@salesforce/apex/calendarPlanningMobileController.getEvents';
import getdailyactivity from '@salesforce/apex/calendarPlanningMobileController.getdailyactivity';
import refreshEvents from '@salesforce/apex/calendarPlanningMobileController.getEventsRefresh';
import getLabels from '@salesforce/apex/calendarPlanningMobileController.getLabels';
import getManagerAndReportee from '@salesforce/apex/calendarPlanningMobileController.getManagerAndReportee';
import getRegionAndZone from '@salesforce/apex/calendarPlanningMobileController.getRegionAndZone';
import getloginlogoutmodule from '@salesforce/apex/CommonutiltiyClass.getCustomLabels';
import getHolidayRecord from '@salesforce/apex/calendarPlanningMobileController.getHolidayRecord';
import updateEventData from '@salesforce/apex/calendarPlanningMobileController.updateEventData';
import deleteEventData from '@salesforce/apex/calendarPlanningMobileController.deleteEventData';
import getLeadData from '@salesforce/apex/calendarPlanningMobileController.getLeadData';
import getEventsForBDPlan from '@salesforce/apex/calendarPlanningMobileController.getEventsForBDPlan';
import getProductsBySubCallType from '@salesforce/apex/calendarPlanningMobileController.getProductsBySubCallType';
import getProductsByFamily from '@salesforce/apex/calendarPlanningMobileController.getProductsByFamily';
import getProductFamily from '@salesforce/apex/calendarPlanningMobileController.getProductFamily';
import getProducts from '@salesforce/apex/calendarPlanningMobileController.getProducts';

// User ID and Labels
import Id from '@salesforce/user/Id';
import HelpDesk from '@salesforce/label/c.DCR_HelpDesk';
import DCR_past_date from '@salesforce/label/c.DCR_past_date';

export default class EventPlanner extends NavigationMixin(LightningElement) {
    @wire(CurrentPageReference) pageRef;

    // User and Labels
    @track skey = Id;
    @track labels;
    @track customLabels = { HelpDesk, DCR_past_date };
    @track helpLable = '';
    @track getloginlogoutlabel = {};

    // Calendar State
    @track currentMonth;
    @track currentYear;
    @track calendarDays = [];
    @track selectedDate = null;
    @track selectedDateString = null; // Track selected date as YYYY-MM-DD string
    @track todayFormatedDate = null;
    @track dateOnHeader = null;

    // Event Data
    @track eventsMap = new Map();
    @track todaysEvent = [];
    @track selectedDateEvents = [];
    events;

    // Holiday Data
    @track holidaysMap = new Map();
    holidayData;

    // UI State
    @track spinner = true;
    @track showEvents = false;
    @track isEventCreate = true;
    @track activeEvent = false;
    @track noActiveEvent = true;
    @track selectedDateEventsView = false;
    @track showCustomerLookup = false;
    @track showCalendar = true;
    @track showEditEventModal = false;
    @track showUpdateLeadModal = false;

    // Event Editing State
    @track eventObj = {};
    @track modalProductOptions = [];
    @track modalSelectedProducts = [];
    @track modalEnableProductOption = false;
    @track modalCurrentCallType = '';
    @track otherType = false;
    @track eventstage = true;
    updateEventMap = {};
    @track eventRecordId;
    @track accountId;
    @track leadData = [];

    // User Selector
    @track usersOptions = [];
    @track Activitydata;

    // Region and Zone Data for Customer Lookup
    @track userRegionSelectList = [];
    @track userZoneSelectList = [];

    // Event Creation State
    @track showEventCreation = false;
    @track selectedAccountId = null;
    @track selectedEventType = null;
    @track selectedCeRating = null;
    @track selectedCisRating = null;
    @track selectedContactOptions = [];
    @track selectedAccountName = '';
    @track selectedShowDataAttribute = '';
    @track selectedProductData = '';
    @track selectedProductFamily = '';
    @track selectedProductGroup = '';
    @track selectedContactName = '';
    @track selectedDate = null;
    @track bdplanlist = [];

    // Getter to check if Today button should be shown
    get shouldShowTodayButton() {
        const today = new Date();
        const shouldShow = this.currentMonth !== today.getMonth() || this.currentYear !== today.getFullYear();
        console.log('📊 [EventPlanner] shouldShowTodayButton: Checking if Today button should show:', shouldShow, '(current:', this.monthNames[this.currentMonth], this.currentYear + ')');
        return shouldShow;
    }

    // Month names for display
    monthNames = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
    ];

    // Wire: Labels
    @wire(getLabels)
    wiredLabels({ error, data }) {
        console.log('📊 [EventPlanner] wiredLabels: Wire adapter called');
        if (data) {
            console.log('📊 [EventPlanner] wiredLabels: Labels received successfully');
            console.log('📊 [EventPlanner] wiredLabels: Labels data:', JSON.stringify(data, null, 2));
            this.labels = data;
        } else if (error) {
            console.error('❌ [EventPlanner] wiredLabels: Error loading labels:', error);
        }
    }

    // Wire: Login/Logout Labels
    @wire(getloginlogoutmodule)
    wiredLoginLogout(result) {
        console.log('📊 [EventPlanner] wiredLoginLogout: Wire adapter called');
        if (result.data) {
            console.log('📊 [EventPlanner] wiredLoginLogout: Login/Logout labels received');
            console.log('📊 [EventPlanner] wiredLoginLogout: Data:', JSON.stringify(result.data, null, 2));
            this.getloginlogoutlabel = result.data;
        } else if (result.error) {
            console.error('❌ [EventPlanner] wiredLoginLogout: Error loading login/logout labels:', result.error);
        }
    }

    // Wire: Manager and Reportee
    @wire(getManagerAndReportee)
    wiredUsers({ error, data }) {
        console.log('📊 [EventPlanner] wiredUsers: Wire adapter called');
        if (data) {
            console.log('📊 [EventPlanner] wiredUsers: User list received');
            console.log('📊 [EventPlanner] wiredUsers: Number of users:', data.length);
            console.log('📊 [EventPlanner] wiredUsers: Users data:', JSON.stringify(data, null, 2));
            this.usersOptions = data;
        } else if (error) {
            console.error('❌ [EventPlanner] wiredUsers: Error loading users:', error);
        }
    }

    // Wire: Daily Activity
    @wire(getdailyactivity)
    wiredActivity({ error, data }) {
        console.log('📊 [EventPlanner] wiredActivity: Wire adapter called');
        if (data) {
            console.log('📊 [EventPlanner] wiredActivity: Activity data received');
            console.log('📊 [EventPlanner] wiredActivity: User has logged in today:', data.activity);
            console.log('📊 [EventPlanner] wiredActivity: Full data:', JSON.stringify(data, null, 2));
            this.Activitydata = data.activity;
        } else if (error) {
            console.error('❌ [EventPlanner] wiredActivity: Error loading activity:', error);
        }
    }

    // Wire: Region and Zone Data
    @wire(getRegionAndZone)
    wiredRegionZone({ error, data }) {
        console.log('📊 [EventPlanner] wiredRegionZone: Wire adapter called');
        if (data) {
            console.log('📊 [EventPlanner] wiredRegionZone: Region/Zone data received');
            console.log('📊 [EventPlanner] wiredRegionZone: Regions count:', data.userRegionSelectList?.length || 0);
            console.log('📊 [EventPlanner] wiredRegionZone: Zones count:', data.userZoneSelectList?.length || 0);
            console.log('📊 [EventPlanner] wiredRegionZone: Full data:', JSON.stringify(data, null, 2));
            this.userRegionSelectList = data.userRegionSelectList || [];
            this.userZoneSelectList = data.userZoneSelectList || [];
        } else if (error) {
            console.error('❌ [EventPlanner] wiredRegionZone: Error loading region/zone data:', error);
        }
    }

    // Wire: Events
    @wire(getEvents, { skey: '$skey' })
    wiredEvents(result) {
        console.log('📊 [EventPlanner] wiredEvents: Wire adapter called');
        console.log('📊 [EventPlanner] wiredEvents: User ID (skey):', this.skey);
        this.events = result;
        if (result.data) {
            console.log('📊 [EventPlanner] wiredEvents: Events data received');
            console.log('📊 [EventPlanner] wiredEvents: Number of events:', result.data.length);
            console.log('📊 [EventPlanner] wiredEvents: Events data:', JSON.stringify(result.data, null, 2));
            console.log('📊 [EventPlanner] wiredEvents: Calling processEvents()');
            this.processEvents(result.data);
            this.spinner = false;
            console.log('📊 [EventPlanner] wiredEvents: Processing complete, spinner hidden');
        } else if (result.error) {
            console.error('❌ [EventPlanner] wiredEvents: Error loading events:', result.error);
            this.spinner = false;
        }
    }

    // Wire: Holidays and Weekly Offs
    @wire(getHolidayRecord)
    wiredHolidays(result) {
        console.log('=== HOLIDAY WIRE CALLED ===');
        console.log('Holiday wire result:', JSON.stringify(result, null, 2));

        this.holidayData = result;
        if (result.data) {
            console.log('Holiday data received:', result.data);
            console.log('Holiday data type:', typeof result.data);
            console.log('Holiday data keys:', Object.keys(result.data));
            this.processHolidays(result.data);
        } else if (result.error) {
            console.error('Error loading holidays:', result.error);
        } else {
            console.log('No data and no error - holiday wire may still be loading');
        }
    }

    // Lifecycle Hooks
    connectedCallback() {
        console.log('🎯 [EventPlanner] connectedCallback: Component initializing...');
        console.log('🎯 [EventPlanner] connectedCallback: Current user ID:', Id);
        console.log('🎯 [EventPlanner] connectedCallback: DCR_past_date label:', DCR_past_date);

        this.helpLable = this.customLabels.HelpDesk + ' ' + DCR_past_date + ' days';
        console.log('🎯 [EventPlanner] connectedCallback: Help label set:', this.helpLable);

        console.log('🎯 [EventPlanner] connectedCallback: Calling initializeCalendar()');
        this.initializeCalendar();

        // Register event listeners
        console.log('🎯 [EventPlanner] connectedCallback: Registering pubsub event listeners');
        registerListener('reloadEvents', this.handleReloadEvents, this);
        registerListener('handleShowCalendar', this.handleShowCalendarFromLookup, this);
        registerListener('homeScreen', this.handleBackToCalendar, this);
        registerListener('reloadBDPlanEvent', this.handleReloadBDPlan, this);
        console.log('🎯 [EventPlanner] connectedCallback: 4 pubsub listeners registered (reloadEvents, handleShowCalendar, homeScreen, reloadBDPlanEvent)');
    }

    disconnectedCallback() {
        console.log('🎯 [EventPlanner] disconnectedCallback: Component disconnecting, unregistering all listeners');
        unregisterAllListeners(this);
    }

    // Initialize Calendar
    initializeCalendar() {
        console.log('📅 [EventPlanner] initializeCalendar: Initializing calendar to current month');
        const today = new Date();
        console.log('📅 [EventPlanner] initializeCalendar: Today\'s date:', today.toString());

        this.currentMonth = today.getMonth();
        this.currentYear = today.getFullYear();
        console.log('📅 [EventPlanner] initializeCalendar: Set to month:', this.currentMonth, 'year:', this.currentYear);

        // Format today's date to match Apex VisitDate format (YYYY-MM-DD)
        // This matches the old component approach for event filtering
        // Use Date getters, not toLocaleDateString().split('/'), which breaks on some mobile locales
        const day = String(today.getDate()).padStart(2, '0');
        const month = String(today.getMonth() + 1).padStart(2, '0');
        const year = String(today.getFullYear());

        // Store in YYYY-MM-DD format to match event.VisitDate from Apex
        this.todayFormatedDate = `${year}-${month}-${day}`;
        console.log('📅 [EventPlanner] initializeCalendar: Today formatted (YYYY-MM-DD):', this.todayFormatedDate);

        // Format header date as DD/MM/YYYY for display
        this.dateOnHeader = `${day}/${month}/${year}`;
        console.log('📅 [EventPlanner] initializeCalendar: Date header (DD/MM/YYYY):', this.dateOnHeader);

        console.log('📅 [EventPlanner] initializeCalendar: Calling buildCalendarDays()');
        this.buildCalendarDays();
    }

    // Build Calendar Days Array
    buildCalendarDays() {
        console.log('📅 [EventPlanner] buildCalendarDays: Building calendar array');
        const year = this.currentYear;
        const month = this.currentMonth;
        console.log('📅 [EventPlanner] buildCalendarDays: Year:', year, 'Month:', month, `(${this.monthNames[month]})`);

        // Get first day of month (0 = Sunday, 1 = Monday, etc.)
        const firstDay = new Date(year, month, 1);
        let firstDayOfWeek = firstDay.getDay();
        console.log('📅 [EventPlanner] buildCalendarDays: First day of month (raw):', firstDayOfWeek);

        // Adjust so Monday = 0, Sunday = 6
        firstDayOfWeek = firstDayOfWeek === 0 ? 6 : firstDayOfWeek - 1;
        console.log('📅 [EventPlanner] buildCalendarDays: First day adjusted (Mon=0):', firstDayOfWeek);

        // Get last day of current month
        const lastDay = new Date(year, month + 1, 0).getDate();
        console.log('📅 [EventPlanner] buildCalendarDays: Last day of month:', lastDay);

        // Get last day of previous month
        const prevMonthLastDay = new Date(year, month, 0).getDate();
        console.log('📅 [EventPlanner] buildCalendarDays: Previous month last day:', prevMonthLastDay);

        const days = [];

        // Previous month days
        const prevMonthDaysCount = firstDayOfWeek;
        console.log('📅 [EventPlanner] buildCalendarDays: Adding', prevMonthDaysCount, 'days from previous month');
        for (let i = firstDayOfWeek - 1; i >= 0; i--) {
            days.push(this.createDayObject(
                prevMonthLastDay - i,
                year,
                month - 1,
                false
            ));
        }

        // Current month days
        console.log('📅 [EventPlanner] buildCalendarDays: Adding', lastDay, 'days from current month');
        for (let day = 1; day <= lastDay; day++) {
            days.push(this.createDayObject(day, year, month, true));
        }

        // Next month days (fill to 42 total for 6 weeks)
        const remainingDays = 42 - days.length;
        console.log('📅 [EventPlanner] buildCalendarDays: Adding', remainingDays, 'days from next month (to fill 42 slots)');
        for (let day = 1; day <= remainingDays; day++) {
            days.push(this.createDayObject(day, year, month + 1, false));
        }

        console.log('📅 [EventPlanner] buildCalendarDays: Total calendar days created:', days.length);
        console.log('📅 [EventPlanner] buildCalendarDays: eventsMap size:', this.eventsMap.size);
        console.log('📅 [EventPlanner] buildCalendarDays: holidaysMap size:', this.holidaysMap.size);
        this.calendarDays = days;
        console.log('📅 [EventPlanner] buildCalendarDays: Calendar build complete');
    }

    // Create Day Object with all properties
    createDayObject(day, year, month, isCurrentMonth) {
        const date = new Date(year, month, day);
        const dateStr = this.formatDateString(date);

        // Check if it's today
        const today = new Date();
        const isToday = date.toDateString() === today.toDateString();

        // Check if this date is selected
        const isSelected = this.selectedDateString === dateStr;

        // Check if it's weekend (Saturday = 6, Sunday = 0)
        const dayOfWeek = date.getDay();
        const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;

        // Check if date is restricted (beyond -6 days)
        const isPastRestricted = this.isPastRestrictedDate(date);

        // Get events for this date
        const eventsForDate = this.eventsMap.get(dateStr) || [];

        // Get holiday/weekly off info for this date
        const holidayInfo = this.holidaysMap.get(dateStr);
        const isHoliday = holidayInfo && holidayInfo.type === 'H';
        const isWeeklyOff = holidayInfo && holidayInfo.type === 'WO';
        const holidayName = holidayInfo ? holidayInfo.name : null;

        // Debug logging for specific dates (sample first few days)
        if (day <= 3 && isCurrentMonth) {
            console.log(`Day ${day} (${dateStr}):`, {
                holidayInfo,
                isHoliday,
                isWeeklyOff,
                holidayName,
                'holidaysMap size': this.holidaysMap.size
            });
        }

        // Categorize events
        const eventCounts = this.categorizeEvents(eventsForDate, isHoliday, isWeeklyOff);

        return {
            key: dateStr,
            date: dateStr,
            dayNumber: day,
            fullDate: date,
            isCurrentMonth,
            isToday,
            isSelected,
            isWeekend,
            isPastRestricted,
            isHoliday,
            isWeeklyOff,
            holidayName,
            events: eventsForDate,
            eventCounts,
            totalEvents: eventsForDate.length,
            cssClass: this.getDayCssClass(isCurrentMonth, isToday, isSelected, isWeekend, isPastRestricted, eventCounts, isHoliday, isWeeklyOff)
        };
    }

    // Format date as YYYY-MM-DD for internal storage (matching Apex VisitDate format)
    formatDateString(date) {
        const day = String(date.getDate()).padStart(2, '0');
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const year = String(date.getFullYear());
        const formatted = `${year}-${month}-${day}`;
        console.log('📊 [EventPlanner] formatDateString: Date object:', date.toString(), '→ YYYY-MM-DD:', formatted);
        return formatted;
    }

    // Format date as MM/DD/YYYY for Apex submission
    formatDateForApex(date) {
        // Apex createEvent expects MM/DD/YYYY format
        const formatted = date.toLocaleDateString("en-US");
        console.log('📊 [EventPlanner] formatDateForApex: Date object:', date.toString(), '→ MM/DD/YYYY:', formatted);
        return formatted;
    }

    // Check if date is beyond -6 days restriction
    isPastRestrictedDate(date) {
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const pastData = DCR_past_date.replace('-', '');
        const restrictionDays = parseInt(pastData) + 1;

        const restrictedDate = new Date(today);
        restrictedDate.setDate(today.getDate() - restrictionDays);

        const isRestricted = date <= restrictedDate;
        console.log('📊 [EventPlanner] isPastRestrictedDate: Checking date:', this.formatDateString(date), 'Restricted:', isRestricted, '(cutoff:', this.formatDateString(restrictedDate) + ')');
        return isRestricted;
    }

    // Categorize events by type
    categorizeEvents(events, isHoliday, isWeeklyOff) {
        const counts = {
            planned: 0,
            completed: 0,
            holiday: isHoliday ? 1 : 0,
            leave: 0,
            weeklyOff: isWeeklyOff ? 1 : 0
        };

        events.forEach(event => {
            // Check event subject or other type to categorize
            const subject = event.Subject || '';

            if (subject === 'Holiday' || event.OtherType === true && subject.includes('Holiday')) {
                counts.holiday++;
            } else if (subject === 'Leave' || subject.includes('Leave')) {
                counts.leave++;
            } else if (subject === 'Out of office' || subject.includes('Out of office')) {
                counts.weeklyOff++;
            } else {
                // Regular customer visit events
                if (event.Status === 'Completed' || event.Status === 'Held') {
                    counts.completed++;
                } else {
                    counts.planned++;
                }
            }
        });

        console.log('📊 [EventPlanner] categorizeEvents: Categorized', events.length, 'events:', counts);
        return counts;
    }

    // Get CSS class for day cell
    getDayCssClass(isCurrentMonth, isToday, isSelected, isWeekend, isPastRestricted, eventCounts, isHoliday, isWeeklyOff) {
        let classes = 'calendar-cell';

        if (!isCurrentMonth) {
            classes += ' calendar-cell--other-month';
        } else {
            classes += ' calendar-cell--current-month';
        }

        if (isToday) {
            classes += ' calendar-cell--today';
        }

        // Add selected class (takes priority over today, but not over restricted)
        if (isSelected && isCurrentMonth) {
            classes += ' calendar-cell--selected';
        }

        if (isWeekend && isCurrentMonth) {
            classes += ' calendar-cell--weekend';
        }

        if (isPastRestricted) {
            classes += ' calendar-cell--past-restricted';
        }

        // Add holiday/weekly off class (takes priority over events)
        if (isHoliday) {
            classes += ' calendar-cell--holiday';
        } else if (isWeeklyOff) {
            classes += ' calendar-cell--weekly-off';
        }
        // Add event type class based on priority (if not a holiday/weekly off)
        else if (eventCounts.planned > 0) {
            classes += ' calendar-cell--has-planned';
        } else if (eventCounts.completed > 0) {
            classes += ' calendar-cell--has-completed';
        } else if (eventCounts.leave > 0) {
            classes += ' calendar-cell--has-leave';
        }

        return classes;
    }

    // Process events from wire
    processEvents(eventsData) {
        console.log('📊 [EventPlanner] processEvents: Processing events data');
        console.log('📊 [EventPlanner] processEvents: Total events received:', eventsData.length);

        const dateMap = new Map();

        eventsData.forEach((event, index) => {
            if (event.VisitDate) {
                if (!dateMap.has(event.VisitDate)) {
                    dateMap.set(event.VisitDate, []);
                }
                dateMap.get(event.VisitDate).push(event);

                // Log first 3 events for sample
                if (index < 3) {
                    console.log(`📊 [EventPlanner] processEvents: Event ${index + 1}:`, {
                        Id: event.Id,
                        Subject: event.Subject,
                        VisitDate: event.VisitDate,
                        Status: event.Status,
                        AccountName: event.AccountName || event.LeadName || event.OpportunityName
                    });
                }
            } else {
                console.log(`📊 [EventPlanner] processEvents: Event ${index} has no VisitDate, skipping`);
            }
        });

        this.eventsMap = dateMap;
        console.log('📊 [EventPlanner] processEvents: eventsMap created with', dateMap.size, 'unique dates');
        console.log('📊 [EventPlanner] processEvents: Dates with events:', Array.from(dateMap.keys()).join(', '));

        // Filter today's events
        this.todaysEvent = eventsData.filter(event =>
            event.VisitDate === this.todayFormatedDate
        );
        console.log('📊 [EventPlanner] processEvents: Today\'s date:', this.todayFormatedDate);
        console.log('📊 [EventPlanner] processEvents: Today\'s events count:', this.todaysEvent.length);
        if (this.todaysEvent.length > 0) {
            console.log('📊 [EventPlanner] processEvents: Today\'s events:', JSON.stringify(this.todaysEvent, null, 2));
        }

        // Update calendar days with new event data
        console.log('📊 [EventPlanner] processEvents: Calling buildCalendarDays() to update visual state');
        this.buildCalendarDays();

        // Update active event view
        if (this.todaysEvent.length > 0) {
            this.activeEvent = true;
            this.noActiveEvent = false;
            console.log('📊 [EventPlanner] processEvents: View state: activeEvent=true (showing today\'s events)');
        } else {
            this.activeEvent = false;
            this.noActiveEvent = true;
            console.log('📊 [EventPlanner] processEvents: View state: noActiveEvent=true (no events for today)');
        }
    }

    // Process holidays from wire
    processHolidays(holidayData) {
        console.log('=== PROCESS HOLIDAYS CALLED ===');
        console.log('Raw holiday data:', holidayData);

        const dateMap = new Map();

        // Process holidays list from the response
        if (holidayData.holidays && Array.isArray(holidayData.holidays)) {
            console.log('Holiday data has holidays array, length:', holidayData.holidays.length);
            console.log('Holidays array:', JSON.stringify(holidayData.holidays, null, 2));

            holidayData.holidays.forEach((holiday, index) => {
                console.log(`Processing holiday ${index}:`, holiday);

                if (holiday.Date) {
                    // Format Date as YYYY-MM-DD
                    const dateStr = this.formatApexDateToString(holiday.Date);
                    console.log(`  Original Date: ${holiday.Date}, Formatted: ${dateStr}`);

                    const holidayInfo = {
                        type: holiday.Type, // 'H' for Holiday, 'WO' for Weekly Off
                        name: holiday.Name || (holiday.Type === 'H' ? 'Holiday' : 'Weekly Off'),
                        id: holiday.Id
                    };

                    console.log(`  Setting date ${dateStr} with info:`, holidayInfo);
                    dateMap.set(dateStr, holidayInfo);
                } else {
                    console.log(`  Holiday ${index} has no Date field`);
                }
            });
        } else {
            console.log('holidayData.holidays is not an array or does not exist');
            console.log('  holidayData.holidays:', holidayData.holidays);
            console.log('  Is Array?:', Array.isArray(holidayData.holidays));
        }

        console.log('Final holidaysMap size:', dateMap.size);
        console.log('Final holidaysMap entries:', Array.from(dateMap.entries()));

        // Log all dates in the map for easier debugging
        if (dateMap.size > 0) {
            console.log('=== ALL HOLIDAY DATES IN MAP ===');
            Array.from(dateMap.keys()).forEach(dateKey => {
                console.log(`  ${dateKey}: ${JSON.stringify(dateMap.get(dateKey))}`);
            });
        }

        this.holidaysMap = dateMap;

        // Rebuild calendar to include holiday markers
        this.buildCalendarDays();
    }

    // Format Apex Date to YYYY-MM-DD string
    formatApexDateToString(apexDate) {
        console.log('formatApexDateToString called with:', apexDate, 'Type:', typeof apexDate);

        // If it's already a Date object
        if (apexDate instanceof Date) {
            console.log('  apexDate is Date object');
            return this.formatDateString(apexDate);
        }

        // If it's a string in format YYYY-MM-DD, return as is
        if (typeof apexDate === 'string' && apexDate.match(/^\d{4}-\d{2}-\d{2}$/)) {
            console.log('  apexDate is already YYYY-MM-DD format');
            return apexDate;
        }

        // Try to parse it
        console.log('  Attempting to parse apexDate');
        const date = new Date(apexDate);
        const result = this.formatDateString(date);
        console.log('  Parsed result:', result);
        return result;
    }

    // Event Handlers
    handlePrevMonth() {
        console.log('🔍 [EventPlanner] handlePrevMonth: Previous month button clicked');
        console.log('🔍 [EventPlanner] handlePrevMonth: Current:', this.monthNames[this.currentMonth], this.currentYear);
        if (this.currentMonth === 0) {
            this.currentMonth = 11;
            this.currentYear--;
        } else {
            this.currentMonth--;
        }
        console.log('🔍 [EventPlanner] handlePrevMonth: New:', this.monthNames[this.currentMonth], this.currentYear);
        this.buildCalendarDays();
    }

    handleNextMonth() {
        console.log('🔍 [EventPlanner] handleNextMonth: Next month button clicked');
        console.log('🔍 [EventPlanner] handleNextMonth: Current:', this.monthNames[this.currentMonth], this.currentYear);
        if (this.currentMonth === 11) {
            this.currentMonth = 0;
            this.currentYear++;
        } else {
            this.currentMonth++;
        }
        console.log('🔍 [EventPlanner] handleNextMonth: New:', this.monthNames[this.currentMonth], this.currentYear);
        this.buildCalendarDays();
    }

    handleGoToToday() {
        console.log('🔍 [EventPlanner] handleGoToToday: Today button clicked');
        // Get today's date
        const today = new Date();
        console.log('🔍 [EventPlanner] handleGoToToday: Today\'s date:', today.toString());

        // Set current month and year to today
        this.currentMonth = today.getMonth();
        this.currentYear = today.getFullYear();
        console.log('🔍 [EventPlanner] handleGoToToday: Navigating to:', this.monthNames[this.currentMonth], this.currentYear);

        // Rebuild calendar to show current month
        this.buildCalendarDays();

        // Auto-select today's date
        const todayStr = this.formatDateString(today);
        console.log('🔍 [EventPlanner] handleGoToToday: Today string (YYYY-MM-DD):', todayStr);
        const dayData = this.calendarDays.find(day => day.date === todayStr);

        if (dayData) {
            console.log('🔍 [EventPlanner] handleGoToToday: Day data found, auto-selecting today');
            this.selectedDate = dayData.fullDate;
            this.selectedDateString = todayStr;
            this.selectedDateEvents = dayData.events;
            console.log('🔍 [EventPlanner] handleGoToToday: Events for today:', dayData.events.length);

            // Update date header
            const splitdate = todayStr.split('-');
            this.dateOnHeader = splitdate[2] + '/' + splitdate[1] + '/' + splitdate[0];
            console.log('🔍 [EventPlanner] handleGoToToday: Date header updated to:', this.dateOnHeader);

            // Enable add button for today (today should not be past-restricted)
            this.isEventCreate = !dayData.isPastRestricted;
            console.log('🔍 [EventPlanner] handleGoToToday: Add button enabled:', this.isEventCreate);

            // Show today's events view
            if (this.todaysEvent.length > 0) {
                this.activeEvent = true;
                this.selectedDateEventsView = false;
                this.noActiveEvent = false;
                console.log('🔍 [EventPlanner] handleGoToToday: Showing activeEvent view (today\'s events)');
            } else {
                this.activeEvent = false;
                this.selectedDateEventsView = false;
                this.noActiveEvent = true;
                console.log('🔍 [EventPlanner] handleGoToToday: Showing noActiveEvent view (no events)');
            }

            // Rebuild calendar to update visual selection
            this.buildCalendarDays();
        } else {
            console.log('🔍 [EventPlanner] handleGoToToday: Day data NOT found for today');
        }
    }

    handleDateSelect(event) {
        console.log('🔍 [EventPlanner] handleDateSelect: Date cell clicked');
        const dateStr = event.currentTarget.dataset.date;
        console.log('🔍 [EventPlanner] handleDateSelect: Date string (YYYY-MM-DD):', dateStr);
        const dayData = this.calendarDays.find(day => day.date === dateStr);

        if (!dayData) {
            console.log('🔍 [EventPlanner] handleDateSelect: Day data not found, exiting');
            return;
        }
        if (!dayData.isCurrentMonth) {
            console.log('🔍 [EventPlanner] handleDateSelect: Date is not in current month, exiting');
            return;
        }

        console.log('🔍 [EventPlanner] handleDateSelect: Valid date selected');
        console.log('🔍 [EventPlanner] handleDateSelect: Day data:', {
            date: dayData.date,
            dayNumber: dayData.dayNumber,
            totalEvents: dayData.totalEvents,
            isWeekend: dayData.isWeekend,
            isPastRestricted: dayData.isPastRestricted,
            isHoliday: dayData.isHoliday,
            isWeeklyOff: dayData.isWeeklyOff
        });

        this.selectedDate = dayData.fullDate;
        this.selectedDateString = dateStr; // Store selected date string for visual highlighting
        this.selectedDateEvents = dayData.events;
        console.log('🔍 [EventPlanner] handleDateSelect: Events for this date:', dayData.events.length);
        if (dayData.events.length > 0) {
            console.log('🔍 [EventPlanner] handleDateSelect: Events:', JSON.stringify(dayData.events, null, 2));
        }

        // Update date header to DD/MM/YYYY format
        // dateStr is in YYYY-MM-DD format from formatDateString()
        // Split by '-' gives [YYYY, MM, DD], rearrange to DD/MM/YYYY
        const splitdate = dateStr.split('-');
        this.dateOnHeader = splitdate[2] + '/' + splitdate[1] + '/' + splitdate[0];
        console.log('🔍 [EventPlanner] handleDateSelect: Date header updated to:', this.dateOnHeader);

        // Check if event creation is allowed for this date
        this.isEventCreate = !dayData.isPastRestricted;
        console.log('🔍 [EventPlanner] handleDateSelect: Event creation allowed:', this.isEventCreate);

        // Update view states
        if (this.selectedDateEvents.length > 0) {
            this.selectedDateEventsView = true;
            this.activeEvent = false;
            this.noActiveEvent = false;
            console.log('🔍 [EventPlanner] handleDateSelect: View state: selectedDateEventsView=true (showing events for selected date)');
        } else {
            this.selectedDateEventsView = false;
            this.activeEvent = false;
            this.noActiveEvent = true;
            console.log('🔍 [EventPlanner] handleDateSelect: View state: noActiveEvent=true (no events on selected date)');
        }

        // Rebuild calendar to update selected state
        console.log('🔍 [EventPlanner] handleDateSelect: Rebuilding calendar to update visual selection');
        this.buildCalendarDays();

        // Fire event for child components (future use)
        const eventData = {
            date: this.formatDateForEvent(dayData.fullDate),
            fulldate: dayData.fullDate
        };
        console.log('🔍 [EventPlanner] handleDateSelect: Firing pubsub selectedDate event:', eventData);
        fireEvent(this.pageRef, 'selectedDate', eventData);
    }

    formatDateForEvent(date) {
        return date.toLocaleDateString('en-US');
    }

    handleUserChange(event) {
        console.log('🔍 [EventPlanner] handleUserChange: User selection changed');
        console.log('🔍 [EventPlanner] handleUserChange: Previous user ID:', this.skey);
        console.log('🔍 [EventPlanner] handleUserChange: New user ID:', event.target.value);
        this.spinner = true;
        this.skey = event.target.value;

        // Clear selected date state to prevent showing stale events
        this.selectedDate = null;
        this.selectedDateString = null;
        this.selectedDateEvents = [];
        this.selectedDateEventsView = false;

        // Reset to today's events view after new data loads
        this.activeEvent = false;
        this.noActiveEvent = true;

        // Reset date header to today's date
        const today = new Date();
        const day = String(today.getDate()).padStart(2, '0');
        const month = String(today.getMonth() + 1).padStart(2, '0');
        const year = String(today.getFullYear());
        this.dateOnHeader = `${day}/${month}/${year}`;

        // Reset calendar to current month
        this.currentMonth = today.getMonth();
        this.currentYear = today.getFullYear();
        this.buildCalendarDays();

        console.log('🔍 [EventPlanner] handleUserChange: Cleared selected date state, reset to current month, wire adapter will re-fire with new skey');
    }

    handleRefresh() {
        console.log('🔄 [EventPlanner] handleRefresh: Refresh button clicked');
        this.spinner = true;

        // Store selected date info before refresh
        const wasDateSelected = this.selectedDateString !== null;
        const previouslySelectedDate = this.selectedDateString;
        console.log('🔄 [EventPlanner] handleRefresh: Previously selected date:', previouslySelectedDate);
        console.log('🔄 [EventPlanner] handleRefresh: Calling refreshEvents Apex method for user:', this.skey);

        refreshEvents({ skey: this.skey })
            .then(result => {
                console.log('✅ [EventPlanner] handleRefresh: Events refreshed successfully');
                console.log('✅ [EventPlanner] handleRefresh: Number of events:', result.length);
                this.processEvents(result);

                // If a date was previously selected, update the selected date view
                if (wasDateSelected && previouslySelectedDate) {
                    // Find the day data for the previously selected date
                    const dayData = this.calendarDays.find(day => day.date === previouslySelectedDate);
                    if (dayData) {
                        // Update selected date events with refreshed data
                        this.selectedDate = dayData.fullDate;
                        this.selectedDateString = previouslySelectedDate;
                        this.selectedDateEvents = dayData.events;

                        // Update date header
                        const splitdate = previouslySelectedDate.split('-');
                        this.dateOnHeader = splitdate[2] + '/' + splitdate[1] + '/' + splitdate[0];

                        // Update view flags based on whether there are events
                        if (dayData.events.length > 0) {
                            this.selectedDateEventsView = true;
                            this.activeEvent = false;
                            this.noActiveEvent = false;
                        } else {
                            // No events on this date
                            this.selectedDateEventsView = false;
                            this.activeEvent = false;
                            this.noActiveEvent = true;
                        }
                    }
                }

                this.spinner = false;
                console.log('✅ [EventPlanner] handleRefresh: Refresh complete, spinner hidden');
                this.showToast('Success', 'Events refreshed successfully', 'success');
            })
            .catch(error => {
                console.error('❌ [EventPlanner] handleRefresh: Error refreshing events:', error);
                this.spinner = false;
                this.showToast('Error', 'Failed to refresh events', 'error');
            });
    }

    handleAddEvent() {
        console.log('🔍 [EventPlanner] handleAddEvent: Add event button clicked');
        console.log('🔍 [EventPlanner] handleAddEvent: Button disabled:', this.isAddButtonDisabled);
        console.log('🔍 [EventPlanner] handleAddEvent: User logged in:', this.Activitydata);
        console.log('🔍 [EventPlanner] handleAddEvent: Selected date:', this.selectedDateString);

        // Prevent action if button is disabled
        if (this.isAddButtonDisabled) {
            console.log('🔍 [EventPlanner] handleAddEvent: Button is disabled, exiting');
            return;
        }

        if (!this.Activitydata) {
            console.log('🔍 [EventPlanner] handleAddEvent: User not logged in, showing warning toast');
            this.showToast(
                this.getloginlogoutlabel.Warning__c,
                this.getloginlogoutlabel.Kindly_do_the_Login_before_performing_th__c,
                'warning'
            );
            return;
        }

        console.log('🔍 [EventPlanner] handleAddEvent: Validation passed, transitioning to customer lookup view');
        // Show customer lookup component
        this.showCustomerLookup = true;
        this.showCalendar = false;
        this.showEvents = false;
        this.activeEvent = false;
        this.noActiveEvent = false;
        this.selectedDateEventsView = false;
        console.log('🔍 [EventPlanner] handleAddEvent: View state: showCustomerLookup=true, calendar hidden');
    }

    async handleShowCalendarFromLookup(data) {
        console.log('🔍 [EventPlanner] handleShowCalendarFromLookup: Received data from customer lookup');
        console.log('🔍 [EventPlanner] handleShowCalendarFromLookup: Data:', JSON.stringify(data, null, 2));

        // Determine event type
        const eventType = this.getEventTypeFromData(data.accountdata);
        console.log('🔍 [EventPlanner] handleShowCalendarFromLookup: Event type determined:', eventType);

        // Store selected data
        this.selectedEventType = eventType;
        const isStaticEvent = data.accountdata === 'Leave' ||
                              data.accountdata === 'Holiday' ||
                              data.accountdata === 'Out of Office';

        this.selectedAccountId = isStaticEvent ? null : data.accountdata;
        this.selectedAccountName = data.accountname || '';
        this.selectedCeRating = data.cerating || '';
        this.selectedCisRating = data.cisrating || '';
        this.selectedContactOptions = data.contactList || [];
        this.selectedProductData = data.product || '';
        this.selectedProductFamily = data.productFamily || '';
        this.selectedProductGroup = data.productGroup || '';
        this.selectedContactName = data.contact || '';
        this.selectedShowDataAttribute = data.showDataAttribute || '';

        console.log('🔍 [EventPlanner] handleShowCalendarFromLookup: Selected data stored:', {
            eventType,
            accountId: this.selectedAccountId,
            accountName: this.selectedAccountName,
            ceRating: this.selectedCeRating,
            cisRating: this.selectedCisRating,
            contactsCount: this.selectedContactOptions.length,
            product: this.selectedProductData
        });

        // Don't modify selectedDate here - keep it as Date object
        // If no date selected, set it to today
        if (!this.selectedDate) {
            this.selectedDate = new Date();
            console.log('🔍 [EventPlanner] handleShowCalendarFromLookup: No date selected, set to today');
        } else {
            console.log('🔍 [EventPlanner] handleShowCalendarFromLookup: Using previously selected date:', this.selectedDateString);
        }

        // Fetch BD plan data for Customer Visit events only
        // Case-insensitive check to handle 'Customer Visit' vs 'Customer visit'
        if (eventType && eventType.toLowerCase() === 'customer visit' && this.selectedAccountId) {
            console.log('🔍 [BD Tracker Debug] Fetching BD Plans...');
            console.log('🔍 [BD Tracker Debug] Account ID:', this.selectedAccountId);
            console.log('🔍 [BD Tracker Debug] User ID:', this.skey);

            this.spinner = true;
            try {
                this.bdplanlist = await getEventsForBDPlan({
                    accountid: this.selectedAccountId,
                    userid: this.skey,
                    action: 'create'
                });

                console.log('✅ [BD Tracker Debug] BD Plans fetched successfully');
                console.log('✅ [BD Tracker Debug] Number of BD Plans:', this.bdplanlist?.length || 0);
                console.log('✅ [BD Tracker Debug] BD Plans data:', JSON.stringify(this.bdplanlist, null, 2));
            } catch (error) {
                console.error('❌ [BD Tracker Debug] Error fetching BD plan data:', error);
                console.error('❌ [BD Tracker Debug] Error details:', JSON.stringify(error, null, 2));
                this.bdplanlist = [];
                this.showToast('Error', 'Failed to load BD plan data', 'warning');
            } finally {
                this.spinner = false;
            }
        } else {
            console.log('⚠️ [BD Tracker Debug] Not fetching BD Plans');
            console.log('⚠️ [BD Tracker Debug] Event Type:', eventType);
            console.log('⚠️ [BD Tracker Debug] Selected Account ID:', this.selectedAccountId);
            this.bdplanlist = [];
        }

        // Show event creation, hide lookup
        console.log('🔍 [EventPlanner] handleShowCalendarFromLookup: Transitioning to event creation form');
        this.showEventCreation = true;
        this.showCustomerLookup = false;
        this.showCalendar = false;
        console.log('🔍 [EventPlanner] handleShowCalendarFromLookup: View state: showEventCreation=true');
    }

    getEventTypeFromData(accountdata) {
        if (accountdata === 'Leave') return 'Leave';
        if (accountdata === 'Holiday') return 'Holiday';
        if (accountdata === 'Out of Office') return 'Out of office';
        return 'Customer visit';
    }

    handleBackToCalendar() {
        console.log('🔍 [EventPlanner] handleBackToCalendar: Back to calendar event received');
        // Return to calendar view
        this.showCustomerLookup = false;
        this.showEventCreation = false;
        this.showCalendar = true;
        this.showEvents = false;
        console.log('🔍 [EventPlanner] handleBackToCalendar: View state reset to showCalendar=true');

        // Clear selected data
        this.clearSelectedData();
        console.log('🔍 [EventPlanner] handleBackToCalendar: Selected data cleared');

        // Check if a date was previously selected
        if (this.selectedDateString) {
            console.log('🔍 [EventPlanner] handleBackToCalendar: Restoring previously selected date view:', this.selectedDateString);
            // Restore selected date events view
            if (this.selectedDateEvents.length > 0) {
                this.selectedDateEventsView = true;
                this.activeEvent = false;
                this.noActiveEvent = false;
                console.log('🔍 [EventPlanner] handleBackToCalendar: Showing selected date events view');
            } else {
                this.selectedDateEventsView = false;
                this.activeEvent = false;
                this.noActiveEvent = true;
                console.log('🔍 [EventPlanner] handleBackToCalendar: No events on selected date');
            }
        } else {
            // No date selected, restore today's events view
            this.selectedDateEventsView = false;
            if (this.todaysEvent.length > 0) {
                this.activeEvent = true;
                this.noActiveEvent = false;
                console.log('🔍 [EventPlanner] handleBackToCalendar: Showing today\'s events view');
            } else {
                this.activeEvent = false;
                this.noActiveEvent = true;
                console.log('🔍 [EventPlanner] handleBackToCalendar: Showing no events view');
            }
        }
    }

    handleEventSaved(event) {
        console.log('✅ [EventPlanner] handleEventSaved: Event saved successfully');
        console.log('✅ [EventPlanner] handleEventSaved: Event data:', event);

        // Event was saved successfully
        this.showEventCreation = false;
        this.showCustomerLookup = false;
        this.showCalendar = true;
        console.log('✅ [EventPlanner] handleEventSaved: Returning to calendar view');

        // Store selected date info before clearing (to restore after refresh)
        const wasDateSelected = this.selectedDateString !== null;
        const previouslySelectedDate = this.selectedDateString;
        console.log('✅ [EventPlanner] handleEventSaved: Previously selected date:', previouslySelectedDate);

        // Clear selected data
        this.clearSelectedData();
        console.log('✅ [EventPlanner] handleEventSaved: Selected data cleared');

        // Refresh events
        console.log('✅ [EventPlanner] handleEventSaved: Refreshing events using refreshApex()');
        this.spinner = true;
        refreshApex(this.events)
            .then(() => {
                console.log('✅ [EventPlanner] handleEventSaved: Events refreshed successfully');
                this.spinner = false;

                // Reload the page so Target checkbox/other components pick up the change
                setTimeout(() => window.location.reload(), 500);

                // If a date was previously selected or if we saved an event for a specific date,
                // restore the selection to show the newly created event
                if (wasDateSelected && previouslySelectedDate) {
                    console.log('✅ [EventPlanner] handleEventSaved: Restoring previously selected date view');
                    // Find the day data for the previously selected date
                    const dayData = this.calendarDays.find(day => day.date === previouslySelectedDate);
                    if (dayData && dayData.events.length > 0) {
                        // Restore selected date view
                        this.selectedDate = dayData.fullDate;
                        this.selectedDateString = previouslySelectedDate;
                        this.selectedDateEvents = dayData.events;

                        // Update date header
                        const splitdate = previouslySelectedDate.split('-');
                        this.dateOnHeader = splitdate[2] + '/' + splitdate[1] + '/' + splitdate[0];

                        // Show selected date events
                        this.selectedDateEventsView = true;
                        this.activeEvent = false;
                        this.noActiveEvent = false;

                        // Rebuild calendar to update visual selection
                        this.buildCalendarDays();
                        return;
                    }
                }

                // Otherwise, show today's events (default behavior)
                if (this.todaysEvent.length > 0) {
                    this.activeEvent = true;
                    this.noActiveEvent = false;
                    this.selectedDateEventsView = false;
                } else {
                    this.activeEvent = false;
                    this.noActiveEvent = true;
                    this.selectedDateEventsView = false;
                }
            })
            .catch(error => {
                console.error('Error reloading events:', error);
                this.spinner = false;
            });
    }

    handleEventCancelled() {
        console.log('🔍 [EventPlanner] handleEventCancelled: Event creation cancelled');
        // User cancelled event creation - return to calendar
        this.showEventCreation = false;
        this.showCustomerLookup = false;
        this.showCalendar = true;
        console.log('🔍 [EventPlanner] handleEventCancelled: Returning to calendar view');

        // Clear selected data
        this.clearSelectedData();
        console.log('🔍 [EventPlanner] handleEventCancelled: Selected data cleared');

        // Restore appropriate view
        if (this.todaysEvent.length > 0) {
            this.activeEvent = true;
            this.noActiveEvent = false;
            console.log('🔍 [EventPlanner] handleEventCancelled: Showing today\'s events view');
        } else {
            this.activeEvent = false;
            this.noActiveEvent = true;
            console.log('🔍 [EventPlanner] handleEventCancelled: Showing no events view');
        }
    }

    clearSelectedData() {
        this.selectedAccountId = null;
        this.selectedEventType = null;
        this.selectedCeRating = null;
        this.selectedCisRating = null;
        this.selectedContactOptions = [];
        this.selectedAccountName = '';
        this.selectedShowDataAttribute = '';
        this.selectedProductData = '';
        this.selectedProductFamily = '';
        this.selectedProductGroup = '';
        this.selectedContactName = '';
        this.bdplanlist = [];
    }

    handleReloadBDPlan() {
        console.log('🔄 [EventPlanner] handleReloadBDPlan: Reload BD Plan event received');
        // Reload BD plan data after linking
        if (this.selectedAccountId && this.selectedEventType === 'Customer Visit') {
            console.log('🔄 [EventPlanner] handleReloadBDPlan: Reloading BD Plans for account:', this.selectedAccountId);
            getEventsForBDPlan({
                accountid: this.selectedAccountId,
                userid: this.skey,
                action: 'create'
            })
                .then(result => {
                    console.log('✅ [EventPlanner] handleReloadBDPlan: BD Plans reloaded, count:', result.length);
                    this.bdplanlist = result;
                })
                .catch(error => {
                    console.error('❌ [EventPlanner] handleReloadBDPlan: Error reloading BD plan data:', error);
                });
        } else {
            console.log('🔄 [EventPlanner] handleReloadBDPlan: Conditions not met for reload (accountId:', this.selectedAccountId, 'eventType:', this.selectedEventType + ')');
        }
    }

    handleReloadEvents() {
        console.log('🔄 [EventPlanner] handleReloadEvents: Reload events pubsub event received');
        this.spinner = true;
        console.log('🔄 [EventPlanner] handleReloadEvents: Calling refreshApex()');
        return refreshApex(this.events)
            .then(() => {
                console.log('✅ [EventPlanner] handleReloadEvents: Events reloaded successfully');
                this.spinner = false;
            })
            .catch(error => {
                console.error('❌ [EventPlanner] handleReloadEvents: Error reloading events:', error);
                this.spinner = false;
            });
    }

    // Event Editing Handlers
    handleEventClick(event) {
        console.log('🔍 [EventPlanner] handleEventClick: Event card clicked');
        const eventId = event.currentTarget.dataset.id;
        console.log('🔍 [EventPlanner] handleEventClick: Event ID:', eventId);
        this.eventRecordId = eventId;

        // Find the event in either todaysEvent or selectedDateEvents
        const allEvents = [...this.todaysEvent, ...this.selectedDateEvents];
        console.log('🔍 [EventPlanner] handleEventClick: Searching in', allEvents.length, 'events');
        const selectedEvent = allEvents.find(evt => evt.Id === eventId);

        if (selectedEvent) {
            console.log('🔍 [EventPlanner] handleEventClick: Event found');
            console.log('🔍 [EventPlanner] handleEventClick: Event details:', {
                Id: selectedEvent.Id,
                Subject: selectedEvent.Subject,
                Status: selectedEvent.Status,
                Stage: selectedEvent.stage,
                OtherType: selectedEvent.OtherType,
                AccountName: selectedEvent.AccountName
            });
            this.eventObj = JSON.parse(JSON.stringify(selectedEvent));
            this.eventObj.Product = selectedEvent.Product;
            this.accountId = selectedEvent.AccountId;

            // Determine if it's an "Other Type" event (Leave, Holiday, Out of office)
            this.otherType = selectedEvent.OtherType || false;
            console.log('🔍 [EventPlanner] handleEventClick: Other Type event:', this.otherType);

            // Check if event can be edited (only Planned events can change date)
            this.eventstage = selectedEvent.stage !== 'Planned';
            console.log('🔍 [EventPlanner] handleEventClick: Event stage editable:', !this.eventstage, '(stage:', selectedEvent.stage + ')');

            // Initialize update map
            this.updateEventMap = {
                Id: eventId,
                Subject: selectedEvent.Subject,
                Call_Type__c: selectedEvent.CallType,
                ActivityDate: selectedEvent.ActivityDate,
                Follow_Up_Date__c: selectedEvent.FollowUpDate,
                Product__c: selectedEvent.Product,
                DCR_Description__c: selectedEvent.Description || null,
                StartDateTime: selectedEvent.ActivityDate,
                EndDateTime: selectedEvent.ActivityDate
            };
            console.log('🔍 [EventPlanner] handleEventClick: Update map initialized:', JSON.stringify(this.updateEventMap, null, 2));

            this.modalCurrentCallType = selectedEvent.CallType || '';
            this.modalEnableProductOption = selectedEvent.CallType === 'In Clinic Branding' && !!selectedEvent.SubCallType;
            this.modalSelectedProducts = selectedEvent.Product
                ? selectedEvent.Product.split(';').filter(p => p.trim())
                : [];
            this.showEditEventModal = true;
            this.loadModalProductOptions();
            console.log('🔍 [EventPlanner] handleEventClick: Showing edit modal');
        } else {
            console.log('🔍 [EventPlanner] handleEventClick: Event NOT found with ID:', eventId);
        }
    }

    handleCloseModal() {
        this.showEditEventModal = false;
        this.eventObj = {};
        this.modalProductOptions = [];
        this.modalSelectedProducts = [];
        this.modalEnableProductOption = false;
        this.modalCurrentCallType = '';
        this.updateEventMap = {};
    }

    handleFieldChange(event) {
        const fieldName = event.target.name;
        const fieldValue = event.target.value;
        console.log('🔍 [EventPlanner] handleFieldChange: Field changed:', fieldName, '→', fieldValue);

        this.updateEventMap[fieldName] = fieldValue;

        // If ActivityDate changes, update Start and End DateTime
        if (fieldName === 'ActivityDate') {
            this.updateEventMap.StartDateTime = fieldValue;
            this.updateEventMap.EndDateTime = fieldValue;
            console.log('🔍 [EventPlanner] handleFieldChange: ActivityDate changed, also updated StartDateTime and EndDateTime');
        }
    }

    handleSelectProduct(event) {
        this.modalSelectedProducts = event.detail.value || [];
        const productString = this.modalSelectedProducts.join(';');
        this.eventObj.Product = productString;
        this.updateEventMap.Product__c = productString;
    }

    async loadModalProductOptions() {
        try {
            if (this.modalEnableProductOption && this.eventObj.SubCallType) {
                const result = await getProductsBySubCallType({ subCallType: this.eventObj.SubCallType });
                this.modalProductOptions = result.map(p => ({ label: p.label, value: p.value }));
            } else {
                const result = await getProducts({ searchKey: null });
                this.modalProductOptions = result.map(p => ({ label: p.Name, value: p.Name }));
            }
        } catch (error) {
            console.error('Error loading product options:', error);
            this.modalProductOptions = [];
        }
    }

    handleUpdateEvent() {
        console.log('🔄 [EventPlanner] handleUpdateEvent: Update button clicked');
        console.log('🔄 [EventPlanner] handleUpdateEvent: Update map:', JSON.stringify(this.updateEventMap, null, 2));
        this.spinner = true;

        // Save ActivityDate before clearing the map
        const activityDate = this.updateEventMap.ActivityDate;
        console.log('🔄 [EventPlanner] handleUpdateEvent: Activity date:', activityDate);

        // Store selected date info before clearing (to restore after refresh)
        const wasDateSelected = this.selectedDateString !== null;
        const previouslySelectedDate = this.selectedDateString;
        console.log('🔄 [EventPlanner] handleUpdateEvent: Previously selected date:', previouslySelectedDate);

        console.log('🔄 [EventPlanner] handleUpdateEvent: Calling updateEventData Apex method');
        updateEventData({ dataMap: this.updateEventMap })
            .then(() => {
                console.log('✅ [EventPlanner] handleUpdateEvent: Event updated successfully');
                this.showToast('Event Updated', 'Event Updated Successfully', 'success');
                this.showEditEventModal = false;
                this.eventObj = {};
                this.updateEventMap = {};

                // Reload events
                fireEvent(this.pageRef, 'reloadEvents', activityDate);
                return refreshApex(this.events);
            })
            .then(() => {
                this.spinner = false;

                // If a date was previously selected, update the selected date view
                if (wasDateSelected && previouslySelectedDate) {
                    // Find the day data for the previously selected date
                    const dayData = this.calendarDays.find(day => day.date === previouslySelectedDate);
                    if (dayData && dayData.events.length > 0) {
                        // Restore selected date view
                        this.selectedDate = dayData.fullDate;
                        this.selectedDateString = previouslySelectedDate;
                        this.selectedDateEvents = dayData.events;

                        // Update date header
                        const splitdate = previouslySelectedDate.split('-');
                        this.dateOnHeader = splitdate[2] + '/' + splitdate[1] + '/' + splitdate[0];

                        // Show selected date events
                        this.selectedDateEventsView = true;
                        this.activeEvent = false;
                        this.noActiveEvent = false;

                        // Rebuild calendar to update visual selection
                        this.buildCalendarDays();
                        return;
                    }
                }

                // Otherwise, update today's events view (default behavior)
                if (this.todaysEvent.length > 0) {
                    this.activeEvent = true;
                    this.noActiveEvent = false;
                    this.selectedDateEventsView = false;
                } else {
                    this.activeEvent = false;
                    this.noActiveEvent = true;
                    this.selectedDateEventsView = false;
                }
            })
            .catch(error => {
                console.error('Error updating event:', error);
                this.showToast('Error', error.body?.message || 'Failed to update event', 'error');
                this.spinner = false;
            });
    }

    handleDeleteEvent() {
        console.log('🔄 [EventPlanner] handleDeleteEvent: Delete button clicked');
        console.log('🔄 [EventPlanner] handleDeleteEvent: Event to delete:', this.updateEventMap.Id);
        this.spinner = true;

        // Added by Priyam Shah - Save ActivityDate before clearing eventObj for reload
        const activityDate = this.eventObj.ActivityDate;
        console.log('🔄 [EventPlanner] handleDeleteEvent: Activity date:', activityDate);

        // Store selected date info before clearing (to restore/update after refresh)
        const wasDateSelected = this.selectedDateString !== null;
        const previouslySelectedDate = this.selectedDateString;
        console.log('🔄 [EventPlanner] handleDeleteEvent: Previously selected date:', previouslySelectedDate);

        console.log('🔄 [EventPlanner] handleDeleteEvent: Calling deleteEventData Apex method');
        deleteEventData({ dataMap: this.updateEventMap })
            .then(() => {
                console.log('✅ [EventPlanner] handleDeleteEvent: Event deleted successfully');
                this.showToast('Event Deleted', 'Event Deleted Successfully', 'success');
                this.showEditEventModal = false;
                this.eventObj = {};
                this.updateEventMap = {};

                // Added by Priyam Shah - Use saved activityDate for reload
                fireEvent(this.pageRef, 'reloadEvents', activityDate);
                return refreshApex(this.events);
            })
            .then(() => {
                this.spinner = false;

                // Reload the page so Target checkbox/other components pick up the change
                setTimeout(() => window.location.reload(), 500);

                // If a date was previously selected, update the selected date view
                if (wasDateSelected && previouslySelectedDate) {
                    // Find the day data for the previously selected date
                    const dayData = this.calendarDays.find(day => day.date === previouslySelectedDate);

                    // Update selected date events (may now be empty after deletion)
                    if (dayData) {
                        this.selectedDate = dayData.fullDate;
                        this.selectedDateString = previouslySelectedDate;
                        this.selectedDateEvents = dayData.events;

                        // Update date header
                        const splitdate = previouslySelectedDate.split('-');
                        this.dateOnHeader = splitdate[2] + '/' + splitdate[1] + '/' + splitdate[0];

                        // Update view flags based on whether there are still events
                        if (dayData.events.length > 0) {
                            this.selectedDateEventsView = true;
                            this.activeEvent = false;
                            this.noActiveEvent = false;
                        } else {
                            // No events left on this date
                            this.selectedDateEventsView = false;
                            this.activeEvent = false;
                            this.noActiveEvent = true;
                        }

                        // Rebuild calendar to update event counts
                        this.buildCalendarDays();
                        return;
                    }
                }

                // Otherwise, update today's events view (default behavior)
                if (this.todaysEvent.length > 0) {
                    this.activeEvent = true;
                    this.noActiveEvent = false;
                    this.selectedDateEventsView = false;
                } else {
                    this.activeEvent = false;
                    this.noActiveEvent = true;
                    this.selectedDateEventsView = false;
                }
            })
            .catch(error => {
                console.error('Error deleting event:', error);
                this.showToast('Error', error.body?.message || 'Failed to delete event', 'error');
                this.spinner = false;
            });
    }

    handleUpdateLead() {
        this.spinner = true;

        getLeadData({ leadId: this.eventRecordId })
            .then(result => {
                console.log('Lead result', result);
                this.leadData = result;
                this.showEditEventModal = false;
                this.showUpdateLeadModal = true;
                this.spinner = false;
            })
            .catch(error => {
                console.error('Error fetching lead data:', error);
                this.showToast('Error', 'Failed to fetch lead data', 'error');
                this.spinner = false;
            });
    }

    handleCloseLeadModal() {
        this.showUpdateLeadModal = false;
        this.showEditEventModal = true;
        this.leadData = [];
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    // Getters for template
    get currentMonthName() {
        const monthName = this.monthNames[this.currentMonth];
        console.log('📊 [EventPlanner] currentMonthName: Returning month name:', monthName);
        return monthName;
    }

    // Get formatted date for event creation (MM/DD/YYYY format for Apex)
    get formattedDateForEvent() {
        if (!this.selectedDate) {
            const formatted = this.formatDateForApex(new Date());
            console.log('📊 [EventPlanner] formattedDateForEvent: No selected date, using today:', formatted);
            return formatted;
        }
        const formatted = this.formatDateForApex(this.selectedDate);
        console.log('📊 [EventPlanner] formattedDateForEvent: Using selected date:', formatted);
        return formatted;
    }

    get isAddButtonDisabled() {
        const isDisabled = !this.isEventCreate || !this.Activitydata;
        console.log('📊 [EventPlanner] isAddButtonDisabled: Button disabled:', isDisabled, '(isEventCreate:', this.isEventCreate, 'Activitydata:', this.Activitydata + ')');
        return isDisabled;
    }

    get addButtonWrapperClass() {
        const baseClass = 'icon-button-wrapper icon-button-wrapper--brand';
        return this.isAddButtonDisabled
            ? `${baseClass} icon-button-wrapper--disabled`
            : baseClass;
    }

    // Get calendar weeks (6 weeks of 7 days each)
    get calendarWeeks() {
        const weeks = [];
        for (let i = 0; i < 6; i++) {
            const week = {
                key: `week-${i}`,
                days: this.calendarDays.slice(i * 7, (i + 1) * 7)
            };
            weeks.push(week);
        }
        console.log('📊 [EventPlanner] calendarWeeks: Created', weeks.length, 'weeks from', this.calendarDays.length, 'days');
        return weeks;
    }

    // Get today's events with computed cardColorClass
    get todaysEventWithCardClass() {
        const eventsWithClass = this.todaysEvent.map(event => ({
            ...event,
            cardColorClass: `slds-card event-card ${event.cardColor || 'default'}`
        }));
        console.log('📊 [EventPlanner] todaysEventWithCardClass: Returning', eventsWithClass.length, 'events with card classes');
        return eventsWithClass;
    }

    // Get selected date events with computed cardColorClass
    get selectedDateEventsWithCardClass() {
        const eventsWithClass = this.selectedDateEvents.map(event => ({
            ...event,
            cardColorClass: `slds-card event-card ${event.cardColor || 'default'}`
        }));
        console.log('📊 [EventPlanner] selectedDateEventsWithCardClass: Returning', eventsWithClass.length, 'events with card classes');
        return eventsWithClass;
    }
}