import ballerinax/googleapis_calendar as calendar;
import ballerinax/twilio;
import ballerina/websub;
import ballerina/config;

listener websub:Listener googleListener = new websub:Listener(4567);

calendar:CalendarConfiguration calendarConfig = {
    oauth2Config: {
        accessToken: config:getAsString("ACCESS_TOKEN"),
        refreshConfig: {
            refreshUrl: config:getAsString("REFRESH_URL"),
            refreshToken: config:getAsString("REFRESH_TOKEN"),
            clientId: config:getAsString("CLIENT_ID"),
            clientSecret: config:getAsString("CLIENT_SECRET")
        }
    }
};

calendar:CalendarClient calendarClient = new (calendarConfig);

twilio:TwilioConfiguration twilioConfig = {
    accountSId: config:getAsString("ACCOUNT_SID"),
    authToken: config:getAsString("AUTH_TOKEN"),
    xAuthyKey: config:getAsString("AUTHY_API_KEY")
};

twilio:Client twilioClient = new (twilioConfig);

string? syncToken = ();
string fromMobile = config:getAsString("SAMPLE_FROM_MOBILE");
string toMobile = config:getAsString("SAMPLE_TO_MOBILE");

@websub:SubscriberServiceConfig {subscribeOnStartUp: false}
service websub:SubscriberService /websub on googleListener {
    remote function onNotification(websub:Notification notification) {
        if (notification.getHeader("X-Goog-Channel-ID") == config:getAsString("CHANNEL_ID") && notification.getHeader(
        "X-Goog-Resource-ID") == config:getAsString("RESOURCE-ID")) {      // resource id has to be taken from watch api response
            if (notification.getHeader("X-Goog-Resource-State") == "sync") {
                calendar:EventResponse|error resp = calendarClient->getEventResponse(config:getAsString("CALENDAR_ID"), 1);
                if (resp is calendar:EventResponse) {
                    syncToken = <@untainted>resp?.nextSyncToken;
                }
            }
            if (notification.getHeader("X-Goog-Resource-State") == "exists") {
                calendar:EventResponse|error resp = calendarClient->getEventResponse(config:getAsString("CALENDAR_ID"), 
                (), syncToken);
                if (resp is calendar:EventResponse) {
                    syncToken = <@untainted>resp?.nextSyncToken;
                    calendar:Event[] events = resp.items;
                    if (events.length() > 0) {
                        calendar:Event env = events[0];
                        string? created = env?.created;
                        string? updated = env?.updated;
                        calendar:Time? 'start = env?.'start;
                        calendar:Time? end = env?.end;
                        if (created is string && updated is string && 'start is calendar:Time && end is calendar:Time) {
                            if (created.substring(0, 19) == updated.substring(0, 19)) {
                                string? summary = env?.summary;
                                string message = "";
                                if (summary is string) {
                                    message = "New event is created : " + summary + "  starts on " + 'start.
                                    dateTime + " ends on " + end.dateTime;
                                } else {
                                    message = "New event is created : starts  on " + 'start.dateTime + " ends on " + end.
                                    dateTime;
                                }
                                var details = twilioClient->sendSms(fromMobile, toMobile, message);
                            }
                        }
                    }
                }
            }
        }
    }
}
