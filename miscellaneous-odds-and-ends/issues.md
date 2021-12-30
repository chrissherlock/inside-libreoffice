# Issues

The following are issues I have noticed in LibreOffice:

### VCL

* OutputDevice is tightly coupled to Window, Printer and VirtualDevice - not for instance that in many parts of the code you must call upon GetOutDevType() to find out if the class you are invoking is a Printer, VirtualDevice or Window!
