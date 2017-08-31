# Sockets

A socket is a mean for two programs to communicate with each other via file descriptors. Each socket represents a communication end point, each socket is associated \(or _bound_\) to a network address, and programs communicate with each other by opening a local socket, which it then _connects_ to a remote socket that is listening for connections, after which data is sent and received via this two-way connection.

