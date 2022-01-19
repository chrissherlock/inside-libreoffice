## Issues

The following are issues I have noticed in LibreOffice - they are my opinion, but others may disagree so take it all with a grain of salt:

### VCL

* OutputDevice is tightly coupled to Window, Printer and VirtualDevice - not for instance that in many parts of the code you must call upon GetOutDevType() to find out if the class you are invoking is a Printer, VirtualDevice or Window!
* Metafile recording is tightly coupled to OutputDevice
* Text layout handling is all done in OutputDevice - I don't see why this should be the case. Text layout should be handled in its own class.
