# GPS Stone Trip Recorder
Register your trips and export them as GPX files.

## Notes
We currently have included a `UIRequiredDeviceCapabilities` with a `location-services`
value (`gps` is too much I think, we don’t need GPS accuracy to be able to record something).
Later (when we offer trip sync w/ iCloud) we should probably get rid of this required capability!

When the user disable the location manager to get the current location, the buttons
Record my location in the info view and the detailed view must be disabled (or replaced
by some text asking the user to enable the app to know the user location).

We should use the `locationServicesEnabled` at some point. Just ask location services
when location services are disabled if the user explicitely tapped the recording button.

## Archived Note (Deleted When I’m sure I Won’t need It Anymore)
```objective-c
/* Here is the code to parse a GPX file. gpxElement is an instance variable. */
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
	if ([elementName isEqualToString:@"gpx"]) {
		gpxElement = [[GPXgpxType alloc] initWithAttributes:attributeDict elementName:elementName];
		parser.delegate = gpxElement;
	}
}

- (void)startParsing
{
	NSString *path = @"Path to gpx file";
	NSXMLParser *parser = [[NSXMLParser alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]];
	[parser setDelegate:self];
	[parser parse];
	[gpxElement release];
}
```
