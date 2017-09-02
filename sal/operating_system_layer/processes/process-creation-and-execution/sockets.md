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

## Socket creation

A socket is created via the API function `osl_createSocket()` . A socket consists of a _family_, _type_ and \_protocol. \_The OSL supports the IP and IPX/SPX families \(though to be frank, IPX/SPX is obsolete\). The type of socket can be stream \(a connection-oriented, sequenced and unique flow of data\), datagram \(a connection-less point for data packets with well defined boundaries\), raw \(socket users aren't aware of encapsulating headers, so can process them directly\), RDM and sequenced packet. Each family has one or more protocols - currently OSL sockets support the IPv4 protocol.

Sockets are very similar between Unix and Windows, however sockets were introduced late in the Windows world, whilst sockets were invented on Unix. The Unix socket creation function is as follows:

```cpp
oslSocket SAL_CALL osl_createSocket(
    oslAddrFamily Family,
    oslSocketType Type,
    oslProtocol Protocol)
{
    oslSocket pSocket;

    /* alloc memory */
    pSocket= createSocketImpl(OSL_INVALID_SOCKET);

    /* create socket */
    pSocket->m_Socket= socket(FAMILY_TO_NATIVE(Family),
                                TYPE_TO_NATIVE(Type),
                                PROTOCOL_TO_NATIVE(Protocol));

    /* creation failed => free memory */
    if(pSocket->m_Socket == OSL_INVALID_SOCKET)
    {
        int nErrno = errno;
        SAL_WARN( "sal.osl", "socket creation failed: (" << nErrno << ") " << strerror(nErrno) );

        destroySocketImpl(pSocket);
        pSocket= nullptr;
    }
    else
    {
        sal_Int32 nFlags=0;
        /* set close-on-exec flag */
        if ((nFlags = fcntl(pSocket->m_Socket, F_GETFD, 0)) != -1)
        {
            nFlags |= FD_CLOEXEC;
            if (fcntl(pSocket->m_Socket, F_SETFD, nFlags) == -1)
            {
                pSocket->m_nLastError=errno;
                int nErrno = errno;
                SAL_WARN( "sal.osl", "failed changing socket flags: (" << nErrno << ") " << strerror(nErrno) );
            }
        }
        else
        {
            pSocket->m_nLastError=errno;
        }
    }

    return pSocket;
}
```

`createSocketImpl()` is actually just an initialization of the internal `oslSocket` structure. The creation of the actual socket is done via calling the `socket()` function, which returns the socket file descriptor. In the Unix version of creating a socket, we also set the close-on-exec flag via `fcntl()`. What this means is that if any forked children call on an exec function, then the socket file descriptor will be closed automatically, which prevents FD leaks from occurring.

The Windows version of `osl_createSocket()` is as follows:

```cpp
oslSocket SAL_CALL osl_createSocket(
    oslAddrFamily Family,
    oslSocketType Type,
    oslProtocol Protocol)
{
    /* alloc memory */
    oslSocket pSocket = createSocketImpl(0);

    if (pSocket == nullptr)
        return nullptr;

    /* create socket */
    pSocket->m_Socket = socket(FAMILY_TO_NATIVE(Family),
                               TYPE_TO_NATIVE(Type),
                               PROTOCOL_TO_NATIVE(Protocol));

    /* creation failed => free memory */
    if(pSocket->m_Socket == OSL_INVALID_SOCKET)
    {
        int nErrno = WSAGetLastError();
        wchar_t *sErr = nullptr;
        FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                       nullptr, nErrno,
                       MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                       reinterpret_cast<LPWSTR>(&sErr), 0, nullptr);
        SAL_WARN("sal.osl", "socket creation failed: (" << nErrno << ") " << sErr);
        LocalFree(sErr);

        destroySocketImpl(pSocket);
        pSocket = nullptr;
    }
    else
    {
        pSocket->m_Flags = 0;
    }

    return pSocket;
}
```

The main difference is in the way that it reports an error - Win32 doesn't really like `strerr()` and has it's own function for extracting the error message. Also, the whole concept of file descriptors doesn't really exist in Windows \(not to mention Windows handles children process differently to Unix\) so there is no need to set a close-on-exec option, as in the Unix version.

## Socket addressing

A server must bind an address to its socket. The following functions deal with host addressing:

```cpp
SAL_DLLPUBLIC oslHostAddr SAL_CALL osl_createHostAddr(rtl_uString *strHostname, const oslSocketAddr Addr);

SAL_DLLPUBLIC oslHostAddr SAL_CALL osl_createHostAddrByName(rtl_uString *strHostname);

SAL_DLLPUBLIC oslHostAddr SAL_CALL osl_createHostAddrByAddr(const oslSocketAddr Addr);

SAL_DLLPUBLIC oslHostAddr SAL_CALL osl_copyHostAddr(const oslHostAddr Addr);

SAL_DLLPUBLIC void SAL_CALL osl_destroyHostAddr(oslHostAddr Addr);

SAL_DLLPUBLIC void SAL_CALL osl_getHostnameOfHostAddr(const oslHostAddr Addr, rtl_uString **strHostname);

SAL_DLLPUBLIC oslSocketAddr SAL_CALL osl_getSocketAddrOfHostAddr(const oslHostAddr Addr);

SAL_DLLPUBLIC oslSocketResult SAL_CALL osl_getLocalHostname(rtl_uString **strLocalHostname);

SAL_DLLPUBLIC oslSocketResult SAL_CALL osl_getHostnameOfSocketAddr(oslSocketAddr Addr, rtl_uString **strHostname);

SAL_DLLPUBLIC sal_Int32 SAL_CALL osl_getInetPortOfSocketAddr(oslSocketAddr Addr);

SAL_DLLPUBLIC sal_Bool SAL_CALL osl_setInetPortOfSocketAddr(oslSocketAddr Addr, sal_Int32 Port);

SAL_DLLPUBLIC oslSocketResult SAL_CALL osl_getDottedInetAddrOfSocketAddr(
        oslSocketAddr Addr, rtl_uString **strDottedInetAddr);

SAL_DLLPUBLIC oslSocketResult SAL_CALL osl_setAddrOfSocketAddr(oslSocketAddr Addr, sal_Sequence *pByteSeq);

SAL_DLLPUBLIC oslSocketResult SAL_CALL osl_getAddrOfSocketAddr(oslSocketAddr Addr, sal_Sequence **ppByteSeq);
```

## Binding, listening and connecting

Once a socket address has been setup, it is then associated - or _bound_ - to the socket. 

## Example

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



