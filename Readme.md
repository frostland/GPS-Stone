# GPS Stone
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
