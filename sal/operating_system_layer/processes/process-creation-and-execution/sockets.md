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

Once a socket address has been setup, it is then associated - or _bound_ - to the socket. The OSL function that does this is `osl_bindAddrToSocket()`which just wraps around a the `bind` function call. The Unix version is virtually the same as the Win32 version, which is implemented as so:

```cpp
sal_Bool SAL_CALL osl_bindAddrToSocket(oslSocket pSocket, oslSocketAddr pAddr)
{
    SAL_WARN_IF(!pSocket, "sal.osl", "undefined socket");
    SAL_WARN_IF(!pAddr, "sal.osl", "undefined address");
    if (!pSocket || pAddr )
    {
        return false;
    }

    pSocket->m_nLastError=0;

    int nRet = bind(pSocket->m_Socket, &(pAddr->m_sockaddr), sizeof(struct sockaddr));

    if (nRet == OSL_SOCKET_ERROR)
    {
        pSocket->m_nLastError=errno;
        return false;
    }

    return true;
}
```

A server _listens_ on its socket for incoming connections. The function that handles this is `osl_listenOnSocket()` \(also virtually the same between Unix and Win32\):

```cpp
sal_Bool SAL_CALL osl_listenOnSocket(oslSocket pSocket, sal_Int32 MaxPendingConnections)
{
    SAL_WARN_IF(!pSocket, "sal.osl", "undefined socket");
    if (!pSocket)
        return false;

    pSocket->m_nLastError=0;

    int nRet = listen(pSocket->m_Socket,
                  MaxPendingConnections == -1 ? SOMAXCONN : MaxPendingConnections);
    if (nRet == OSL_SOCKET_ERROR)
    {
        pSocket->m_nLastError=errno;
        return false;
    }

    return true;
}
```

Listen is nothing without `accept()` however - `listen()` basically is a passive socket that waits for incoming connections, and `accept()` makes the listening socket _accept_ the next connection and returns a socket file descriptor for this connection. The function that accepts connections is `osl_acceptConnectionOnSocket()`the Unix version is:

```cpp
oslSocket SAL_CALL osl_acceptConnectionOnSocket(oslSocket pSocket, oslSocketAddr* ppAddr)
{
    struct sockaddr Addr;
    int Connection;
    oslSocket pConnectionSockImpl;

    SAL_WARN_IF(!pSocket, "sal.osl", "undefined socket");
    if (!pSocket)
        return nullptr;

    pSocket->m_nLastError = 0;
#if defined(CLOSESOCKET_DOESNT_WAKE_UP_ACCEPT)
    pSocket->m_bIsAccepting = true;
#endif /* CLOSESOCKET_DOESNT_WAKE_UP_ACCEPT */

    if (ppAddr && *ppAddr)
    {
        osl_destroySocketAddr(*ppAddr);
        *ppAddr = nullptr;
    }

    /* prevent Linux EINTR behaviour */
    socklen_t AddrLen = sizeof(struct sockaddr);

    do
    {
        Connection = accept(pSocket->m_Socket, &Addr, &AddrLen);
    } while (Connection == -1 && errno == EINTR);

    /* accept failed? */
    if (Connection == OSL_SOCKET_ERROR)
    {
        pSocket->m_nLastError=errno;
        int nErrno = errno;
        SAL_WARN( "sal.osl", "accept connection failed: (" << nErrno << ") " << strerror(nErrno) );

#if defined(CLOSESOCKET_DOESNT_WAKE_UP_ACCEPT)
        pSocket->m_bIsAccepting = false;
#endif /* CLOSESOCKET_DOESNT_WAKE_UP_ACCEPT */
        return nullptr;
    }

    assert(AddrLen == sizeof(struct sockaddr));

#if defined(CLOSESOCKET_DOESNT_WAKE_UP_ACCEPT)
    if (pSocket->m_bIsInShutdown)
    {
        close(Connection);
        SAL_WARN( "sal.osl", "close while accept" );
        return nullptr;
    }
#endif /* CLOSESOCKET_DOESNT_WAKE_UP_ACCEPT */

    if (ppAddr)
        *ppAddr = createSocketAddrFromSystem(&Addr);

    /* alloc memory */
    pConnectionSockImpl = createSocketImpl(OSL_INVALID_SOCKET);

    /* set close-on-exec flag */
    int Flags = fcntl(Connection, F_GETFD, 0);
    if (Flags != -1)
    {
        Flags |= FD_CLOEXEC;
        if (fcntl(Connection, F_SETFD, Flags) == -1)
        {
            pSocket->m_nLastError=errno;
            int nErrno = errno;
            SAL_WARN( "sal.osl", "failed changing socket flags: (" << nErrno << ") " << strerror(nErrno) );
        }

    }

    pConnectionSockImpl->m_Socket = Connection;
    pConnectionSockImpl->m_nLastError = 0;
#if defined(CLOSESOCKET_DOESNT_WAKE_UP_ACCEPT)
    pConnectionSockImpl->m_bIsAccepting = false;

    pSocket->m_bIsAccepting = false;
#endif /* CLOSESOCKET_DOESNT_WAKE_UP_ACCEPT */
    return pConnectionSockImpl;
}
```

