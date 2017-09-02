# Sockets

A socket is a mean for two programs to communicate with each other via file descriptors. Each socket represents a communication end point, each socket is associated \(or _bound_\) to a network address, and programs communicate with each other by opening a local socket, which it then _connects_ to a remote socket that is listening for connections, after which data is sent and received via this two-way connection.

A program that listens for incoming connections on a socket and responds to those connection requests is called a _server_. A program that makes a connection to a server is called a _client_. A socket server works as follows:

1. Create a socket
2. Assign \(or _bind_\) a network address and port to the socket
3. _Listen_ on the socket for incoming connections
4. If a client makes a connection request, then _accept_ the connection

This forms a channel between the server and the client, from which the server can read and write data.

A client works as follows:

1. Create a socket
2. _Connect_ the socket to a remote address and port

Once the remote server accepts the connection a channel between the server and client is formed, and the client can similarly read and write data on this channel.

### Example

The following example is from [my private branch](https://cgit.freedesktop.org/libreoffice/core/log/?h=private/tbsdy/workbench) in the LibreOffice git repository.

This example basically runs on two threads: the main thread which runs the client, and a second background threat that runs the server that the client connects to. Essentially, the program first opens a socket, binds this to the localhost address 127.0.0.1 on port 30,000 \(a high port\), and then listens for connections. The client is run after this server thread which opens its own socket, then connects to the remote server and sends a single character to it, which the server receives and echos to the screen. A condition variable is used to ensure that the client doesn't try to connect to the server before it has started listening.

[.../sal/workben/osl/socket/socket.cxx](https://cgit.freedesktop.org/libreoffice/core/tree/sal/workben/osl/socket/socket.cxx?h=private/tbsdy/workbench)

```cpp
#include <sal/main.h>
#include <rtl/ustring.h>
#include <osl/thread.h>
#include <osl/conditn.h>
#include <osl/socket.h>

#include <cstdio>

oslThread serverThread;
oslCondition serverReady;

void server(void*);
void client();

SAL_IMPLEMENT_MAIN()
{
    fprintf(stdout, "Demonstrates sockets.\n");

    serverReady = osl_createCondition();
    serverThread = osl_createThread(server, nullptr);
    osl_waitCondition(serverReady, nullptr);
    client();
    osl_joinWithThread(serverThread);

    return 0;
}

void client()
{
    oslSocket socket = osl_createSocket(osl_Socket_FamilyInet, osl_Socket_TypeStream, osl_Socket_ProtocolIp);

    rtl_uString *pstrLocalHostAddr = nullptr;
    rtl_string2UString(&pstrLocalHostAddr, "127.0.0.1", 9, osl_getThreadTextEncoding(), OSTRING_TO_OUSTRING_CVTFLAGS);

    // high port on localhost address
    oslSocketAddr addr = osl_createInetSocketAddr(pstrLocalHostAddr, 30000);

    if (osl_connectSocketTo(socket, addr, nullptr) != osl_Socket_Ok)
    {
        fprintf(stderr, "**Client**    Could not bind address to socket.\n");
        exit(1);
    }

    char sendBuffer = 'c';
    sal_Int32 nSentChar = osl_sendSocket(socket, &sendBuffer, 1, osl_Socket_MsgNormal);
    fprintf(stdout, "**Client**    Sent %d character.\n", nSentChar);
}

void server(void* /* pData */)
{
    oslSocket socket = osl_createSocket(osl_Socket_FamilyInet, osl_Socket_TypeStream, osl_Socket_ProtocolIp);

    rtl_uString *pstrLocalHostAddr = nullptr;
    rtl_string2UString(&pstrLocalHostAddr, "127.0.0.1", 9, osl_getThreadTextEncoding(), OSTRING_TO_OUSTRING_CVTFLAGS);

    fprintf(stdout, "**Server**    Listening on localhost...\n");
    // create high port on localhost address
    fprintf(stdout, "**Server**    Create socket\n");
    oslSocketAddr addr = osl_createInetSocketAddr(pstrLocalHostAddr, 30000);

    fprintf(stdout, "**Server**    Bind address to socket\n");
    if (osl_bindAddrToSocket(socket, addr) == sal_False)
    {
        fprintf(stderr, "Could not bind address to socket.\n");
        exit(1);
    }

    fprintf(stdout, "**Server**    Listen on socket...\n");
    if (osl_listenOnSocket(socket, -1) == sal_False)
    {
        fprintf(stderr, "**Client** Could not listen on socket.\n");
        exit(1);
    }

    osl_setCondition(serverReady);

    fprintf(stdout, "**Server**    Accept connection...\n");
    oslSocket inboundSocket = osl_acceptConnectionOnSocket(socket, &addr);

    fprintf(stdout, "**Server**    Receive data...\n");
    char buffer;
    osl_receiveSocket(inboundSocket, &buffer, 1, osl_Socket_MsgNormal);

    fprintf(stdout, "**Server**    Received character %c\n", buffer);
}
```



