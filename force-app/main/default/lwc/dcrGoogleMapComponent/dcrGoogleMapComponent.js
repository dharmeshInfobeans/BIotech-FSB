import { LightningElement, api, track } from 'lwc';

/**
 * @description Lightning Map component for displaying visit locations
 * @author Priyam Shah
 * @date 2026-01-19
 */
export default class DcrGoogleMapComponent extends LightningElement {
    @track _eventList = [];
    @track _userLocation = null;
    @track _selectedMarkerValue = null;
    @track _mapCenter = null; // Tracks current map center for panning

    @api
    get eventList() {
        return this._eventList;
    }
    set eventList(value) {
        this._eventList = value || [];
    }

    @api
    get userLocation() {
        return this._userLocation;
    }
    set userLocation(value) {
        this._userLocation = value;
        console.log('DcrGoogleMapComponent received userLocation:', value);
        // Set initial map center to user location
        if (value?.latitude && value?.longitude && !this._mapCenter) {
            this._mapCenter = {
                location: {
                    Latitude: value.latitude,
                    Longitude: value.longitude
                }
            };
        }
    }

    @api
    get selectedMarkerValue() {
        return this._selectedMarkerValue;
    }
    set selectedMarkerValue(value) {
        this._selectedMarkerValue = value;
        console.log('DcrGoogleMapComponent selected marker:', value);
        // Pan to the selected marker
        this.panToMarker(value);
    }

    // Zoom level 17 matches the original VF page
    zoomLevel = 17;


    /**
     * Configures the Google Maps UI to show ONLY zoom buttons.
     */
    mapOptions = {
        disableDefaultUI: true, // Removes all default controls
        zoomControl: true,      // Specifically enables +/- buttons
        streetViewControl: false,
        mapTypeControl: false,
        fullscreenControl: false,
        gestureHandling: 'greedy'
    };



    /**
     * @description Check if we have data to display markers
     */
    get hasMarkers() {
        const hasUserLocation = this._userLocation?.latitude && this._userLocation?.longitude;
        const hasEvents = this._eventList?.length > 0;
        return hasUserLocation || hasEvents;
    }

    /**
     * @description Computed map markers from eventList and userLocation
     */
    get mapMarkers() {
        const markers = [];

        // Add user location marker (if available) - shown first like original VF
        if (this._userLocation?.latitude && this._userLocation?.longitude) {
            markers.push({
                location: {
                    Latitude: this._userLocation.latitude,
                    Longitude: this._userLocation.longitude
                },
                value: 'user-location',
                title: 'Your Location',
                description: 'Current position',
                icon: 'custom:custom26'
            });
        }

        // Add event markers
        if (this._eventList?.length > 0) {
            this._eventList.forEach((event, index) => {
                const isLead = event.Leads__c != null;
                const isOpportunity = event.WhatId != null && event.What?.Type === 'Opportunity__c';

                // Get name based on event type
                let name;
                if (isLead) {
                    name = event.Leads__r?.Name;
                } else if (isOpportunity) {
                    name = event.What?.Name; // Opportunity name
                } else {
                    name = event.Account__r?.Name;
                }

                const street = event.BillingStreet__c || '';
                const city = event.BillingCity__c || '';

                // Priority for coordinates:
                // 1. Event coordinates (Event_Latitude__c / Lead_Latitude__c)
                // 2. Account BillingLatitude/BillingLongitude (for Accounts or Opportunity's Account)
                let lat = isLead ? event.Lead_Latitude__c : event.Event_Latitude__c;
                let lng = isLead ? event.Lead_Longitude__c : event.Event_Longitude__c;
                let coordSource = 'Event';

                console.log(`Event ${index + 1} (${name}):`, {
                    isLead,
                    isOpportunity,
                    eventLat: event.Event_Latitude__c,
                    eventLng: event.Event_Longitude__c,
                    leadLat: event.Lead_Latitude__c,
                    leadLng: event.Lead_Longitude__c,
                    accountLat: event.Account__r?.BillingLatitude,
                    accountLng: event.Account__r?.BillingLongitude
                });

                // Fallback to Account's BillingLatitude/BillingLongitude if event coordinates not available
                if (!lat || !lng) {
                    if (!isLead && event.Account__r) {
                        lat = event.Account__r.BillingLatitude;
                        lng = event.Account__r.BillingLongitude;
                        coordSource = 'Account';
                    }
                }

                console.log(`Event ${index + 1} using ${coordSource} coordinates:`, { lat, lng });

                // If coordinates are available, use them
                if (lat && lng) {
                    markers.push({
                        location: {
                            Latitude: lat,
                            Longitude: lng
                        },
                        value: event.Id,
                        title: `${index + 1}. ${name || 'Visit'}`,
                        description: `${street}${street && city ? ', ' : ''}${city}`,
                        icon: 'standard:account'
                    });
                } else if (street || city) {
                    console.log(`Event ${index + 1} using address fallback:`, { street, city });
                    // Fallback to address-based marker if no coordinates at all
                    markers.push({
                        location: {
                            Street: street,
                            City: city
                        },
                        value: event.Id,
                        title: `${index + 1}. ${name || 'Visit'}`,
                        description: `${street}${street && city ? ', ' : ''}${city}`,
                        icon: 'standard:account'
                    });
                } else {
                    console.log(`Event ${index + 1} has no coordinates or address - marker not added`);
                }
            });
        }

        console.log('DcrGoogleMapComponent mapMarkers:', markers);
        return markers;
    }

