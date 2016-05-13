//
//  main.m
//  基于NSStream&CFStream实现的Tcp Socket 服务器端
//
//  Created by EaseMob on 16/5/13.
//  Copyright © 2016年 EaseMob. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <sys/socket.h>
#include <netinet/in.h>


#define PORT 9000

void AcceptCallBack(CFSocketRef, CFSocketCallBackType, CFDateRef, const void *, void *);
void WriteStreamClientCallBack(CFWriteStreamRef stream, CFStreamEventType eventType, void *);
void ReadStreamClientCallBack(CFReadStreamRef stream,CFStreamEventType eventType, void *);

void AcceptCallBack(CFSocketRef socket, CFSocketCallBackType type, CFDateRef address, const void * data, void * info) {
    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    /* data 参数的含义是，如果回调的类型是kCFSocketAcceptCallBack，data就是CFSocketBativeHandle 类型的指针 */
    CFSocketNativeHandle sock =  * (CFSocketNativeHandle *)data;
    /* 创建读写 Socket 流 */
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, sock, &readStream, &writeStream);
    if (!readStream || !writeStream) {
        close(sock);
        fprintf(stderr, "CFStreamCreatPairWithSocket()失败\n");
        return;
    }
    CFStreamClientContext streamCtxt = {0, NULL, NULL, NULL, NULL};
    //注册俩种回调函数
    CFReadStreamSetClient(readStream, kCFStreamEventHasBytesAvailable, ReadStreamClientCallBack, &streamCtxt);
    CFWriteStreamSetClient(writeStream, kCFStreamEventCanAcceptBytes, WriteStreamClientCallBack, &streamCtxt);
    
    /* 加入到循环中 */
    CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    CFWriteStreamScheduleWithRunLoop(writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    CFReadStreamOpen(readStream);
    CFWriteStreamOpen(writeStream);
}


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        /* 定义一个 Server Socket引用 */
        CFSocketRef sserver;
        
        /* 创建 socket context */
        CFSocketContext CTX = {0,NULL,NULL,NULL,NULL};
        
        /* 创建 server socket TCP IPv4 设置回调函数 */
        sserver = CFSocketCreate(NULL, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, (CFSocketCallBack)AcceptCallBack, &CTX);
        if (sserver == NULL) {
            return -1;
        }
        /* 设置是否重新绑定标志 */
        int yes = 1;
        /* 设置 socket 属性 SOL_SOCKET 是设置tcp SO_REUSEADDR 重新绑定，yes 是否重新绑定 */
        
        setsockopt(CFSocketGetNative(sserver), SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));
        
        /* 设置端口和地址 */
        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));//memset 函数对指定的地址进行内存复制
        addr.sin_len = sizeof(addr);
        addr.sin_family = AF_INET;// AF_INET 是设置Ipv4
        addr.sin_port = htons(PORT);//htons 函数 无符号短整型数转换成“网络字节序”
        addr.sin_addr.s_addr = htonl(INADDR_ANY);//INADDR_ANY 有内核分配，htonl 函数无符号长整形数转换成“网络字节序”
        /* 从指定字节缓冲区复制，一个不可变的 CFData 对象 */
        CFDataRef address = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&addr, sizeof(addr));
        /* 绑定 Socket */
        if (CFSocketSetAddress(sserver, (CFDataRef)address) != kCFSocketSuccess) {
            fprintf(stderr, "socket 绑定失败\n");
            CFRelease(sserver);
            return -1;
        }
        /* 创建一个 Run Loop Socket 源 */
        CFRunLoopSourceRef sourceRef = CFSocketCreateRunLoopSource(kCFAllocatorDefault, sserver, 0);
        /* Socket 源添加到 Run Loop 中 */
        CFRunLoopAddSource(CFRunLoopGetCurrent(), sourceRef, kCFRunLoopCommonModes);
        CFRelease(sourceRef);
        printf("Socket listening on port %d\n",PORT);
        /* 运行Loop */
        CFRunLoopRun();
    }
    return 0;
}

/* 读取流操作 客户端有数据过来的时候调用 */
void ReadStreamClientCallBack (CFReadStreamRef stream, CFStreamEventType eventType, void *clientCallBackInfo) {
    UInt8 buff[255];
    CFReadStreamRef inputStream = stream;
    if (NULL != inputStream) {
        CFReadStreamRead(stream, buff, 255);
        printf("接收到数据：%s \n",buff);
        CFReadStreamClose(inputStream);
        CFReadStreamUnscheduleFromRunLoop(inputStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        inputStream = NULL;
    }
}

/* 写入流 客户端在读取数据是调用 */
void WriteStreamClientCallBack(CFWriteStreamRef stream, CFStreamEventType eventType, void * clientCallBackInfo) {
    CFWriteStreamRef outputStream = stream;
    //输出
    UInt8 buff[] = "Hello Client";
    if (NULL != outputStream) {
        CFWriteStreamWrite(outputStream, buff,strlen((const char *)buff +1));
        CFWriteStreamClose(outputStream);
        CFWriteStreamUnscheduleFromRunLoop(outputStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        outputStream = NULL;
    }
}