A few notes about this function: the way it works is the same as the `accept()` function - you pass the listening socket to the function and the new connecting address is populated into the `ppAddr` output parameter if the address is not null. The Unix version also sets close-on-exec on the socket. However, a special consideration needs to be made for Linux - [as the man page states](https://linux.die.net/man/7/signal):

> On Linux, even in the absence of signal handlers, certain blocking interfaces can fail with the error EINTR after the process is stopped by one of the stop signals and then resumed via SIGCONT. This behavior is not sanctioned by POSIX.1, and doesn't occur on other systems.

Thus, the function loops while `accept()` errors out \(returns -1\) and `errno` is set to `EINTR`.

From the client side, you connect to the server's listening socket. The OSL API function that does this is `osl_connectSocketTo()`. The Unix version is:

```cpp
oslSocketResult SAL_CALL osl_connectSocketTo(
    oslSocket pSocket,
    oslSocketAddr pAddr,
    const TimeValue* pTimeout)
{
    SAL_WARN_IF(!pSocket, "sal.osl", "undefined socket");

    if (!pSocket || !pAddr)
        return osl_Socket_Error;

    pSocket->m_nLastError=0;

    if (osl_isNonBlockingMode(pSocket))
    {
        if (connect(pSocket->m_Socket,
                    &(pAddr->m_sockaddr),
                    sizeof(struct sockaddr)) != OSL_SOCKET_ERROR)
        {
            return osl_Socket_Ok;
        }

        if (errno == EWOULDBLOCK || errno == EINPROGRESS)
        {
            pSocket->m_nLastError = EINPROGRESS;
            return osl_Socket_InProgress;
        }

        pSocket->m_nLastError = errno;
        int nErrno = errno;
        SAL_WARN("sal.osl", "connection failed: (" << nErrno << ") " << strerror(nErrno));
        return osl_Socket_Error;
    }

    /* set socket temporarily to non-blocking */
    if( !osl_enableNonBlockingMode(pSocket, true) )
        SAL_WARN( "sal.osl", "failed to enable non-blocking mode" );

    /* initiate connect */
    if(connect(pSocket->m_Socket,
               &(pAddr->m_sockaddr),
               sizeof(struct sockaddr)) != OSL_SOCKET_ERROR)
    {
       /* immediate connection */
        osl_enableNonBlockingMode(pSocket, false);

        return osl_Socket_Ok;
    }

    /* really an error or just delayed? */
    if (errno != EINPROGRESS)
    {
        pSocket->m_nLastError = errno;
        int nErrno = errno;
        SAL_WARN( "sal.osl", "connection failed: (" << nErrno << ") " << strerror(nErrno) );

        osl_enableNonBlockingMode(pSocket, false);
        return osl_Socket_Error;
    }

    /* prepare select set for socket  */
    fd_set WriteSet;
    fd_set ExcptSet;

    FD_ZERO(&WriteSet);
    FD_ZERO(&ExcptSet);
    FD_SET(pSocket->m_Socket, &WriteSet);
    FD_SET(pSocket->m_Socket, &ExcptSet);

    /* prepare timeout */
    struct timeval tv;

    if (pTimeout)
    {
        /* divide milliseconds into seconds and microseconds */
        tv.tv_sec=  pTimeout->Seconds;
        tv.tv_usec= pTimeout->Nanosec / 1000L;
    }

    /* select */
    oslSocketResult Result = osl_Socket_Ok;

    int ReadyHandles = select(pSocket->m_Socket+1,
                         nullptr,
                         PTR_FD_SET(WriteSet),
                         PTR_FD_SET(ExcptSet),
                         (pTimeout) ? &tv : nullptr);

    if (ReadyHandles > 0) /* connected */
    {
        if (FD_ISSET(pSocket->m_Socket, &WriteSet))
        {
            int nErrorCode = 0;
            socklen_t nErrorSize = sizeof(nErrorCode);

            int nSockOpt = getsockopt(pSocket->m_Socket, SOL_SOCKET, SO_ERROR,
                                  &nErrorCode, &nErrorSize);

            if (nSockOpt == 0 && nErrorCode == 0)
                Result = osl_Socket_Ok;
            else
                Result = osl_Socket_Error;
        }
        else
        {
            Result = osl_Socket_Error;
        }
    }
    else if (ReadyHandles < 0)  /* error */
    {
        if (errno == EBADF) /* most probably interrupted by close() */
        {
            /* do not access pSockImpl because it is about to be or */
            /* already destroyed */
            return osl_Socket_Interrupted;
        }
        pSocket->m_nLastError=errno;
        Result= osl_Socket_Error;
    }
    else /* timeout */
    {
        pSocket->m_nLastError=errno;
        Result= osl_Socket_TimedOut;
    }

    osl_enableNonBlockingMode(pSocket, false);

    return Result;
}
```

The Windows version of the function is similar:

```cpp
oslSocketResult SAL_CALL osl_connectSocketTo(
    oslSocket pSocket,
    oslSocketAddr pAddr,
    const TimeValue* pTimeout)
{
    int nError=0;

    if (!pSocket) /* ENOTSOCK */
        return osl_Socket_Error;

    if (!pAddr) /* EDESTADDRREQ */
        return osl_Socket_Error;

    if (!pTimeout)
    {
        if (connect(pSocket->m_Socket,
                   &(pAddr->m_sockaddr),
                    sizeof(struct sockaddr)) != OSL_SOCKET_ERROR)
        {
            return osl_Socket_Ok;
        }
        else
        {
            wchar_t *sErr = nullptr;
            FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                           nullptr, nErrno,
                           MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                           reinterpret_cast<LPWSTR>(&sErr), 0, nullptr);
            SAL_WARN("sal.osl", "connection failed: (" << nErrno << ") " << sErr);
            LocalFree(sErr);

            return osl_Socket_Error;
        }
    }
    else
    {
        if (pSocket->m_Flags & OSL_SOCKET_FLAGS_NONBLOCKING)
        {
            if (connect(pSocket->m_Socket,
                        &(pAddr->m_sockaddr),
                        sizeof(struct sockaddr)) == OSL_SOCKET_ERROR)
            {
                switch (WSAGetLastError())
                {
                    case WSAEWOULDBLOCK:
                    case WSAEINPROGRESS:
                        return osl_Socket_InProgress;

                    default:
                        return osl_Socket_Error;
                }
            }
            else
            {
                return osl_Socket_Ok;
            }
        }

        /* set socket temporarily to non-blocking */
        unsigned long ulNonblockingMode = 1;
        SAL_WARN_IF(ioctlsocket(
                pSocket->m_Socket, FIONBIO, &ulNonblockingMode) == OSL_SOCKET_ERROR,
                "sal.osl", "cannot set nonblocking mode");

        /* initiate connect */
        if (connect(pSocket->m_Socket,
                     &(pAddr->m_sockaddr),
                    sizeof(struct sockaddr)) != OSL_SOCKET_ERROR)
        {
            /* immediate connection */
            ulNonblockingMode = 0;
            ioctlsocket(pSocket->m_Socket, FIONBIO, &ulNonblockingMode);

            return osl_Socket_Ok;
        }
        else
        {
            nError = WSAGetLastError();

            /* really an error or just delayed? */
            if (nError != WSAEWOULDBLOCK && nError != WSAEINPROGRESS)
            {
                 ulNonblockingMode = 0;
                 ioctlsocket(pSocket->m_Socket, FIONBIO, &ulNonblockingMode);

                 return osl_Socket_Error;
            }
        }

        /* prepare select set for socket  */
        fd_set fds;
        FD_ZERO(&fds);
        FD_SET(pSocket->m_Socket, &fds);

        /* divide milliseconds into seconds and microseconds */
        struct timeval tv;
        tv.tv_sec = pTimeout->Seconds;
        tv.tv_usec = pTimeout->Nanosec / 1000L;

        /* select */
        nError = select(pSocket->m_Socket+1, nullptr, &fds, nullptr, &tv);

        oslSocketResult Result = osl_Socket_Ok;

        if (nError > 0) /* connected */
        {
            SAL_WARN_IF(
                !FD_ISSET(pSocket->m_Socket, &fds),
                "sal.osl",
                "osl_connectSocketTo(): select returned but socket not set");

            Result = osl_Socket_Ok;

        }
        else if (nError < 0)  /* error */
        {
            /* errno == EBADF: most probably interrupted by close() */
            if (WSAGetLastError() == WSAEBADF)
            {
                /* do not access pSockImpl because it is about to be or
                   already destroyed */
                return osl_Socket_Interrupted;
            }
            else
            {
                Result = osl_Socket_Error;
            }

        }
        else /* timeout */
        {
            Result = osl_Socket_TimedOut;
        }

        /* clean up */
        ulNonblockingMode = 0;
        ioctlsocket(pSocket->m_Socket, FIONBIO, &ulNonBlockingMode);

        return Result;
    }
}
```

The OSL connect functions handle `connect()` in both blocking and non-blocking mode.

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