    /**
     * @description Computed map center - uses tracked _mapCenter for panning
     */
    get mapCenter() {
        // Return tracked center if set (for panning)
        if (this._mapCenter) {
            return this._mapCenter;
        }
        // Default to user location
        if (this._userLocation?.latitude && this._userLocation?.longitude) {
            return {
                location: {
                    Latitude: this._userLocation.latitude,
                    Longitude: this._userLocation.longitude
                }
            };
        }
        return {};
    }

    /**
     * @description Check if user location is available (for showing My Location button)
     */
    get hasUserLocation() {
        return this._userLocation?.latitude && this._userLocation?.longitude;
    }

    /**
     * @description Pan the map to the selected marker's location
     */
    panToMarker(markerValue) {
        if (!markerValue) return;

        console.log('Panning to marker:', markerValue);

        // If user location marker
        if (markerValue === 'user-location') {
            if (this._userLocation?.latitude && this._userLocation?.longitude) {
                this._mapCenter = {
                    location: {
                        Latitude: this._userLocation.latitude,
                        Longitude: this._userLocation.longitude
                    }
                };
                console.log('Panning to user location:', this._mapCenter);
            }
            return;
        }

        // Find the event with matching ID
        const event = this._eventList?.find(e => e.Id === markerValue);
        if (!event) {
            console.log('Event not found for marker:', markerValue);
            return;
        }

        // Get coordinates using same logic as mapMarkers
        const isLead = event.Leads__c != null;
        let lat = isLead ? event.Lead_Latitude__c : event.Event_Latitude__c;
        let lng = isLead ? event.Lead_Longitude__c : event.Event_Longitude__c;

        // Fallback to Account coordinates
        if (!lat || !lng) {
            if (!isLead && event.Account__r) {
                lat = event.Account__r.BillingLatitude;
                lng = event.Account__r.BillingLongitude;
            }
        }

        if (lat && lng) {
            this._mapCenter = {
                location: {
                    Latitude: lat,
                    Longitude: lng
                }
            };
            console.log('Panning to event location:', this._mapCenter);
        }
    }

    /**
     * @description Handle click on My Location button - focuses map on user's location marker
     */
    handleMyLocationClick() {
        console.log('My Location button clicked');

        if (this._userLocation?.latitude && this._userLocation?.longitude) {
            // Update selected marker
            this._selectedMarkerValue = 'user-location';

            // Force map to re-center by creating a new object reference
            this._mapCenter = {
                location: {
                    Latitude: this._userLocation.latitude,
                    Longitude: this._userLocation.longitude
                }
            };
            console.log('Forced pan to user location:', this._mapCenter);
        }
    }
}